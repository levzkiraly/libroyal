-- Deploy libroyal:lo_views to pg
-- requires: research_layer
-- requires: lo_bibliography
-- LibreOffice bibliography views per scope. LibreOffice reads one table-like
-- source at a time (chosen application-wide) and copies each inserted entry
-- into the document, so a view per project and per document can exist side by
-- side; the one to insert from is chosen in the Bibliography Database dialog.
--   * lo_bibliography_rows(scope, id): the 33 LibreOffice columns (and the
--     manifestation id) for scope 'global', 'project' (projects.id) or
--     'document' (documents.work_id); labels are computed within the scope
--       project   the manifestations among the members (items as their
--                 manifestation; work and expression members have no entry)
--       document  the manifestations its expression cites
--       global    the union of all project and document scopes
--   * lo_sync(): creates lo_project_<code> and lo_document_<code> for every
--     project and document, and drops the generated views whose row is gone;
--     run by triggers on projects and documents, and by hand after a restore.
--     The generated views are data-dependent and not part of the plan.
-- Column derivations and label rules: see lo_bibliography. Custom3 now lists
-- the projects the entry belongs to.

BEGIN;

CREATE FUNCTION public.lo_bibliography_rows(p_scope text, p_id bigint DEFAULT NULL)
RETURNS TABLE (
    manifestation_id bigint,
    "Identifier" text,
    "BibliographyType" integer,
    "Author" text,
    "Editor" text,
    "Title" text,
    "Subtitle" text,
    "Year" text,
    "Publisher" text,
    "Address" text,
    "Journal" text,
    "Volume" text,
    "Number" text,
    "Pages" text,
    "ISBN" text,
    "URL" text,
    "Custom1" text,
    "Custom2" text,
    "Custom3" text,
    "Note" text,
    "Annote" text,
    "Booktitle" text,
    "Chapter" text,
    "Edition" text,
    "Howpublished" text,
    "Institution" text,
    "Month" text,
    "Organizations" text,
    "School" text,
    "Series" text,
    "ReportType" text,
    "Custom4" text,
    "Custom5" text,
    "LocalURL" text
)
LANGUAGE sql STABLE AS $fn$
    WITH RECURSIVE
    scoped AS (     -- manifestations per scope (an item counts as its manifestation)
        SELECT coalesce(i.manifestation_id, pm.res_id) AS m, pm.project_id, NULL::bigint AS document_id
          FROM public.project_members pm
          LEFT JOIN public.items i ON i.id = pm.res_id AND pm.res_kind = 'item'
         WHERE pm.res_kind IN ('manifestation', 'item')
        UNION
        SELECT coalesce(i.manifestation_id, ct.cited_id), NULL, d.work_id
          FROM public.documents d
          JOIN public.citations ct ON ct.citing_expression_id = d.expression_id
          LEFT JOIN public.items i ON i.id = ct.cited_id AND ct.cited_kind = 'item'
    ),
    cited AS (      -- k: the cited manifestation, the key of the row
        SELECT DISTINCT s.m AS k, s.m AS m, me.expression_id AS e, ex.work_id AS w
          FROM scoped s
          JOIN LATERAL (SELECT x.expression_id FROM public.manifestation_expressions x
                         WHERE x.manifestation_id = s.m ORDER BY x.position, x.expression_id LIMIT 1) me ON true
          JOIN public.expressions ex ON ex.id = me.expression_id
         WHERE p_scope = 'global'
            OR (p_scope = 'project'  AND s.project_id  = p_id)
            OR (p_scope = 'document' AND s.document_id = p_id)
    ),
    -- the cited manifestation and every host it is part of
    up AS (
        SELECT c.k, c.m AS m, 0 AS depth FROM cited c
        UNION ALL
        SELECT up.k, r.from_id, up.depth + 1
          FROM up JOIN public.relations r ON r.to_id = up.m AND r.type = 'manifestation_has_part'
    ),
    pub AS (
        SELECT DISTINCT ON (up.k) up.k, i.id AS imprint_id, i.date_text, i.date_sort
          FROM up JOIN public.imprints i ON i.manifestation_id = up.m AND i.function = 'publication'
         ORDER BY up.k, up.depth, i.position
    ),
    host AS (       -- direct host: issue, volume set, or the volume a chapter is in
        SELECT c.k, r.from_id AS m, r.locator, hm.category
          FROM cited c
          JOIN public.relations r ON r.to_id = c.m AND r.type = 'manifestation_has_part'
          JOIN public.manifestations hm ON hm.id = r.from_id
    ),
    serial AS (     -- the serial at the top of the chain
        SELECT DISTINCT ON (up.k) up.k, up.m
          FROM up JOIN public.manifestations sm ON sm.id = up.m AND sm.category = 'serial_whole'
         ORDER BY up.k, up.depth DESC
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
        SELECT c.k, ct.role, ct.position, p.key_name, p.full_name
          FROM cited c
          JOIN public.contributions ct ON
               (ct.role = 'author' AND ct.res_id = c.w)
            OR (ct.role IN ('editor', 'translator') AND (ct.res_id = c.e OR ct.res_id IN (
                   SELECT r.to_id FROM public.relations r
                    WHERE r.from_id = c.e AND r.type IN ('aggregated_by', 'edition_of'))))
          JOIN pname p ON p.person_id = ct.agent_id
    ),
    names AS (
        SELECT k,
               string_agg(full_name, '; ' ORDER BY position) FILTER (WHERE role = 'author')     AS authors,
               string_agg(full_name, '; ' ORDER BY position) FILTER (WHERE role = 'editor')     AS editors,
               string_agg(full_name, '; ' ORDER BY position) FILTER (WHERE role = 'translator') AS translators,
               array_agg(key_name ORDER BY position) FILTER (WHERE role = 'author')             AS author_keys,
               array_agg(key_name ORDER BY position) FILTER (WHERE role = 'editor')             AS editor_keys
          FROM people GROUP BY k
    ),
    base AS (
        SELECT c.k,
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
               (SELECT string_agg(DISTINCT p.name, '; ')
                  FROM public.project_members pm JOIN public.projects p ON p.id = pm.project_id
                 WHERE pm.res_id = c.m OR pm.res_id IN (SELECT i.id FROM public.items i WHERE i.manifestation_id = c.m)) AS projects,
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
          LEFT JOIN names n ON n.k = c.k
          LEFT JOIN mtitle t ON t.res_id = c.m
          LEFT JOIN pub ON pub.k = c.k
          LEFT JOIN host h ON h.k = c.k
          LEFT JOIN serial s ON s.k = c.k
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
                                 l.k)::int)
                   ELSE '' END AS label
          FROM labelled l
    )
    SELECT k AS manifestation_id,
           label AS "Identifier",
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
           projects AS "Custom3",
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
$fn$;
COMMENT ON FUNCTION public.lo_bibliography_rows(text, bigint) IS 'LibreOffice bibliography rows of a scope: global, project (projects.id), document (documents.work_id)';

