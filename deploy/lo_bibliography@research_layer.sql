-- Deploy libroyal:lo_bibliography to pg
-- requires: lo_bibliography@baseline
-- requires: citation_names
-- requires: legacy_mapping
-- The LibreOffice bibliography view (read by libroyal.odb), now over the
-- four-level model. Interim project view: its scope is the migrated entries
-- (legacy_map); project-specific views come with the research layer. The 33
-- columns are LibreOffice's bibliography fields, as before.
--
-- Cited unit: the manifestation recorded in legacy_map. Column derivations:
--   Author, Editor, Custom2  authors of the work; editors and translators of the
--            expression, or of the expression one relation away (the host
--            volume it is aggregated by; the text an edition is an edition of)
--   Title, Subtitle  the cited manifestation, or for a volume of a set the
--           set's title (the volume's own title goes into Volume)
--   Edition, Note, ISBN  the cited manifestation
--   Year, Publisher, Address  the publication imprint of the manifestation or,
--            failing that, of the nearest host it is part of (issue, volume)
--   Journal  the serial at the top of the part-of chain
--   Volume, Number  the issue's locator ("42/4", "8, 15/1"); for a volume of a
--            set "number, volume title" ("1, Introduction and Translation");
--            Number otherwise the series number
--   Pages   the locator within the host, or an extent written "pp. …"
--   Series  the series the manifestation is issued in
--   URL     an online item of the manifestation or of a reproduction or
--           alternate of it; LocalURL: a local file of it
--   Custom1 DOI (expression, work or manifestation), as "doi:…"
--   Custom3 tags (still in the legacy tables)
--
-- Identifier (the label shown in the text), computed within the view's scope:
--   name part  per author: citation_name, else the entry element of the
--              preferred name; up to four joined by "–", five or more as
--              "First et al."; editors when there is no author
--   year       of the publication imprint (see Year)
--   suffix     a, b, c … only where name part + year repeat. Order within such
--              a group: alphabetical by title, leading article ignored; parts
--              of a multipart work form a block sorted under the title of the
--              whole, in part order (date, then part number) inside the block

BEGIN;

DROP VIEW public.lo_bibliography;

