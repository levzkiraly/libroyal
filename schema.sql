--
-- PostgreSQL database dump
--



SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bases (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    note text
);


--
-- Name: certainties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.certainties (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    isbd_mark text
);


--
-- Name: conversion_schemes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversion_schemes (
    code text NOT NULL,
    label text NOT NULL,
    source_script text NOT NULL,
    target_script text NOT NULL,
    lang text,
    authority text,
    revision text,
    url text,
    bcp47_t text,
    generator text,
    note text,
    CONSTRAINT conversion_schemes_check CHECK ((source_script <> target_script))
);


--
-- Name: identifier_schemes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identifier_schemes (
    code text NOT NULL,
    label text NOT NULL,
    res_kind text,
    url_template text,
    note text
);


--
-- Name: identifier_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identifier_statuses (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    note text
);


--
-- Name: imprint_functions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imprint_functions (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    lrm_id text
);


--
-- Name: languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.languages (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    CONSTRAINT languages_code_check CHECK ((code ~ '^[a-z]{2,3}$'::text))
);


--
-- Name: legacy_persons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_persons (
    id bigint NOT NULL,
    family_name text NOT NULL,
    given_name text,
    prefix text,
    suffix text
);


--
-- Name: legacy_persons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_persons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_persons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_persons_id_seq OWNED BY public.legacy_persons.id;


--
-- Name: legacy_series; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_series (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    issn character varying(9)
);


--
-- Name: legacy_series_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_series_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_series_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_series_id_seq OWNED BY public.legacy_series.id;


--
-- Name: legacy_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_tags (
    id bigint NOT NULL,
    name text NOT NULL
);


--
-- Name: legacy_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_tags_id_seq OWNED BY public.legacy_tags.id;


--
-- Name: legacy_work_contributors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_work_contributors (
    work_id bigint NOT NULL,
    person_id bigint NOT NULL,
    role text NOT NULL,
    "position" integer NOT NULL,
    CONSTRAINT legacy_work_contributors_position_check CHECK (("position" > 0))
);


--
-- Name: legacy_work_copies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_work_copies (
    id bigint NOT NULL,
    work_id bigint NOT NULL,
    location_type character varying(12) NOT NULL,
    mime_type character varying(255) NOT NULL,
    url text NOT NULL
);


--
-- Name: legacy_work_copies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_work_copies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_work_copies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_work_copies_id_seq OWNED BY public.legacy_work_copies.id;


--
-- Name: legacy_work_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_work_tags (
    work_id bigint NOT NULL,
    tag_id bigint NOT NULL
);


--
-- Name: legacy_works; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_works (
    id bigint NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    subtitle text,
    year text,
    publisher text,
    place text,
    journal text,
    volume text,
    issue text,
    pages text,
    doi text,
    isbn text,
    url text,
    note text,
    series_id bigint,
    number character varying(12),
    booktitle text,
    edition text,
    CONSTRAINT legacy_works_type_lo_check CHECK ((type = ANY (ARRAY['article'::text, 'book'::text, 'booklet'::text, 'conference'::text, 'inbook'::text, 'incollection'::text, 'inproceedings'::text, 'journal'::text, 'manual'::text, 'mastersthesis'::text, 'misc'::text, 'phdthesis'::text, 'proceedings'::text, 'techreport'::text, 'unpublished'::text, 'email'::text, 'www'::text, 'custom1'::text, 'custom2'::text, 'custom3'::text, 'custom4'::text, 'custom5'::text])))
);


--
-- Name: legacy_works_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.legacy_works_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legacy_works_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.legacy_works_id_seq OWNED BY public.legacy_works.id;


--
-- Name: lo_bibliography; Type: VIEW; Schema: public; Owner: -
--

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


--
-- Name: manifestation_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manifestation_categories (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    note text
);


--
-- Name: place_name_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.place_name_types (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text
);


--
-- Name: relation_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.relation_types (
    code text NOT NULL,
    label_en text NOT NULL,
    inverse_label_en text NOT NULL,
    lrm_id text,
    parent text,
    domain_kind text NOT NULL,
    range_kind text NOT NULL,
    note text
);


--
-- Name: res_kinds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.res_kinds (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    lrm_id text
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    res_kind text NOT NULL,
    lrm_id text
);


--
-- Name: scripts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scripts (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    CONSTRAINT scripts_code_check CHECK ((code ~ '^[A-Z][a-z]{3}$'::text))
);