CREATE FUNCTION public.lo_sync() RETURNS void LANGUAGE plpgsql AS $fn$
DECLARE
    r record;
    v_cols constant text := '"Identifier", "BibliographyType", "Author", "Editor", "Title", "Subtitle", "Year", "Publisher", "Address", "Journal", "Volume", "Number", "Pages", "ISBN", "URL", "Custom1", "Custom2", "Custom3", "Note", "Annote", "Booktitle", "Chapter", "Edition", "Howpublished", "Institution", "Month", "Organizations", "School", "Series", "ReportType", "Custom4", "Custom5", "LocalURL"';
BEGIN
    -- drop generated views whose project or document is gone (or renamed)
    FOR r IN
        SELECT c.relname
          FROM pg_class c
          JOIN pg_description d ON d.objoid = c.oid AND d.classoid = 'pg_class'::regclass AND d.objsubid = 0
         WHERE c.relkind = 'v' AND c.relnamespace = 'public'::regnamespace
           AND d.description LIKE 'generated by lo_sync()%'
           AND c.relname NOT IN (SELECT 'lo_project_' || code FROM public.projects
                                 UNION ALL SELECT 'lo_document_' || code FROM public.documents)
    LOOP
        EXECUTE format('DROP VIEW public.%I', r.relname);
    END LOOP;
    FOR r IN
        SELECT 'lo_project_' || code AS view_name, 'project' AS scope, id FROM public.projects
        UNION ALL
        SELECT 'lo_document_' || code, 'document', work_id FROM public.documents
    LOOP
        EXECUTE format('CREATE OR REPLACE VIEW public.%I AS SELECT %s FROM public.lo_bibliography_rows(%L, %s)',
                       r.view_name, v_cols, r.scope, r.id);
        EXECUTE format('COMMENT ON VIEW public.%I IS %L', r.view_name,
                       format('generated by lo_sync() for %s %s', r.scope, r.id));
    END LOOP;
END $fn$;
COMMENT ON FUNCTION public.lo_sync() IS 'create/drop the LibreOffice views lo_project_<code> and lo_document_<code>';

CREATE FUNCTION public.lo_sync_trigger() RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
    PERFORM public.lo_sync();
    RETURN NULL;
END $fn$;

CREATE TRIGGER projects_lo_sync AFTER INSERT OR DELETE OR UPDATE OF code ON public.projects
    FOR EACH STATEMENT EXECUTE FUNCTION public.lo_sync_trigger();
CREATE TRIGGER documents_lo_sync AFTER INSERT OR DELETE OR UPDATE OF code ON public.documents
    FOR EACH STATEMENT EXECUTE FUNCTION public.lo_sync_trigger();

COMMIT;