CREATE VIEW public.lo_bibliography AS
WITH RECURSIVE
cited AS (
    SELECT lm.legacy_id, lm.work_id AS w, lm.expression_id AS e, lm.manifestation_id AS m
      FROM public.legacy_map lm
),
-- the cited manifestation and every host it is part of
up AS (
    SELECT c.legacy_id, c.m AS m, 0 AS depth FROM cited c
    UNION ALL
    SELECT up.legacy_id, r.from_id, up.depth + 1
      FROM up JOIN public.relations r ON r.to_id = up.m AND r.type = 'manifestation_has_part'
),
pub AS (
    SELECT DISTINCT ON (up.legacy_id) up.legacy_id, i.id AS imprint_id, i.date_text, i.date_sort
      FROM up JOIN public.imprints i ON i.manifestation_id = up.m AND i.function = 'publication'
     ORDER BY up.legacy_id, up.depth, i.position
),
host AS (       -- direct host: issue, volume set, or the volume a chapter is in
    SELECT c.legacy_id, r.from_id AS m, r.locator, hm.category
      FROM cited c
      JOIN public.relations r ON r.to_id = c.m AND r.type = 'manifestation_has_part'
      JOIN public.manifestations hm ON hm.id = r.from_id
),
serial AS (     -- the serial at the top of the chain
    SELECT DISTINCT ON (up.legacy_id) up.legacy_id, up.m
      FROM up JOIN public.manifestations sm ON sm.id = up.m AND sm.category = 'serial_whole'
     ORDER BY up.legacy_id, up.depth DESC
),
mtitle AS (
    SELECT t.res_id, t.value, t.subtitle
      FROM public.titles t WHERE t.title_type = 'title_proper' AND t.derived_from IS NULL AND t.position = 1
),
pname AS (      -- one preferred Latin-script name per person
    SELECT DISTINCT ON (n.person_id) n.person_id,
           coalesce(n.citation_name, public.person_name_entry(n)) AS key_name,
           CASE WHEN n.entry = 'given' THEN public.person_name_display(n, 'en')
                ELSE public.person_name_entry(n) || coalesce(', ' || public.person_name_rest(n), '') END AS full_name
      FROM public.person_names n
     WHERE n.name_type = 'preferred' AND n.script = 'Latn'
     ORDER BY n.person_id, n.derived_from NULLS FIRST
),
people AS (     -- authors / editors / translators per cited entry
    SELECT c.legacy_id, ct.role, ct.position, p.key_name, p.full_name
      FROM cited c
      JOIN public.contributions ct ON
           (ct.role = 'author' AND ct.res_id = c.w)
        OR (ct.role IN ('editor', 'translator') AND (ct.res_id = c.e OR ct.res_id IN (
               SELECT r.to_id FROM public.relations r
                WHERE r.from_id = c.e AND r.type IN ('aggregated_by', 'edition_of'))))
      JOIN pname p ON p.person_id = ct.agent_id
),
names AS (
    SELECT legacy_id,
           string_agg(full_name, '; ' ORDER BY position) FILTER (WHERE role = 'author')     AS authors,
           string_agg(full_name, '; ' ORDER BY position) FILTER (WHERE role = 'editor')     AS editors,
           string_agg(full_name, '; ' ORDER BY position) FILTER (WHERE role = 'translator') AS translators,
           array_agg(key_name ORDER BY position) FILTER (WHERE role = 'author')             AS author_keys,
           array_agg(key_name ORDER BY position) FILTER (WHERE role = 'editor')             AS editor_keys
      FROM people GROUP BY legacy_id
),
base AS (
    SELECT c.legacy_id,
           c.w, c.m,
           CASE
               WHEN m.category = 'component' AND s.m IS NOT NULL THEN 'article'
               WHEN m.category = 'component' THEN 'incollection'
               WHEN wk.category = 'online_resource' THEN 'misc'
               ELSE 'book' END AS type,
           n.authors, n.editors, n.translators,
           coalesce(n.author_keys, n.editor_keys) AS keys,
           -- a volume of a set is cited under the set's title; its own (part)
           -- title goes with the volume number
           CASE WHEN h.category = 'set' THEN (SELECT x.value    FROM mtitle x WHERE x.res_id = h.m) ELSE t.value    END AS title_value,
           CASE WHEN h.category = 'set' THEN (SELECT x.subtitle FROM mtitle x WHERE x.res_id = h.m) ELSE t.subtitle END AS subtitle,
           CASE WHEN h.category = 'set' THEN h.locator || coalesce(', ' || t.value || coalesce(': ' || t.subtitle, ''), '') END AS volume_label,
           coalesce(pub.date_sort::text, pub.date_text) AS year,
           (SELECT string_agg(cn.value, ' – ' ORDER BY ia.position)
              FROM public.imprint_agents ia
              JOIN public.collective_names cn ON cn.collective_id = ia.agent_id AND cn.name_type = 'preferred'
             WHERE ia.imprint_id = pub.imprint_id) AS publisher,
           (SELECT string_agg(pn.value, '–' ORDER BY ip.position)
              FROM public.imprint_places ip
              JOIN public.place_names pn ON pn.place_id = ip.place_id AND pn.is_preferred
             WHERE ip.imprint_id = pub.imprint_id) AS place,
           st.value AS journal,
           -- the issue's own place in the serial ("42/4"), not the article's place in the issue
           CASE WHEN h.category = 'issue' THEN (SELECT r.locator FROM public.relations r
                                                  WHERE r.to_id = h.m AND r.type = 'manifestation_has_part' LIMIT 1) END AS issue_locator,
           CASE WHEN m.category = 'component' THEN h.locator
                ELSE substring(m.extent FROM '^pp\. (.+)$') END AS pages,
           CASE WHEN m.category = 'component' AND s.m IS NULL THEN
                (SELECT ht.value || coalesce(': ' || ht.subtitle, '') FROM mtitle ht WHERE ht.res_id = h.m) END AS booktitle,
           (SELECT x.value FROM public.identifiers x WHERE x.res_id = c.m AND x.scheme = 'isbn' ORDER BY x.id LIMIT 1) AS isbn,
           (SELECT 'doi:' || x.value FROM public.identifiers x
             WHERE x.res_id IN (c.e, c.w, c.m) AND x.scheme = 'doi' ORDER BY x.id LIMIT 1) AS doi,
           (SELECT i.url FROM public.items i
             WHERE i.url IS NOT NULL AND (i.manifestation_id = c.m OR i.manifestation_id IN (
                   SELECT r.from_id FROM public.relations r WHERE r.to_id = c.m AND r.type IN ('reproduction_of', 'alternate_of')
                   UNION SELECT r.to_id FROM public.relations r WHERE r.from_id = c.m AND r.type = 'alternate_of'))
             ORDER BY i.id LIMIT 1) AS url,
           (SELECT i.path FROM public.items i WHERE i.manifestation_id = c.m AND i.path IS NOT NULL ORDER BY i.id LIMIT 1) AS local_path,
           (SELECT ms.value FROM public.manifestation_statements ms
             WHERE ms.manifestation_id = c.m AND ms.statement_type = 'edition' AND ms.derived_from IS NULL
             ORDER BY ms.position LIMIT 1) AS edition,
           (SELECT wt.value FROM public.relations r
              JOIN public.titles wt ON wt.res_id = r.to_id AND wt.title_type = 'preferred'
             WHERE r.from_id = c.m AND r.type = 'in_series' ORDER BY r.id LIMIT 1) AS series_name,
           (SELECT r.locator FROM public.relations r
             WHERE r.from_id = c.m AND r.type = 'in_series' ORDER BY r.id LIMIT 1) AS series_number,
           m.note,
           (SELECT string_agg(tg.name, '; ' ORDER BY tg.name)
              FROM public.legacy_work_tags lt JOIN public.legacy_tags tg ON tg.id = lt.tag_id
             WHERE lt.work_id = c.legacy_id) AS tags,
           -- ordering inside a label group: block title (whole of a multipart work) and part order
           coalesce((SELECT pt.value FROM public.relations r
                       JOIN public.works pw ON pw.id = r.from_id AND pw.category = 'multipart'
                       JOIN public.titles pt ON pt.res_id = pw.id AND pt.title_type = 'preferred'
                      WHERE r.to_id = c.w AND r.type = 'work_has_part' LIMIT 1), t.value) AS block_title,
           (SELECT r.locator FROM public.relations r
             WHERE r.to_id = c.w AND r.type = 'work_has_part' LIMIT 1) AS part_locator,
           pub.date_text AS date_full
      FROM cited c
      JOIN public.manifestations m ON m.id = c.m
      JOIN public.works wk ON wk.id = c.w
      LEFT JOIN names n ON n.legacy_id = c.legacy_id
      LEFT JOIN mtitle t ON t.res_id = c.m
      LEFT JOIN pub ON pub.legacy_id = c.legacy_id
      LEFT JOIN host h ON h.legacy_id = c.legacy_id
      LEFT JOIN serial s ON s.legacy_id = c.legacy_id
      LEFT JOIN mtitle st ON st.res_id = s.m
),
labelled AS (
    SELECT b.*,
           coalesce(CASE WHEN cardinality(b.keys) >= 5 THEN b.keys[1] || ' et al.'
                         ELSE array_to_string(b.keys, '–') END, '[no-author]')
           || ' ' || coalesce(b.year, '[no-year]') AS label0
      FROM base b
),
keyed AS (
    SELECT l.*,
           l.label0 || CASE WHEN count(*) OVER (PARTITION BY l.label0) > 1
               THEN chr(96 + row_number() OVER (
                    PARTITION BY l.label0
                    ORDER BY regexp_replace(l.block_title, '^(a|az|the|an?|der|die|das|le|la|les|l''|il|lo|el)\s+', '', 'i') COLLATE "hu-HU-x-icu",
                             l.date_full, l.part_locator,
                             regexp_replace(l.title_value, '^(a|az|the|an?|der|die|das|le|la|les|l''|il|lo|el)\s+', '', 'i') COLLATE "hu-HU-x-icu",
                             l.legacy_id)::int)
               ELSE '' END AS label
      FROM labelled l
)
SELECT label AS "Identifier",
       CASE type WHEN 'article' THEN 0 WHEN 'book' THEN 1 WHEN 'incollection' THEN 5 WHEN 'misc' THEN 10 END AS "BibliographyType",
       authors AS "Author",
       editors AS "Editor",
       title_value || coalesce(': ' || subtitle, '') AS "Title",
       subtitle AS "Subtitle",
       year AS "Year",
       publisher AS "Publisher",
       place AS "Address",
       journal AS "Journal",
       coalesce(volume_label, CASE WHEN issue_locator ~ ', ' THEN split_part(issue_locator, ', ', 1)
                                    WHEN issue_locator ~ '/' THEN split_part(issue_locator, '/', 1) END) AS "Volume",
       coalesce(CASE WHEN issue_locator ~ ', ' THEN substring(issue_locator FROM ', (.*)$')
                     WHEN issue_locator ~ '/' THEN substring(issue_locator FROM '/(.*)$')
                     ELSE issue_locator END, series_number) AS "Number",
       pages AS "Pages",
       isbn AS "ISBN",
       url AS "URL",
       doi AS "Custom1",
       translators AS "Custom2",
       tags AS "Custom3",
       note AS "Note",
       NULL::text AS "Annote",
       booktitle AS "Booktitle",
       NULL::text AS "Chapter",
       edition AS "Edition",
       NULL::text AS "Howpublished",
       NULL::text AS "Institution",
       NULL::text AS "Month",
       NULL::text AS "Organizations",
       NULL::text AS "School",
       series_name AS "Series",
       NULL::text AS "ReportType",
       NULL::text AS "Custom4",
       NULL::text AS "Custom5",
       local_path AS "LocalURL"
  FROM keyed;

COMMIT;