--
-- Name: sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sources (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text
);


--
-- Name: statement_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.statement_types (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text
);


--
-- Name: title_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.title_types (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    note text
);


--
-- Name: work_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_categories (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    note text
);


--
-- Name: legacy_persons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_persons ALTER COLUMN id SET DEFAULT nextval('public.legacy_persons_id_seq'::regclass);


--
-- Name: legacy_series id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_series ALTER COLUMN id SET DEFAULT nextval('public.legacy_series_id_seq'::regclass);


--
-- Name: legacy_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_tags ALTER COLUMN id SET DEFAULT nextval('public.legacy_tags_id_seq'::regclass);


--
-- Name: legacy_work_copies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_work_copies ALTER COLUMN id SET DEFAULT nextval('public.legacy_work_copies_id_seq'::regclass);


--
-- Name: legacy_works id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_works ALTER COLUMN id SET DEFAULT nextval('public.legacy_works_id_seq'::regclass);


--
-- Name: bases bases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bases
    ADD CONSTRAINT bases_pkey PRIMARY KEY (code);


--
-- Name: certainties certainties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certainties
    ADD CONSTRAINT certainties_pkey PRIMARY KEY (code);


--
-- Name: conversion_schemes conversion_schemes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversion_schemes
    ADD CONSTRAINT conversion_schemes_pkey PRIMARY KEY (code);


--
-- Name: identifier_schemes identifier_schemes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_schemes
    ADD CONSTRAINT identifier_schemes_pkey PRIMARY KEY (code);


--
-- Name: identifier_statuses identifier_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_statuses
    ADD CONSTRAINT identifier_statuses_pkey PRIMARY KEY (code);


--
-- Name: imprint_functions imprint_functions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_functions
    ADD CONSTRAINT imprint_functions_pkey PRIMARY KEY (code);


--
-- Name: languages languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.languages
    ADD CONSTRAINT languages_pkey PRIMARY KEY (code);


--
-- Name: legacy_persons legacy_persons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_persons
    ADD CONSTRAINT legacy_persons_pkey PRIMARY KEY (id);


--
-- Name: legacy_series legacy_series_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_series
    ADD CONSTRAINT legacy_series_pkey PRIMARY KEY (id);


--
-- Name: legacy_tags legacy_tags_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_tags
    ADD CONSTRAINT legacy_tags_name_key UNIQUE (name);


--
-- Name: legacy_tags legacy_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_tags
    ADD CONSTRAINT legacy_tags_pkey PRIMARY KEY (id);


--
-- Name: legacy_work_contributors legacy_work_contributors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_work_contributors
    ADD CONSTRAINT legacy_work_contributors_pkey PRIMARY KEY (work_id, person_id, role);


--
-- Name: legacy_work_contributors legacy_work_contributors_unique_position; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_work_contributors
    ADD CONSTRAINT legacy_work_contributors_unique_position UNIQUE (work_id, role, "position");


--
-- Name: legacy_work_copies legacy_work_copies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_work_copies
    ADD CONSTRAINT legacy_work_copies_pkey PRIMARY KEY (id);


--
-- Name: legacy_work_tags legacy_work_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_work_tags
    ADD CONSTRAINT legacy_work_tags_pkey PRIMARY KEY (work_id, tag_id);


--
-- Name: legacy_works legacy_works_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_works
    ADD CONSTRAINT legacy_works_pkey PRIMARY KEY (id);


--
-- Name: manifestation_categories manifestation_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_categories
    ADD CONSTRAINT manifestation_categories_pkey PRIMARY KEY (code);


--
-- Name: place_name_types place_name_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_name_types
    ADD CONSTRAINT place_name_types_pkey PRIMARY KEY (code);


--
-- Name: relation_types relation_types_code_domain_kind_range_kind_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relation_types
    ADD CONSTRAINT relation_types_code_domain_kind_range_kind_key UNIQUE (code, domain_kind, range_kind);


--
-- Name: relation_types relation_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relation_types
    ADD CONSTRAINT relation_types_pkey PRIMARY KEY (code);


--
-- Name: res_kinds res_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.res_kinds
    ADD CONSTRAINT res_kinds_pkey PRIMARY KEY (code);


--
-- Name: roles roles_code_res_kind_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_code_res_kind_key UNIQUE (code, res_kind);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (code);


--
-- Name: scripts scripts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scripts
    ADD CONSTRAINT scripts_pkey PRIMARY KEY (code);


