-- Revert libroyal:lo_bibliography from pg
-- Restores the @baseline view over the legacy tables, under their legacy_*
-- names (renamed by legacy_rename after the baseline view was created).
-- Generated from pg_dump --schema-only of the live libroyal DB, 2026-10-21.

BEGIN;

DROP VIEW public.lo_bibliography;

-- Name: lo_bibliography; Type: VIEW; Schema: public; Owner: -
CREATE VIEW public.lo_bibliography AS
 WITH author_names AS (
         SELECT wc.work_id,
            string_agg(p.family_name, '–'::text ORDER BY wc."position") AS author_family_names,
            string_agg(
                CASE
                    WHEN ((p.given_name IS NULL) OR (p.given_name = ''::text)) THEN p.family_name
                    ELSE ((p.family_name || ', '::text) || p.given_name)
                END, '; '::text ORDER BY wc."position") AS author_full_names
           FROM (public.legacy_work_contributors wc
             JOIN public.legacy_persons p ON ((p.id = wc.person_id)))
          WHERE (wc.role = 'author'::text)
          GROUP BY wc.work_id
        ), editor_names AS (
         SELECT wc.work_id,
            string_agg(p.family_name, '–'::text ORDER BY wc."position") AS editor_family_names,
            string_agg(
                CASE
                    WHEN ((p.given_name IS NULL) OR (p.given_name = ''::text)) THEN p.family_name
                    ELSE ((p.family_name || ', '::text) || p.given_name)
                END, '; '::text ORDER BY wc."position") AS editor_full_names
           FROM (public.legacy_work_contributors wc
             JOIN public.legacy_persons p ON ((p.id = wc.person_id)))
          WHERE (wc.role = 'editor'::text)
          GROUP BY wc.work_id
        ), translator_names AS (
         SELECT wc.work_id,
            string_agg(
                CASE
                    WHEN ((p.given_name IS NULL) OR (p.given_name = ''::text)) THEN p.family_name
                    ELSE ((p.family_name || ', '::text) || p.given_name)
                END, '; '::text ORDER BY wc."position") AS translator_full_names
           FROM (public.legacy_work_contributors wc
             JOIN public.legacy_persons p ON ((p.id = wc.person_id)))
          WHERE (wc.role = 'translator'::text)
          GROUP BY wc.work_id
        ), tag_names AS (
         SELECT wt.work_id,
            string_agg(t.name, '; '::text ORDER BY t.name) AS tag_list
           FROM (public.legacy_work_tags wt
             JOIN public.legacy_tags t ON ((t.id = wt.tag_id)))
          GROUP BY wt.work_id
        ), local_copies AS (
         SELECT DISTINCT ON (wc.work_id) wc.work_id,
            wc.url
           FROM public.legacy_work_copies wc
          WHERE ((wc.location_type)::text = 'local'::text)
          ORDER BY wc.work_id, wc.id DESC
        ), base AS (
         SELECT w.id,
            TRIM(BOTH ' '::text FROM ((COALESCE(NULLIF(an.author_family_names, ''::text), NULLIF(en.editor_family_names, ''::text), '[no-author]'::text) || ' '::text) || COALESCE(NULLIF(w.year, ''::text), '[no-year]'::text))) AS citekey0,
            w.type,
            an.author_full_names AS authors,
            en.editor_full_names AS editors,
            tr.translator_full_names AS translators,
                CASE
                    WHEN (NULLIF(btrim(w.subtitle), ''::text) IS NOT NULL) THEN ((w.title || ': '::text) || w.subtitle)
                    ELSE w.title
                END AS title,
            w.subtitle,
            w.year,
            w.publisher,
            w.place,
            w.journal,
            w.volume,
            w.issue,
            w.pages,
            w.doi,
            w.isbn,
            w.url,
            w.note,
            w.booktitle,
            w.edition,
            tg.tag_list AS tags,
            s.name AS series_name,
            w.number AS series_number,
            lc.url AS local_url
           FROM ((((((public.legacy_works w
             LEFT JOIN author_names an ON ((an.work_id = w.id)))
             LEFT JOIN editor_names en ON ((en.work_id = w.id)))
             LEFT JOIN translator_names tr ON ((tr.work_id = w.id)))
             LEFT JOIN tag_names tg ON ((tg.work_id = w.id)))
             LEFT JOIN public.legacy_series s ON ((s.id = w.series_id)))
             LEFT JOIN local_copies lc ON ((lc.work_id = w.id)))
        ), keyed AS (
         SELECT base.id,
            base.citekey0,
            base.type,
            base.authors,
            base.editors,
            base.translators,
            base.title,
            base.subtitle,
            base.year,
            base.publisher,
            base.place,
            base.journal,
            base.volume,
            base.issue,
            base.pages,
            base.doi,
            base.isbn,
            base.url,
            base.note,
            base.booktitle,
            base.edition,
            base.tags,
            base.series_name,
            base.series_number,
            base.local_url,
            (base.citekey0 ||
                CASE
                    WHEN (count(*) OVER (PARTITION BY base.citekey0) > 1) THEN chr((96 + (row_number() OVER (PARTITION BY base.citekey0 ORDER BY (base.title COLLATE "und-x-icu"), base.id))::integer))
                    ELSE ''::text
                END) AS citekey
           FROM base
        )
 SELECT citekey AS "Identifier",
        CASE type
            WHEN 'article'::text THEN 0
            WHEN 'book'::text THEN 1
            WHEN 'booklet'::text THEN 2
            WHEN 'conference'::text THEN 3
            WHEN 'inbook'::text THEN 4
            WHEN 'incollection'::text THEN 5
            WHEN 'inproceedings'::text THEN 6
            WHEN 'journal'::text THEN 7
            WHEN 'manual'::text THEN 8
            WHEN 'mastersthesis'::text THEN 9
            WHEN 'misc'::text THEN 10
            WHEN 'phdthesis'::text THEN 11
            WHEN 'proceedings'::text THEN 12
            WHEN 'techreport'::text THEN 13
            WHEN 'unpublished'::text THEN 14
            WHEN 'email'::text THEN 15
            WHEN 'www'::text THEN 16
            WHEN 'custom1'::text THEN 17
            WHEN 'custom2'::text THEN 18
            WHEN 'custom3'::text THEN 19
            WHEN 'custom4'::text THEN 20
            WHEN 'custom5'::text THEN 21
            ELSE NULL::integer
        END AS "BibliographyType",
    authors AS "Author",
    editors AS "Editor",
    title AS "Title",
    subtitle AS "Subtitle",
    year AS "Year",
    publisher AS "Publisher",
    place AS "Address",
    journal AS "Journal",
    volume AS "Volume",
    COALESCE(issue, (series_number)::text) AS "Number",
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
    local_url AS "LocalURL"
   FROM keyed;

COMMIT;