--
-- Name: sources sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sources
    ADD CONSTRAINT sources_pkey PRIMARY KEY (code);


--
-- Name: statement_types statement_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statement_types
    ADD CONSTRAINT statement_types_pkey PRIMARY KEY (code);


--
-- Name: title_types title_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.title_types
    ADD CONSTRAINT title_types_pkey PRIMARY KEY (code);


--
-- Name: work_categories work_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_categories
    ADD CONSTRAINT work_categories_pkey PRIMARY KEY (code);


--
-- Name: legacy_idx_persons_family_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legacy_idx_persons_family_name ON public.legacy_persons USING btree (family_name);


--
-- Name: legacy_idx_tags_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legacy_idx_tags_name ON public.legacy_tags USING btree (name);


--
-- Name: legacy_idx_work_contributors_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legacy_idx_work_contributors_person ON public.legacy_work_contributors USING btree (person_id);


--
-- Name: legacy_idx_work_contributors_work_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legacy_idx_work_contributors_work_role ON public.legacy_work_contributors USING btree (work_id, role);


--
-- Name: legacy_idx_works_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legacy_idx_works_type ON public.legacy_works USING btree (type);


--
-- Name: legacy_idx_works_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX legacy_idx_works_year ON public.legacy_works USING btree (year);


--
-- Name: conversion_schemes conversion_schemes_lang_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversion_schemes
    ADD CONSTRAINT conversion_schemes_lang_fkey FOREIGN KEY (lang) REFERENCES public.languages(code);


--
-- Name: conversion_schemes conversion_schemes_source_script_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversion_schemes
    ADD CONSTRAINT conversion_schemes_source_script_fkey FOREIGN KEY (source_script) REFERENCES public.scripts(code);


--
-- Name: conversion_schemes conversion_schemes_target_script_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversion_schemes
    ADD CONSTRAINT conversion_schemes_target_script_fkey FOREIGN KEY (target_script) REFERENCES public.scripts(code);


--
-- Name: identifier_schemes identifier_schemes_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_schemes
    ADD CONSTRAINT identifier_schemes_res_kind_fkey FOREIGN KEY (res_kind) REFERENCES public.res_kinds(code);


--
-- Name: legacy_work_contributors legacy_work_contributors_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_work_contributors
    ADD CONSTRAINT legacy_work_contributors_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.legacy_persons(id) ON DELETE RESTRICT;


--
-- Name: legacy_work_contributors legacy_work_contributors_work_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_work_contributors
    ADD CONSTRAINT legacy_work_contributors_work_id_fkey FOREIGN KEY (work_id) REFERENCES public.legacy_works(id) ON DELETE CASCADE;


--
-- Name: legacy_work_copies legacy_work_copies_work_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_work_copies
    ADD CONSTRAINT legacy_work_copies_work_id_fkey FOREIGN KEY (work_id) REFERENCES public.legacy_works(id) ON DELETE CASCADE;


--
-- Name: legacy_work_tags legacy_work_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_work_tags
    ADD CONSTRAINT legacy_work_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.legacy_tags(id) ON DELETE CASCADE;


--
-- Name: legacy_work_tags legacy_work_tags_work_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_work_tags
    ADD CONSTRAINT legacy_work_tags_work_id_fkey FOREIGN KEY (work_id) REFERENCES public.legacy_works(id) ON DELETE CASCADE;


--
-- Name: legacy_works legacy_works_series_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_works
    ADD CONSTRAINT legacy_works_series_id_fkey FOREIGN KEY (series_id) REFERENCES public.legacy_series(id) ON DELETE SET NULL;


--
-- Name: relation_types relation_types_domain_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relation_types
    ADD CONSTRAINT relation_types_domain_kind_fkey FOREIGN KEY (domain_kind) REFERENCES public.res_kinds(code);


--
-- Name: relation_types relation_types_parent_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relation_types
    ADD CONSTRAINT relation_types_parent_fkey FOREIGN KEY (parent) REFERENCES public.relation_types(code);


--
-- Name: relation_types relation_types_range_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relation_types
    ADD CONSTRAINT relation_types_range_kind_fkey FOREIGN KEY (range_kind) REFERENCES public.res_kinds(code);


--
-- Name: roles roles_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_res_kind_fkey FOREIGN KEY (res_kind) REFERENCES public.res_kinds(code);


--
-- PostgreSQL database dump complete
--


