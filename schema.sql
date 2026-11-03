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
-- Name: person_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.person_names (
    id bigint NOT NULL,
    person_id bigint NOT NULL,
    name_type text DEFAULT 'preferred'::text NOT NULL,
    entry text DEFAULT 'family'::text NOT NULL,
    name_order text DEFAULT 'given_first'::text NOT NULL,
    culture text,
    family_name text,
    given_name text,
    patronymic text,
    particle text,
    particle_in_entry boolean,
    particle_joined boolean,
    predicate text,
    epithet text,
    noble_title text,
    numeral integer,
    generational text,
    generational_ordinal integer,
    qualifier text,
    heading_override text,
    display_override text,
    sort_override text,
    lang text,
    script text DEFAULT 'Latn'::text NOT NULL,
    derived_from bigint,
    conversion_scheme text,
    basis text,
    certainty text DEFAULT 'certain'::text NOT NULL,
    note text,
    citation_name text,
    CONSTRAINT person_names_check CHECK (((conversion_scheme IS NULL) OR (derived_from IS NOT NULL))),
    CONSTRAINT person_names_check1 CHECK (((family_name IS NOT NULL) OR (given_name IS NOT NULL) OR (heading_override IS NOT NULL))),
    CONSTRAINT person_names_check2 CHECK (((entry = 'given'::text) OR (family_name IS NOT NULL) OR (heading_override IS NOT NULL))),
    CONSTRAINT person_names_check3 CHECK (((generational = 'ordinal'::text) = (generational_ordinal IS NOT NULL))),
    CONSTRAINT person_names_entry_check CHECK ((entry = ANY (ARRAY['family'::text, 'given'::text]))),
    CONSTRAINT person_names_generational_ordinal_check CHECK ((generational_ordinal > 1)),
    CONSTRAINT person_names_name_order_check CHECK ((name_order = ANY (ARRAY['family_first'::text, 'given_first'::text]))),
    CONSTRAINT person_names_numeral_check CHECK ((numeral > 0))
);


--
-- Name: COLUMN person_names.citation_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.person_names.citation_name IS 'name used in citation labels when it differs from the entry element (e.g. Jacobus de Voragine)';


--
-- Name: generational_label(public.person_names, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generational_label(n public.person_names, p_lang text) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT CASE WHEN n.generational = 'ordinal' THEN to_char(n.generational_ordinal, 'FMRN')
        ELSE coalesce(
            (SELECT label FROM public.generational_labels WHERE code = n.generational AND lang = p_lang),
            (SELECT label FROM public.generational_labels WHERE code = n.generational AND lang = n.lang),
            (SELECT label FROM public.generational_labels WHERE code = n.generational AND lang = 'en'))
        END
$$;


--
-- Name: heading_resolution_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.heading_resolution_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.catalogue_headings WHERE id = NEW.heading_id AND rejected IS NOT NULL) THEN
        RAISE EXCEPTION 'heading % is rejected and cannot be resolved', NEW.heading_id;
    END IF;
    RETURN NEW;
END $$;


--
-- Name: identifier_checksum_ok(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.identifier_checksum_ok(p_scheme text, p_normalized text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
    s int := 0;
    d int;
    i int;
BEGIN
    IF p_scheme = 'isbn' AND p_normalized ~ '^[0-9]{9}[0-9X]$' THEN
        FOR i IN 1..10 LOOP
            d := CASE WHEN substr(p_normalized, i, 1) = 'X' THEN 10 ELSE substr(p_normalized, i, 1)::int END;
            s := s + (11 - i) * d;
        END LOOP;
        RETURN s % 11 = 0;
    ELSIF p_scheme = 'isbn' AND p_normalized ~ '^[0-9]{13}$' THEN
        FOR i IN 1..13 LOOP
            s := s + substr(p_normalized, i, 1)::int * CASE WHEN i % 2 = 0 THEN 3 ELSE 1 END;
        END LOOP;
        RETURN s % 10 = 0;
    ELSIF p_scheme IN ('issn', 'issn_l') AND p_normalized ~ '^[0-9]{7}[0-9X]$' THEN
        FOR i IN 1..7 LOOP
            s := s + (9 - i) * substr(p_normalized, i, 1)::int;
        END LOOP;
        d := (11 - s % 11) % 11;
        RETURN substr(p_normalized, 8, 1) = CASE WHEN d = 10 THEN 'X' ELSE d::text END;
    ELSIF p_scheme = 'orcid' AND replace(p_normalized, '-', '') ~ '^[0-9]{15}[0-9X]$' THEN
        FOR i IN 1..15 LOOP
            s := (s + substr(replace(p_normalized, '-', ''), i, 1)::int) * 2;
        END LOOP;
        d := (12 - s % 11) % 11;
        RETURN right(p_normalized, 1) = CASE WHEN d = 10 THEN 'X' ELSE d::text END;
    ELSIF p_scheme IN ('isbn', 'issn', 'issn_l', 'orcid') THEN
        RETURN false;  -- wrong length or characters
    END IF;
    RETURN NULL;
END $_$;


--
-- Name: identifiers_check_kind(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.identifiers_check_kind() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_kind text;
BEGIN
    SELECT res_kind INTO v_kind FROM public.identifier_schemes WHERE code = NEW.scheme;
    IF v_kind IS NOT NULL AND v_kind <> NEW.res_kind THEN
        RAISE EXCEPTION 'identifier scheme % applies to %, not to %', NEW.scheme, v_kind, NEW.res_kind;
    END IF;
    RETURN NEW;
END $$;


--
-- Name: lo_bibliography_rows(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lo_bibliography_rows(p_scope text, p_id bigint DEFAULT NULL::bigint) RETURNS TABLE(manifestation_id bigint, "Identifier" text, "BibliographyType" integer, "Author" text, "Editor" text, "Title" text, "Subtitle" text, "Year" text, "Publisher" text, "Address" text, "Journal" text, "Volume" text, "Number" text, "Pages" text, "ISBN" text, "URL" text, "Custom1" text, "Custom2" text, "Custom3" text, "Note" text, "Annote" text, "Booktitle" text, "Chapter" text, "Edition" text, "Howpublished" text, "Institution" text, "Month" text, "Organizations" text, "School" text, "Series" text, "ReportType" text, "Custom4" text, "Custom5" text, "LocalURL" text)
    LANGUAGE sql STABLE
    AS $_$
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
$_$;


--
-- Name: FUNCTION lo_bibliography_rows(p_scope text, p_id bigint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.lo_bibliography_rows(p_scope text, p_id bigint) IS 'LibreOffice bibliography rows of a scope: global, project (projects.id), document (documents.work_id)';


--
-- Name: lo_sync(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lo_sync() RETURNS void
    LANGUAGE plpgsql
    AS $$
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
END $$;


--
-- Name: FUNCTION lo_sync(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.lo_sync() IS 'create/drop the LibreOffice views lo_project_<code> and lo_document_<code>';


--
-- Name: lo_sync_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lo_sync_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM public.lo_sync();
    RETURN NULL;
END $$;


--
-- Name: new_agent(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.new_agent(p_type text) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE v_id bigint;
BEGIN
    INSERT INTO public.res (kind) VALUES ('agent') RETURNING id INTO v_id;
    INSERT INTO public.agents (id, agent_type) VALUES (v_id, p_type);
    RETURN v_id;
END $$;


--
-- Name: new_res(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.new_res(p_kind text) RETURNS bigint
    LANGUAGE sql
    AS $$ INSERT INTO public.res (kind) VALUES (p_kind) RETURNING id $$;


--
-- Name: normalize_identifier(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_identifier(p_scheme text, p_value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT CASE
        WHEN p_scheme IN ('isbn', 'issn', 'issn_l') THEN upper(regexp_replace(p_value, '[^0-9Xx]', '', 'g'))
        WHEN p_scheme = 'doi'   THEN lower(regexp_replace(btrim(p_value), '^(https?://(dx\.)?doi\.org/|doi:)', '', 'i'))
        -- full URI, shortened orcid.org/… form (ORCID display guidelines) or an informal ORCID: prefix
        -- canonical form 0000-0000-0000-000X, also from unhyphenated input
        WHEN p_scheme = 'orcid' THEN regexp_replace(
            upper(regexp_replace(regexp_replace(btrim(p_value), '^((https?://)?(www\.)?orcid\.org/|orcid:\s*)', '', 'i'), '[\s-]', '', 'g')),
            '^(.{4})(.{4})(.{4})(.{4})$', '\1-\2-\3-\4')
        WHEN p_scheme = 'wikidata' THEN upper(btrim(p_value))
        ELSE btrim(p_value) END
$_$;


--
-- Name: normalize_particle(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_particle(p text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$ SELECT lower(replace(btrim(p), '’', '''')) $$;


--
-- Name: particle_in_entry(public.person_names); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.particle_in_entry(n public.person_names) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$ SELECT coalesce(n.particle_in_entry, public.particle_rule(n.particle, n.culture)) $$;


--
-- Name: particle_joiner(text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.particle_joiner(p_particle text, p_joined boolean) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN coalesce(p_joined, public.normalize_particle(p_particle) LIKE '%''') THEN ''
        ELSE ' ' END
$$;


--
-- Name: particle_rule(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.particle_rule(p_particle text, p_culture text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
    SELECT coalesce(
        (SELECT in_entry FROM public.particle_rules
          WHERE particle = public.normalize_particle(p_particle) AND culture = p_culture),
        (SELECT in_entry FROM public.particle_rules
          WHERE particle = split_part(public.normalize_particle(p_particle), ' ', 1) AND culture = p_culture),
        (SELECT particles_in_entry FROM public.name_cultures WHERE code = p_culture))
$$;


--
-- Name: person_name_display(public.person_names, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.person_name_display(n public.person_names, p_locale text) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    pl     record;
    pre    text[] := '{}';
    post   text[] := '{}';
    core   text;
    fam    text;
    gen    text := public.generational_label(n, p_locale);
    num    text := to_char(n.numeral, 'FMRN');
BEGIN
    IF n.display_override IS NOT NULL THEN
        RETURN n.display_override;
    END IF;
    IF n.family_name IS NULL AND n.given_name IS NULL THEN
        RETURN n.heading_override;
    END IF;
    SELECT
        coalesce((SELECT position FROM public.name_element_placements WHERE locale = p_locale AND element = 'numeral'),      'after') AS numeral,
        coalesce((SELECT position FROM public.name_element_placements WHERE locale = p_locale AND element = 'generational'), 'after') AS generational,
        coalesce((SELECT position FROM public.name_element_placements WHERE locale = p_locale AND element = 'epithet'),      'after') AS epithet,
        coalesce((SELECT position FROM public.name_element_placements WHERE locale = p_locale AND element = 'predicate'),    'before') AS predicate
      INTO pl;

    IF gen IS NOT NULL THEN
        IF pl.generational = 'before' THEN pre := pre || gen; ELSE post := post || gen; END IF;
    END IF;
    IF num IS NOT NULL THEN
        IF pl.numeral = 'before' THEN pre := pre || (num || '.'); ELSE post := post || num; END IF;
    END IF;
    IF n.predicate IS NOT NULL THEN
        IF pl.predicate = 'before' THEN pre := pre || n.predicate; ELSE post := post || n.predicate; END IF;
    END IF;
    IF n.epithet IS NOT NULL THEN
        IF pl.epithet = 'before' THEN pre := pre || n.epithet; ELSE post := post || n.epithet; END IF;
    END IF;

    fam := CASE WHEN n.particle IS NOT NULL
                THEN n.particle || public.particle_joiner(n.particle, n.particle_joined) || n.family_name
                ELSE n.family_name END;
    IF n.name_order = 'family_first' AND p_locale = 'hu' THEN
        core := concat_ws(' ', fam, n.given_name, n.patronymic);
    ELSE
        core := concat_ws(' ', n.given_name, n.patronymic, fam);
    END IF;

    RETURN concat_ws(' ', nullif(array_to_string(pre, ' '), ''), core, nullif(array_to_string(post, ' '), ''))
        || coalesce(', ' || n.noble_title, '');
END $$;


--
-- Name: person_name_entry(public.person_names); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.person_name_entry(n public.person_names) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT CASE
        WHEN n.entry = 'given' THEN n.given_name
        WHEN n.particle IS NOT NULL AND public.particle_in_entry(n) IS TRUE
            THEN n.particle || public.particle_joiner(n.particle, n.particle_joined) || n.family_name
        ELSE n.family_name END
$$;


--
-- Name: person_name_heading(public.person_names); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.person_name_heading(n public.person_names) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT coalesce(n.heading_override,
        public.person_name_entry(n)
        || coalesce(CASE WHEN n.name_order = 'family_first' THEN ' ' ELSE ', ' END || public.person_name_rest(n), '')
        || coalesce(' (' || n.qualifier || ')', '')
        || coalesce(', ' || to_char(n.numeral, 'FMRN') || '.', '')
        || coalesce(', ' || n.epithet, '')
        || coalesce(', ' || n.predicate, '')
        || coalesce(', ' || n.noble_title, '')
        || coalesce(' (' || public.generational_label(n, coalesce(n.lang, 'hu')) || ')', ''))
$$;


--
-- Name: person_name_heading_full(public.person_names); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.person_name_heading_full(n public.person_names) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT public.person_name_heading(n) || coalesce(' (' || (
        SELECT CASE
            WHEN p.birth_text IS NOT NULL OR p.death_text IS NOT NULL
                THEN coalesce(p.birth_text, '') || '-' || coalesce(p.death_text, '')
            ELSE p.floruit_text END
          FROM public.persons p WHERE p.id = n.person_id) || ')', '')
$$;


--
-- Name: person_name_rest(public.person_names); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.person_name_rest(n public.person_names) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT nullif(concat_ws(' ',
        CASE WHEN n.entry = 'family' THEN n.given_name END,
        n.patronymic,
        CASE WHEN n.entry = 'family' AND n.particle IS NOT NULL
              AND public.particle_in_entry(n) IS NOT TRUE THEN n.particle END), '')
$$;


--
-- Name: res_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.res_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM public.res WHERE id = OLD.id;
    RETURN NULL;
END $$;


--
-- Name: touch_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END $$;


--
-- Name: agent_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_types (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    lrm_id text
);


--
-- Name: agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agents (
    id bigint NOT NULL,
    kind text DEFAULT 'agent'::text NOT NULL,
    agent_type text NOT NULL,
    note text,
    CONSTRAINT agents_kind_check CHECK ((kind = 'agent'::text))
);


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
-- Name: cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cards (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    res_id bigint NOT NULL,
    res_kind text NOT NULL,
    locator text,
    title text NOT NULL,
    body text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cards_res_kind_check CHECK ((res_kind = ANY (ARRAY['work'::text, 'expression'::text, 'manifestation'::text, 'item'::text])))
);


--
-- Name: TABLE cards; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cards IS 'titled texts of a project about one entry, at a locator (e.g. "f. 223v"); several cards per entry';


--
-- Name: cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.cards ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.cards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: catalogue_headings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.catalogue_headings (
    id bigint NOT NULL,
    work_id bigint NOT NULL,
    record_id bigint NOT NULL,
    function text NOT NULL,
    vocabulary text NOT NULL,
    tag text NOT NULL,
    indicators text DEFAULT '  '::text NOT NULL,
    value text NOT NULL,
    subfields jsonb NOT NULL,
    authority_uri text,
    "position" integer NOT NULL,
    rejected text,
    note text,
    CONSTRAINT catalogue_headings_indicators_check CHECK ((length(indicators) = 2)),
    CONSTRAINT catalogue_headings_position_check CHECK (("position" > 0)),
    CONSTRAINT catalogue_headings_rejected_check CHECK ((rejected <> ''::text)),
    CONSTRAINT catalogue_headings_subfields_check CHECK ((jsonb_typeof(subfields) = 'array'::text)),
    CONSTRAINT catalogue_headings_tag_check CHECK ((tag ~ '^[0-9]{3}$'::text))
);


--
-- Name: TABLE catalogue_headings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.catalogue_headings IS 'access points of a catalogue record as recorded (nomens); record_id is the record''s identifier on the manifestation, work_id the work it describes';


--
-- Name: COLUMN catalogue_headings.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalogue_headings.value IS 'the heading as a string: subfields joined (" -- " between subdivisions)';


--
-- Name: COLUMN catalogue_headings.subfields; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalogue_headings.subfields IS 'the field''s subfields in order, [["a", "Cryptography"], ["z", "Hungary"]]';


--
-- Name: COLUMN catalogue_headings."position"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalogue_headings."position" IS 'order of the field among the record''s access points';


--
-- Name: COLUMN catalogue_headings.rejected; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalogue_headings.rejected IS 'why the heading is not accepted for the work (e.g. a form term that describes its subject, not the work); a rejected heading stays as recorded and is not resolved';


--
-- Name: catalogue_headings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.catalogue_headings ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.catalogue_headings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
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
-- Name: citations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.citations (
    id bigint NOT NULL,
    citing_expression_id bigint NOT NULL,
    citing_manifestation_id bigint,
    citing_locator text,
    citing_note text,
    citing_note_locator text,
    cited_id bigint NOT NULL,
    cited_kind text NOT NULL,
    cited_locator text,
    "position" integer,
    basis text,
    note text,
    CONSTRAINT citations_cited_kind_check CHECK ((cited_kind = ANY (ARRAY['manifestation'::text, 'item'::text]))),
    CONSTRAINT citations_position_check CHECK (("position" > 0))
);


--
-- Name: TABLE citations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.citations IS 'a text citing a manifestation or item; one row per citation (a pair may recur in several notes)';


--
-- Name: COLUMN citations.citing_manifestation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.citations.citing_manifestation_id IS 'the manifestation whose pagination the citing locators refer to; NULL for an unpublished text';


--
-- Name: COLUMN citations.citing_locator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.citations.citing_locator IS 'where the reference stands, e.g. "p. 191"';


--
-- Name: COLUMN citations.citing_note; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.citations.citing_note IS 'the note carrying the reference, e.g. "n. 8"';


--
-- Name: COLUMN citations.citing_note_locator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.citations.citing_note_locator IS 'where the note itself stands, e.g. "p. 195" (endnotes)';


--
-- Name: COLUMN citations.cited_locator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.citations.cited_locator IS 'the part of the cited entry referred to, e.g. "esp. 15, 18–19"';


--
-- Name: COLUMN citations."position"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.citations."position" IS 'order among the references of the same note or place';


--
-- Name: citations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.citations ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.citations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: collective_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collective_categories (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text
);


--
-- Name: collective_name_attestations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collective_name_attestations (
    id bigint NOT NULL,
    name_id bigint NOT NULL,
    res_id bigint,
    source_text text,
    locator text,
    note text,
    CONSTRAINT collective_name_attestations_check CHECK (((res_id IS NOT NULL) OR (source_text IS NOT NULL)))
);


--
-- Name: collective_name_attestations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.collective_name_attestations ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.collective_name_attestations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: collective_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collective_names (
    id bigint NOT NULL,
    collective_id bigint NOT NULL,
    name_type text DEFAULT 'preferred'::text NOT NULL,
    value text NOT NULL,
    valid_from_year integer,
    valid_to_year integer,
    lang text,
    script text DEFAULT 'Latn'::text NOT NULL,
    derived_from bigint,
    conversion_scheme text,
    basis text,
    certainty text DEFAULT 'certain'::text NOT NULL,
    note text,
    CONSTRAINT collective_names_check CHECK (((conversion_scheme IS NULL) OR (derived_from IS NOT NULL))),
    CONSTRAINT collective_names_check1 CHECK ((valid_to_year >= valid_from_year))
);


--
-- Name: collective_names_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.collective_names ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.collective_names_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: collectives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collectives (
    id bigint DEFAULT public.new_agent('collective'::text) NOT NULL,
    agent_type text DEFAULT 'collective'::text NOT NULL,
    category text NOT NULL,
    parent_id bigint,
    start_text text,
    start_year integer,
    end_text text,
    end_year integer,
    note text,
    CONSTRAINT collectives_agent_type_check CHECK ((agent_type = 'collective'::text))
);


--
-- Name: COLUMN collectives.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.collectives.parent_id IS 'LRM-R31: the larger collective this one is part of';


--
-- Name: concept_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concept_categories (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text
);


--
-- Name: concept_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concept_names (
    id bigint NOT NULL,
    concept_id bigint NOT NULL,
    value text NOT NULL,
    lang text,
    is_preferred boolean DEFAULT false NOT NULL,
    note text
);


--
-- Name: TABLE concept_names; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.concept_names IS 'our labels of a concept, one preferred per language; the catalogues'' forms are in catalogue_headings';


--
-- Name: concept_names_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.concept_names ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.concept_names_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: concepts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.concepts (
    id bigint DEFAULT public.new_res('concept'::text) NOT NULL,
    kind text DEFAULT 'concept'::text NOT NULL,
    category text DEFAULT 'topic'::text NOT NULL,
    note text,
    CONSTRAINT concepts_kind_check CHECK ((kind = 'concept'::text))
);


--
-- Name: contributions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contributions (
    id bigint NOT NULL,
    res_id bigint NOT NULL,
    res_kind text NOT NULL,
    agent_id bigint NOT NULL,
    agent_kind text DEFAULT 'agent'::text NOT NULL,
    role text NOT NULL,
    "position" integer DEFAULT 1 NOT NULL,
    basis text,
    certainty text DEFAULT 'certain'::text NOT NULL,
    note text,
    CONSTRAINT contributions_agent_kind_check CHECK ((agent_kind = 'agent'::text)),
    CONSTRAINT contributions_position_check CHECK (("position" > 0))
);


--
-- Name: contributions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.contributions ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.contributions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
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
-- Name: document_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_statuses (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text NOT NULL,
    "position" integer NOT NULL
);


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    work_id bigint NOT NULL,
    expression_id bigint NOT NULL,
    project_id bigint NOT NULL,
    code text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    note text,
    CONSTRAINT documents_code_check CHECK ((code ~ '^[a-z][a-z0-9_]{0,39}$'::text))
);


--
-- Name: TABLE documents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.documents IS 'own writings: the work, the expression being written (whose citations make its bibliography), project and status; code names the generated LibreOffice view (lo_document_<code>)';


--
-- Name: expressions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expressions (
    id bigint DEFAULT public.new_res('expression'::text) NOT NULL,
    kind text DEFAULT 'expression'::text NOT NULL,
    work_id bigint NOT NULL,
    lang text,
    script text,
    date_text text,
    date_sort integer,
    date_sort_end integer,
    note text,
    CONSTRAINT expressions_check CHECK ((date_sort_end >= date_sort)),
    CONSTRAINT expressions_kind_check CHECK ((kind = 'expression'::text))
);


--
-- Name: COLUMN expressions.work_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.expressions.work_id IS 'LRM-R2: the one work this expression realizes';


--
-- Name: generational_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.generational_labels (
    code text NOT NULL,
    lang text NOT NULL,
    label text NOT NULL
);


--
-- Name: generational_markers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.generational_markers (
    code text NOT NULL,
    label_en text NOT NULL
);


--
-- Name: heading_functions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heading_functions (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    marc text NOT NULL
);


--
-- Name: heading_resolutions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heading_resolutions (
    heading_id bigint NOT NULL,
    res_id bigint NOT NULL,
    res_kind text NOT NULL,
    part integer,
    certainty text DEFAULT 'certain'::text NOT NULL,
    note text,
    CONSTRAINT heading_resolutions_part_check CHECK ((part > 0))
);


--
-- Name: TABLE heading_resolutions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.heading_resolutions IS 'the res a heading designates; part = the subfield (1-based, in subfields) for one part of a pre-coordinated heading, NULL for the whole';


--
-- Name: heading_vocabularies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heading_vocabularies (
    code text NOT NULL,
    label text NOT NULL,
    marc text NOT NULL,
    note text
);


--
-- Name: TABLE heading_vocabularies; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.heading_vocabularies IS 'where a heading''s form comes from: a subject vocabulary, a classification, or none (as the record codes it)';


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
-- Name: identifiers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identifiers (
    id bigint NOT NULL,
    res_id bigint NOT NULL,
    res_kind text NOT NULL,
    scheme text NOT NULL,
    value text NOT NULL,
    normalized text GENERATED ALWAYS AS (public.normalize_identifier(scheme, value)) STORED NOT NULL,
    status text DEFAULT 'valid'::text NOT NULL,
    qualifier text,
    assigned_by bigint,
    assigned_by_kind text DEFAULT 'agent'::text NOT NULL,
    corrects bigint,
    basis text,
    note text,
    checked_on_success date,
    checked_on_error date,
    CONSTRAINT identifiers_assigned_by_kind_check CHECK ((assigned_by_kind = 'agent'::text)),
    CONSTRAINT identifiers_check CHECK ((corrects <> id))
);


--
-- Name: COLUMN identifiers.checked_on_success; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.identifiers.checked_on_success IS 'last date the identifier or its permalink was successfully checked against the issuing service';


--
-- Name: COLUMN identifiers.checked_on_error; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.identifiers.checked_on_error IS 'last date a check failed (not cleared by a later success: both dates are kept)';


--
-- Name: identifiers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.identifiers ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.identifiers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: imprint_agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imprint_agents (
    imprint_id bigint NOT NULL,
    "position" integer NOT NULL,
    agent_id bigint,
    agent_kind text DEFAULT 'agent'::text NOT NULL,
    as_printed text,
    basis text DEFAULT 'transcribed'::text NOT NULL,
    certainty text DEFAULT 'certain'::text NOT NULL,
    note text,
    person_name_id bigint,
    collective_name_id bigint,
    CONSTRAINT imprint_agents_agent_kind_check CHECK ((agent_kind = 'agent'::text)),
    CONSTRAINT imprint_agents_check CHECK (((agent_id IS NOT NULL) OR (as_printed IS NOT NULL))),
    CONSTRAINT imprint_agents_check1 CHECK ((num_nonnulls(person_name_id, collective_name_id) <= 1)),
    CONSTRAINT imprint_agents_position_check CHECK (("position" > 0))
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
-- Name: imprint_places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imprint_places (
    imprint_id bigint NOT NULL,
    "position" integer NOT NULL,
    place_id bigint,
    place_kind text DEFAULT 'place'::text NOT NULL,
    as_printed text,
    basis text DEFAULT 'transcribed'::text NOT NULL,
    certainty text DEFAULT 'certain'::text NOT NULL,
    note text,
    CONSTRAINT imprint_places_check CHECK (((place_id IS NOT NULL) OR (as_printed IS NOT NULL))),
    CONSTRAINT imprint_places_place_kind_check CHECK ((place_kind = 'place'::text)),
    CONSTRAINT imprint_places_position_check CHECK (("position" > 0))
);


--
-- Name: imprints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imprints (
    id bigint NOT NULL,
    manifestation_id bigint NOT NULL,
    function text DEFAULT 'publication'::text NOT NULL,
    "position" integer DEFAULT 1 NOT NULL,
    date_as_printed text,
    date_text text,
    date_sort integer,
    date_sort_end integer,
    date_basis text,
    date_certainty text DEFAULT 'certain'::text NOT NULL,
    lang text,
    script text DEFAULT 'Latn'::text NOT NULL,
    derived_from bigint,
    conversion_scheme text,
    note text,
    CONSTRAINT imprints_check CHECK (((conversion_scheme IS NULL) OR (derived_from IS NOT NULL))),
    CONSTRAINT imprints_check1 CHECK ((date_sort_end >= date_sort)),
    CONSTRAINT imprints_position_check CHECK (("position" > 0))
);


--
-- Name: COLUMN imprints.date_as_printed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.imprints.date_as_printed IS 'the date exactly as on the resource (e.g. 1985 where 1958 is correct)';


--
-- Name: COLUMN imprints.date_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.imprints.date_text IS 'the established date as to be displayed';


--
-- Name: imprints_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.imprints ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.imprints_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.items (
    id bigint DEFAULT public.new_res('item'::text) NOT NULL,
    kind text DEFAULT 'item'::text NOT NULL,
    manifestation_id bigint NOT NULL,
    holder_id bigint,
    holder_kind text DEFAULT 'agent'::text NOT NULL,
    location text,
    path text,
    url text,
    mime_type text,
    note text,
    CONSTRAINT items_holder_kind_check CHECK ((holder_kind = 'agent'::text)),
    CONSTRAINT items_kind_check CHECK ((kind = 'item'::text))
);


--
-- Name: COLUMN items.location; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.items.location IS 'place within the holding (room, shelf); not a shelfmark — shelfmarks are identifiers';


--
-- Name: COLUMN items.path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.items.path IS 'local file path of a digital item';


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
-- Name: lo_bibliography; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.lo_bibliography AS
 SELECT "Identifier",
    "BibliographyType",
    "Author",
    "Editor",
    "Title",
    "Subtitle",
    "Year",
    "Publisher",
    "Address",
    "Journal",
    "Volume",
    "Number",
    "Pages",
    "ISBN",
    "URL",
    "Custom1",
    "Custom2",
    "Custom3",
    "Note",
    "Annote",
    "Booktitle",
    "Chapter",
    "Edition",
    "Howpublished",
    "Institution",
    "Month",
    "Organizations",
    "School",
    "Series",
    "ReportType",
    "Custom4",
    "Custom5",
    "LocalURL"
   FROM public.lo_bibliography_rows('global'::text) lo_bibliography_rows(manifestation_id, "Identifier", "BibliographyType", "Author", "Editor", "Title", "Subtitle", "Year", "Publisher", "Address", "Journal", "Volume", "Number", "Pages", "ISBN", "URL", "Custom1", "Custom2", "Custom3", "Note", "Annote", "Booktitle", "Chapter", "Edition", "Howpublished", "Institution", "Month", "Organizations", "School", "Series", "ReportType", "Custom4", "Custom5", "LocalURL");


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
-- Name: manifestation_expressions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manifestation_expressions (
    manifestation_id bigint NOT NULL,
    expression_id bigint NOT NULL,
    "position" integer DEFAULT 1 NOT NULL,
    CONSTRAINT manifestation_expressions_position_check CHECK (("position" > 0))
);


--
-- Name: manifestation_statements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manifestation_statements (
    id bigint NOT NULL,
    manifestation_id bigint NOT NULL,
    statement_type text NOT NULL,
    source text,
    value text NOT NULL,
    lang text,
    script text DEFAULT 'Latn'::text NOT NULL,
    derived_from bigint,
    conversion_scheme text,
    basis text DEFAULT 'transcribed'::text NOT NULL,
    certainty text DEFAULT 'certain'::text NOT NULL,
    "position" integer DEFAULT 1 NOT NULL,
    note text,
    CONSTRAINT manifestation_statements_check CHECK (((conversion_scheme IS NULL) OR (derived_from IS NOT NULL))),
    CONSTRAINT manifestation_statements_position_check CHECK (("position" > 0))
);


--
-- Name: manifestation_statements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.manifestation_statements ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.manifestation_statements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: manifestations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manifestations (
    id bigint DEFAULT public.new_res('manifestation'::text) NOT NULL,
    kind text DEFAULT 'manifestation'::text NOT NULL,
    category text NOT NULL,
    extent text,
    note text,
    CONSTRAINT manifestations_kind_check CHECK ((kind = 'manifestation'::text))
);


--
-- Name: person_name_attestations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.person_name_attestations (
    id bigint NOT NULL,
    name_id bigint NOT NULL,
    res_id bigint,
    source_text text,
    locator text,
    note text,
    CONSTRAINT person_name_attestations_check CHECK (((res_id IS NOT NULL) OR (source_text IS NOT NULL)))
);


--
-- Name: statement_agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.statement_agents (
    statement_id bigint NOT NULL,
    "position" integer NOT NULL,
    agent_id bigint,
    agent_kind text DEFAULT 'agent'::text NOT NULL,
    person_name_id bigint,
    collective_name_id bigint,
    as_printed text,
    basis text DEFAULT 'transcribed'::text NOT NULL,
    certainty text DEFAULT 'certain'::text NOT NULL,
    note text,
    CONSTRAINT statement_agents_agent_kind_check CHECK ((agent_kind = 'agent'::text)),
    CONSTRAINT statement_agents_check CHECK (((agent_id IS NOT NULL) OR (as_printed IS NOT NULL))),
    CONSTRAINT statement_agents_check1 CHECK ((num_nonnulls(person_name_id, collective_name_id) <= 1)),
    CONSTRAINT statement_agents_position_check CHECK (("position" > 0))
);


--
-- Name: name_attestations; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.name_attestations AS
 SELECT 'person'::text AS name_kind,
    a.name_id,
    'attestation'::text AS via,
    a.res_id,
    a.source_text,
    a.locator
   FROM public.person_name_attestations a
UNION ALL
 SELECT 'collective'::text AS name_kind,
    a.name_id,
    'attestation'::text AS via,
    a.res_id,
    a.source_text,
    a.locator
   FROM public.collective_name_attestations a
UNION ALL
 SELECT
        CASE
            WHEN (sa.person_name_id IS NOT NULL) THEN 'person'::text
            ELSE 'collective'::text
        END AS name_kind,
    COALESCE(sa.person_name_id, sa.collective_name_id) AS name_id,
    'statement'::text AS via,
    ms.manifestation_id AS res_id,
    NULL::text AS source_text,
    ms.source AS locator
   FROM (public.statement_agents sa
     JOIN public.manifestation_statements ms ON ((ms.id = sa.statement_id)))
  WHERE (num_nonnulls(sa.person_name_id, sa.collective_name_id) = 1)
UNION ALL
 SELECT
        CASE
            WHEN (ia.person_name_id IS NOT NULL) THEN 'person'::text
            ELSE 'collective'::text
        END AS name_kind,
    COALESCE(ia.person_name_id, ia.collective_name_id) AS name_id,
    'imprint'::text AS via,
    im.manifestation_id AS res_id,
    NULL::text AS source_text,
    im.function AS locator
   FROM (public.imprint_agents ia
     JOIN public.imprints im ON ((im.id = ia.imprint_id)))
  WHERE (num_nonnulls(ia.person_name_id, ia.collective_name_id) = 1);


--
-- Name: name_cultures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.name_cultures (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    kind text NOT NULL,
    particles_in_entry boolean,
    note text,
    CONSTRAINT name_cultures_kind_check CHECK ((kind = ANY (ARRAY['nation'::text, 'language_area'::text])))
);


--
-- Name: name_element_placements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.name_element_placements (
    locale text NOT NULL,
    element text NOT NULL,
    "position" text NOT NULL,
    CONSTRAINT name_element_placements_element_check CHECK ((element = ANY (ARRAY['numeral'::text, 'generational'::text, 'epithet'::text, 'predicate'::text]))),
    CONSTRAINT name_element_placements_position_check CHECK (("position" = ANY (ARRAY['before'::text, 'after'::text])))
);


--
-- Name: name_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.name_types (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    note text
);


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    title text NOT NULL,
    body text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE notes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.notes IS 'titled texts of a project (body in Markdown)';


--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.notes ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: particle_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.particle_rules (
    particle text NOT NULL,
    culture text NOT NULL,
    in_entry boolean NOT NULL,
    CONSTRAINT particle_rules_particle_check CHECK (((particle = lower(particle)) AND (particle !~ '’'::text)))
);


--
-- Name: person_name_attestations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.person_name_attestations ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.person_name_attestations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: person_names_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.person_names ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.person_names_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: person_names_rendered; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.person_names_rendered AS
 SELECT id,
    person_id,
    name_type,
    script,
    public.person_name_heading(n.*) AS heading,
    public.person_name_heading_full(n.*) AS heading_full,
    public.person_name_display(n.*, 'hu'::text) AS display_hu,
    public.person_name_display(n.*, 'en'::text) AS display_en,
    (COALESCE(sort_override, public.person_name_entry(n.*)) COLLATE "hu-HU-x-icu") AS sort_entry,
    (
        CASE
            WHEN (sort_override IS NULL) THEN concat_ws(' '::text, public.person_name_rest(n.*), epithet, predicate)
            ELSE NULL::text
        END COLLATE "hu-HU-x-icu") AS sort_rest,
    numeral AS sort_numeral
   FROM public.person_names n;


--
-- Name: persons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persons (
    id bigint DEFAULT public.new_agent('person'::text) NOT NULL,
    agent_type text DEFAULT 'person'::text NOT NULL,
    birth_text text,
    birth_year integer,
    death_text text,
    death_year integer,
    floruit_text text,
    note text,
    CONSTRAINT persons_agent_type_check CHECK ((agent_type = 'person'::text))
);


--
-- Name: COLUMN persons.birth_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.persons.birth_text IS 'as to be displayed, e.g. 1824, 1824?, ca. 1500';


--
-- Name: COLUMN persons.floruit_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.persons.floruit_text IS 'period of activity when life dates are unknown, e.g. 15. sz. (KSZ4 4.2)';


--
-- Name: place_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.place_categories (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text
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
-- Name: place_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.place_names (
    id bigint NOT NULL,
    place_id bigint NOT NULL,
    name_type text DEFAULT 'official'::text NOT NULL,
    value text NOT NULL,
    is_preferred boolean DEFAULT false NOT NULL,
    valid_from_year integer,
    valid_to_year integer,
    lang text,
    script text DEFAULT 'Latn'::text NOT NULL,
    derived_from bigint,
    conversion_scheme text,
    basis text,
    certainty text DEFAULT 'certain'::text NOT NULL,
    reference_source text,
    note text,
    CONSTRAINT place_names_check CHECK (((conversion_scheme IS NULL) OR (derived_from IS NOT NULL))),
    CONSTRAINT place_names_check1 CHECK ((valid_to_year >= valid_from_year))
);


--
-- Name: place_names_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.place_names ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.place_names_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.places (
    id bigint DEFAULT public.new_res('place'::text) NOT NULL,
    kind text DEFAULT 'place'::text NOT NULL,
    category text NOT NULL,
    parent_id bigint,
    note text,
    CONSTRAINT places_kind_check CHECK ((kind = 'place'::text))
);


--
-- Name: COLUMN places.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.places.parent_id IS 'LRM-R34: the larger place this one is part of';


--
-- Name: project_member_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_member_sections (
    project_id bigint NOT NULL,
    res_id bigint NOT NULL,
    section_id bigint NOT NULL
);


--
-- Name: project_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_members (
    project_id bigint NOT NULL,
    res_id bigint NOT NULL,
    res_kind text NOT NULL,
    added_on date DEFAULT CURRENT_DATE NOT NULL,
    note text,
    CONSTRAINT project_members_res_kind_check CHECK ((res_kind = ANY (ARRAY['work'::text, 'expression'::text, 'manifestation'::text, 'item'::text])))
);


--
-- Name: TABLE project_members; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.project_members IS 'what a project collects; in LibreOffice views a manifestation (an item counts as its manifestation)';


--
-- Name: project_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_sections (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    parent_id bigint,
    label text NOT NULL,
    "position" integer DEFAULT 1 NOT NULL,
    note text,
    CONSTRAINT project_sections_check CHECK ((parent_id <> id)),
    CONSTRAINT project_sections_position_check CHECK (("position" > 0))
);


--
-- Name: TABLE project_sections; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.project_sections IS 'outline of a project (its own arrangement of the members); parent in the same project';


--
-- Name: project_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.project_sections ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.project_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: project_subjects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_subjects (
    project_id bigint NOT NULL,
    res_id bigint NOT NULL,
    res_kind text NOT NULL,
    note text
);


--
-- Name: TABLE project_subjects; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.project_subjects IS 'what a project is about: any res, at the level that fits (a work, a manifestation, a person …)';


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    parent_id bigint,
    note text,
    CONSTRAINT projects_check CHECK ((parent_id <> id)),
    CONSTRAINT projects_code_check CHECK ((code ~ '^[a-z][a-z0-9_]{0,39}$'::text))
);


--
-- Name: TABLE projects; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.projects IS 'research projects; code names the generated LibreOffice view (lo_project_<code>)';


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.projects ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: qa_agents_without_preferred_name; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.qa_agents_without_preferred_name AS
 SELECT id,
    agent_type
   FROM public.agents a
  WHERE ((NOT (EXISTS ( SELECT 1
           FROM public.person_names n
          WHERE ((n.person_id = a.id) AND (n.name_type = 'preferred'::text))))) AND (NOT (EXISTS ( SELECT 1
           FROM public.collective_names n
          WHERE ((n.collective_id = a.id) AND (n.name_type = 'preferred'::text))))));


--
-- Name: qa_headings_off_work; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.qa_headings_off_work AS
 SELECT h.id,
    h.work_id,
    i.res_id AS record_res_id,
    i.res_kind AS record_res_kind
   FROM (public.catalogue_headings h
     JOIN public.identifiers i ON ((i.id = h.record_id)))
  WHERE ((i.res_kind <> 'manifestation'::text) OR (NOT (EXISTS ( SELECT 1
           FROM (public.manifestation_expressions me
             JOIN public.expressions e ON ((e.id = me.expression_id)))
          WHERE ((me.manifestation_id = i.res_id) AND (e.work_id = h.work_id))))));


--
-- Name: qa_identifier_checksums; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.qa_identifier_checksums AS
 SELECT id,
    res_id,
    scheme,
    value,
    status
   FROM public.identifiers i
  WHERE ((status = 'valid'::text) AND (public.identifier_checksum_ok(scheme, normalized) IS FALSE));


--
-- Name: qa_manifestations_without_expression; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.qa_manifestations_without_expression AS
 SELECT id,
    category
   FROM public.manifestations m
  WHERE (NOT (EXISTS ( SELECT 1
           FROM public.manifestation_expressions me
          WHERE (me.manifestation_id = m.id))));


--
-- Name: res; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.res (
    id bigint NOT NULL,
    kind text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: works; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.works (
    id bigint DEFAULT public.new_res('work'::text) NOT NULL,
    kind text DEFAULT 'work'::text NOT NULL,
    category text NOT NULL,
    date_text text,
    date_sort integer,
    date_sort_end integer,
    note text,
    CONSTRAINT works_check CHECK ((date_sort_end >= date_sort)),
    CONSTRAINT works_kind_check CHECK ((kind = 'work'::text))
);


--
-- Name: COLUMN works.date_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.works.date_text IS 'date of the work (of its creation) as to be displayed';


--
-- Name: COLUMN works.date_sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.works.date_sort IS 'first year, for sorting and filtering';


--
-- Name: qa_orphan_res; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.qa_orphan_res AS
 SELECT id,
    kind,
    created_at
   FROM public.res r
  WHERE (((kind = 'work'::text) AND (NOT (EXISTS ( SELECT 1
           FROM public.works x
          WHERE (x.id = r.id))))) OR ((kind = 'expression'::text) AND (NOT (EXISTS ( SELECT 1
           FROM public.expressions x
          WHERE (x.id = r.id))))) OR ((kind = 'manifestation'::text) AND (NOT (EXISTS ( SELECT 1
           FROM public.manifestations x
          WHERE (x.id = r.id))))) OR ((kind = 'item'::text) AND (NOT (EXISTS ( SELECT 1
           FROM public.items x
          WHERE (x.id = r.id))))) OR ((kind = 'agent'::text) AND (NOT (EXISTS ( SELECT 1
           FROM public.persons x
          WHERE (x.id = r.id)))) AND (NOT (EXISTS ( SELECT 1
           FROM public.collectives x
          WHERE (x.id = r.id))))) OR ((kind = 'place'::text) AND (NOT (EXISTS ( SELECT 1
           FROM public.places x
          WHERE (x.id = r.id))))) OR ((kind = 'concept'::text) AND (NOT (EXISTS ( SELECT 1
           FROM public.concepts x
          WHERE (x.id = r.id))))));


--
-- Name: qa_person_names_particle_undecided; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.qa_person_names_particle_undecided AS
 SELECT id,
    person_id,
    family_name,
    particle,
    culture
   FROM public.person_names n
  WHERE ((particle IS NOT NULL) AND (heading_override IS NULL) AND (public.particle_in_entry(n.*) IS NULL));


--
-- Name: qa_unresolved_headings; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.qa_unresolved_headings AS
 SELECT id,
    work_id,
    record_id,
    function,
    vocabulary,
    tag,
    indicators,
    value,
    subfields,
    authority_uri,
    "position",
    rejected,
    note
   FROM public.catalogue_headings h
  WHERE ((function <> 'classification'::text) AND (rejected IS NULL) AND (NOT (EXISTS ( SELECT 1
           FROM public.heading_resolutions r
          WHERE (r.heading_id = h.id)))));


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
-- Name: relations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.relations (
    id bigint NOT NULL,
    type text NOT NULL,
    from_id bigint NOT NULL,
    from_kind text NOT NULL,
    to_id bigint NOT NULL,
    to_kind text NOT NULL,
    locator text,
    "position" integer,
    basis text,
    certainty text DEFAULT 'certain'::text NOT NULL,
    note text,
    CONSTRAINT relations_check CHECK ((from_id <> to_id)),
    CONSTRAINT relations_position_check CHECK (("position" > 0))
);


--
-- Name: relations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.relations ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.relations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: res_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.res ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.res_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
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
-- Name: titles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.titles (
    id bigint NOT NULL,
    res_id bigint NOT NULL,
    res_kind text NOT NULL,
    title_type text NOT NULL,
    source text,
    value text NOT NULL,
    subtitle text,
    lang text,
    script text DEFAULT 'Latn'::text NOT NULL,
    derived_from bigint,
    conversion_scheme text,
    basis text,
    certainty text DEFAULT 'certain'::text NOT NULL,
    "position" integer DEFAULT 1 NOT NULL,
    note text,
    CONSTRAINT titles_check CHECK (((conversion_scheme IS NULL) OR (derived_from IS NOT NULL))),
    CONSTRAINT titles_position_check CHECK (("position" > 0)),
    CONSTRAINT titles_res_kind_check CHECK ((res_kind = ANY (ARRAY['work'::text, 'expression'::text, 'manifestation'::text])))
);


--
-- Name: COLUMN titles.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.titles.source IS 'for manifestations: where the title was transcribed from';


--
-- Name: titles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.titles ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.titles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
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
-- Name: work_genre_forms; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.work_genre_forms AS
 SELECT h.work_id,
    r.res_id,
    r.res_kind,
    array_agg(DISTINCT h.id ORDER BY h.id) AS heading_ids
   FROM (public.catalogue_headings h
     JOIN public.heading_resolutions r ON ((r.heading_id = h.id)))
  WHERE (h.function = 'genre_form'::text)
  GROUP BY h.work_id, r.res_id, r.res_kind;


--
-- Name: work_subjects; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.work_subjects AS
 SELECT h.work_id,
    r.res_id,
    r.res_kind,
    bool_or((r.certainty = 'certain'::text)) AS certain,
    array_agg(DISTINCT h.id ORDER BY h.id) AS heading_ids
   FROM (public.catalogue_headings h
     JOIN public.heading_resolutions r ON ((r.heading_id = h.id)))
  WHERE (h.function = ANY (ARRAY['subject'::text, 'keyword'::text]))
  GROUP BY h.work_id, r.res_id, r.res_kind;


--
-- Name: VIEW work_subjects; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.work_subjects IS 'LRM-R12 work has as subject res, from resolved headings; certain = at least one heading resolves to it with certainty';


--
-- Name: agent_types agent_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_types
    ADD CONSTRAINT agent_types_pkey PRIMARY KEY (code);


--
-- Name: agents agents_id_agent_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_id_agent_type_key UNIQUE (id, agent_type);


--
-- Name: agents agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_pkey PRIMARY KEY (id);


--
-- Name: bases bases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bases
    ADD CONSTRAINT bases_pkey PRIMARY KEY (code);


--
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- Name: catalogue_headings catalogue_headings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogue_headings
    ADD CONSTRAINT catalogue_headings_pkey PRIMARY KEY (id);


--
-- Name: catalogue_headings catalogue_headings_record_id_position_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogue_headings
    ADD CONSTRAINT catalogue_headings_record_id_position_key UNIQUE (record_id, "position");


--
-- Name: certainties certainties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certainties
    ADD CONSTRAINT certainties_pkey PRIMARY KEY (code);


--
-- Name: citations citations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citations
    ADD CONSTRAINT citations_pkey PRIMARY KEY (id);


--
-- Name: collective_categories collective_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_categories
    ADD CONSTRAINT collective_categories_pkey PRIMARY KEY (code);


--
-- Name: collective_name_attestations collective_name_attestations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_name_attestations
    ADD CONSTRAINT collective_name_attestations_pkey PRIMARY KEY (id);


--
-- Name: collective_names collective_names_id_collective_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_names
    ADD CONSTRAINT collective_names_id_collective_id_key UNIQUE (id, collective_id);


--
-- Name: collective_names collective_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_names
    ADD CONSTRAINT collective_names_pkey PRIMARY KEY (id);


--
-- Name: collectives collectives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collectives
    ADD CONSTRAINT collectives_pkey PRIMARY KEY (id);


--
-- Name: concept_categories concept_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_categories
    ADD CONSTRAINT concept_categories_pkey PRIMARY KEY (code);


--
-- Name: concept_names concept_names_concept_id_value_lang_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_names
    ADD CONSTRAINT concept_names_concept_id_value_lang_key UNIQUE (concept_id, value, lang);


--
-- Name: concept_names concept_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_names
    ADD CONSTRAINT concept_names_pkey PRIMARY KEY (id);


--
-- Name: concepts concepts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concepts
    ADD CONSTRAINT concepts_pkey PRIMARY KEY (id);


--
-- Name: contributions contributions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_pkey PRIMARY KEY (id);


--
-- Name: contributions contributions_res_id_agent_id_role_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_res_id_agent_id_role_key UNIQUE (res_id, agent_id, role);


--
-- Name: contributions contributions_res_id_role_position_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_res_id_role_position_key UNIQUE (res_id, role, "position") DEFERRABLE INITIALLY DEFERRED;


--
-- Name: conversion_schemes conversion_schemes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversion_schemes
    ADD CONSTRAINT conversion_schemes_pkey PRIMARY KEY (code);


--
-- Name: document_statuses document_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_statuses
    ADD CONSTRAINT document_statuses_pkey PRIMARY KEY (code);


--
-- Name: documents documents_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_code_key UNIQUE (code);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (work_id);


--
-- Name: expressions expressions_id_work_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expressions
    ADD CONSTRAINT expressions_id_work_id_key UNIQUE (id, work_id);


--
-- Name: expressions expressions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expressions
    ADD CONSTRAINT expressions_pkey PRIMARY KEY (id);


--
-- Name: generational_labels generational_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generational_labels
    ADD CONSTRAINT generational_labels_pkey PRIMARY KEY (code, lang);


--
-- Name: generational_markers generational_markers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generational_markers
    ADD CONSTRAINT generational_markers_pkey PRIMARY KEY (code);


--
-- Name: heading_functions heading_functions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heading_functions
    ADD CONSTRAINT heading_functions_pkey PRIMARY KEY (code);


--
-- Name: heading_resolutions heading_resolutions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heading_resolutions
    ADD CONSTRAINT heading_resolutions_pkey PRIMARY KEY (heading_id, res_id);


--
-- Name: heading_vocabularies heading_vocabularies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heading_vocabularies
    ADD CONSTRAINT heading_vocabularies_pkey PRIMARY KEY (code);


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
-- Name: identifiers identifiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifiers
    ADD CONSTRAINT identifiers_pkey PRIMARY KEY (id);


--
-- Name: identifiers identifiers_res_id_scheme_normalized_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifiers
    ADD CONSTRAINT identifiers_res_id_scheme_normalized_key UNIQUE (res_id, scheme, normalized);


--
-- Name: imprint_agents imprint_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_agents
    ADD CONSTRAINT imprint_agents_pkey PRIMARY KEY (imprint_id, "position");


--
-- Name: imprint_functions imprint_functions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_functions
    ADD CONSTRAINT imprint_functions_pkey PRIMARY KEY (code);


--
-- Name: imprint_places imprint_places_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_places
    ADD CONSTRAINT imprint_places_pkey PRIMARY KEY (imprint_id, "position");


--
-- Name: imprints imprints_id_manifestation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprints
    ADD CONSTRAINT imprints_id_manifestation_id_key UNIQUE (id, manifestation_id);


--
-- Name: imprints imprints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprints
    ADD CONSTRAINT imprints_pkey PRIMARY KEY (id);


--
-- Name: items items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (id);


--
-- Name: languages languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.languages
    ADD CONSTRAINT languages_pkey PRIMARY KEY (code);


--
-- Name: manifestation_categories manifestation_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_categories
    ADD CONSTRAINT manifestation_categories_pkey PRIMARY KEY (code);


--
-- Name: manifestation_expressions manifestation_expressions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_expressions
    ADD CONSTRAINT manifestation_expressions_pkey PRIMARY KEY (manifestation_id, expression_id);


--
-- Name: manifestation_statements manifestation_statements_id_manifestation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_statements
    ADD CONSTRAINT manifestation_statements_id_manifestation_id_key UNIQUE (id, manifestation_id);


--
-- Name: manifestation_statements manifestation_statements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_statements
    ADD CONSTRAINT manifestation_statements_pkey PRIMARY KEY (id);


--
-- Name: manifestations manifestations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestations
    ADD CONSTRAINT manifestations_pkey PRIMARY KEY (id);


--
-- Name: name_cultures name_cultures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.name_cultures
    ADD CONSTRAINT name_cultures_pkey PRIMARY KEY (code);


--
-- Name: name_element_placements name_element_placements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.name_element_placements
    ADD CONSTRAINT name_element_placements_pkey PRIMARY KEY (locale, element);


--
-- Name: name_types name_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.name_types
    ADD CONSTRAINT name_types_pkey PRIMARY KEY (code);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: particle_rules particle_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.particle_rules
    ADD CONSTRAINT particle_rules_pkey PRIMARY KEY (particle, culture);


--
-- Name: person_name_attestations person_name_attestations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_name_attestations
    ADD CONSTRAINT person_name_attestations_pkey PRIMARY KEY (id);


--
-- Name: person_names person_names_id_person_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_id_person_id_key UNIQUE (id, person_id);


--
-- Name: person_names person_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_pkey PRIMARY KEY (id);


--
-- Name: persons persons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_pkey PRIMARY KEY (id);


--
-- Name: place_categories place_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_categories
    ADD CONSTRAINT place_categories_pkey PRIMARY KEY (code);


--
-- Name: place_name_types place_name_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_name_types
    ADD CONSTRAINT place_name_types_pkey PRIMARY KEY (code);


--
-- Name: place_names place_names_id_place_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_names
    ADD CONSTRAINT place_names_id_place_id_key UNIQUE (id, place_id);


--
-- Name: place_names place_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_names
    ADD CONSTRAINT place_names_pkey PRIMARY KEY (id);


--
-- Name: places places_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_pkey PRIMARY KEY (id);


--
-- Name: project_member_sections project_member_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_member_sections
    ADD CONSTRAINT project_member_sections_pkey PRIMARY KEY (section_id, res_id);


--
-- Name: project_members project_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_pkey PRIMARY KEY (project_id, res_id);


--
-- Name: project_sections project_sections_id_project_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_sections
    ADD CONSTRAINT project_sections_id_project_id_key UNIQUE (id, project_id);


--
-- Name: project_sections project_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_sections
    ADD CONSTRAINT project_sections_pkey PRIMARY KEY (id);


--
-- Name: project_subjects project_subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_subjects
    ADD CONSTRAINT project_subjects_pkey PRIMARY KEY (project_id, res_id);


--
-- Name: projects projects_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_code_key UNIQUE (code);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


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
-- Name: relations relations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relations
    ADD CONSTRAINT relations_pkey PRIMARY KEY (id);


--
-- Name: relations relations_type_from_id_to_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relations
    ADD CONSTRAINT relations_type_from_id_to_id_key UNIQUE (type, from_id, to_id);


--
-- Name: res res_id_kind_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.res
    ADD CONSTRAINT res_id_kind_key UNIQUE (id, kind);


--
-- Name: res_kinds res_kinds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.res_kinds
    ADD CONSTRAINT res_kinds_pkey PRIMARY KEY (code);


--
-- Name: res res_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.res
    ADD CONSTRAINT res_pkey PRIMARY KEY (id);


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
-- Name: statement_agents statement_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statement_agents
    ADD CONSTRAINT statement_agents_pkey PRIMARY KEY (statement_id, "position");


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
-- Name: titles titles_id_res_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.titles
    ADD CONSTRAINT titles_id_res_id_key UNIQUE (id, res_id);


--
-- Name: titles titles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.titles
    ADD CONSTRAINT titles_pkey PRIMARY KEY (id);


--
-- Name: work_categories work_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_categories
    ADD CONSTRAINT work_categories_pkey PRIMARY KEY (code);


--
-- Name: works works_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.works
    ADD CONSTRAINT works_pkey PRIMARY KEY (id);


--
-- Name: idx_cards_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cards_project ON public.cards USING btree (project_id);


--
-- Name: idx_cards_res; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cards_res ON public.cards USING btree (res_id);


--
-- Name: idx_catalogue_headings_work; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalogue_headings_work ON public.catalogue_headings USING btree (work_id);


--
-- Name: idx_citations_cited; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_citations_cited ON public.citations USING btree (cited_id);


--
-- Name: idx_citations_citing; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_citations_citing ON public.citations USING btree (citing_expression_id);


--
-- Name: idx_collective_name_attestations_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_collective_name_attestations_name ON public.collective_name_attestations USING btree (name_id);


--
-- Name: idx_collective_name_attestations_res; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_collective_name_attestations_res ON public.collective_name_attestations USING btree (res_id);


--
-- Name: idx_collective_names_collective; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_collective_names_collective ON public.collective_names USING btree (collective_id);


--
-- Name: idx_concept_names_concept; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_concept_names_concept ON public.concept_names USING btree (concept_id);


--
-- Name: idx_contributions_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contributions_agent ON public.contributions USING btree (agent_id);


--
-- Name: idx_expressions_work; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expressions_work ON public.expressions USING btree (work_id);


--
-- Name: idx_heading_resolutions_res; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heading_resolutions_res ON public.heading_resolutions USING btree (res_id);


--
-- Name: idx_identifiers_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_identifiers_lookup ON public.identifiers USING btree (scheme, normalized);


--
-- Name: idx_identifiers_res; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_identifiers_res ON public.identifiers USING btree (res_id);


--
-- Name: idx_imprint_agents_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_imprint_agents_agent ON public.imprint_agents USING btree (agent_id);


--
-- Name: idx_imprint_places_place; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_imprint_places_place ON public.imprint_places USING btree (place_id);


--
-- Name: idx_imprints_manifestation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_imprints_manifestation ON public.imprints USING btree (manifestation_id);


--
-- Name: idx_items_manifestation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_manifestation ON public.items USING btree (manifestation_id);


--
-- Name: idx_manifestation_expressions_expression; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_manifestation_expressions_expression ON public.manifestation_expressions USING btree (expression_id);


--
-- Name: idx_manifestation_statements_manifestation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_manifestation_statements_manifestation ON public.manifestation_statements USING btree (manifestation_id);


--
-- Name: idx_notes_project; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notes_project ON public.notes USING btree (project_id);


--
-- Name: idx_person_name_attestations_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_name_attestations_name ON public.person_name_attestations USING btree (name_id);


--
-- Name: idx_person_name_attestations_res; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_name_attestations_res ON public.person_name_attestations USING btree (res_id);


--
-- Name: idx_person_names_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_person_names_person ON public.person_names USING btree (person_id);


--
-- Name: idx_place_names_place; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_place_names_place ON public.place_names USING btree (place_id);


--
-- Name: idx_project_members_res; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_project_members_res ON public.project_members USING btree (res_id);


--
-- Name: idx_relations_from; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_relations_from ON public.relations USING btree (from_id);


--
-- Name: idx_relations_to; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_relations_to ON public.relations USING btree (to_id);


--
-- Name: idx_statement_agents_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_statement_agents_agent ON public.statement_agents USING btree (agent_id);


--
-- Name: idx_titles_res; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_titles_res ON public.titles USING btree (res_id);


--
-- Name: uq_concept_names_preferred; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_concept_names_preferred ON public.concept_names USING btree (concept_id, lang) WHERE is_preferred;


--
-- Name: uq_person_names_preferred; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_person_names_preferred ON public.person_names USING btree (person_id, script) WHERE ((name_type = 'preferred'::text) AND (derived_from IS NULL));


--
-- Name: uq_place_names_preferred; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_place_names_preferred ON public.place_names USING btree (place_id, lang) WHERE is_preferred;


--
-- Name: agents agents_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER agents_res_delete AFTER DELETE ON public.agents FOR EACH ROW EXECUTE FUNCTION public.res_delete();


--
-- Name: cards cards_touch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER cards_touch BEFORE UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: collectives collectives_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER collectives_res_delete AFTER DELETE ON public.collectives FOR EACH ROW EXECUTE FUNCTION public.res_delete();


--
-- Name: concepts concepts_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER concepts_res_delete AFTER DELETE ON public.concepts FOR EACH ROW EXECUTE FUNCTION public.res_delete();


--
-- Name: documents documents_lo_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER documents_lo_sync AFTER INSERT OR DELETE OR UPDATE OF code ON public.documents FOR EACH STATEMENT EXECUTE FUNCTION public.lo_sync_trigger();


--
-- Name: expressions expressions_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER expressions_res_delete AFTER DELETE ON public.expressions FOR EACH ROW EXECUTE FUNCTION public.res_delete();


--
-- Name: heading_resolutions heading_resolutions_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER heading_resolutions_check BEFORE INSERT OR UPDATE ON public.heading_resolutions FOR EACH ROW EXECUTE FUNCTION public.heading_resolution_check();


--
-- Name: identifiers identifiers_check_kind; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER identifiers_check_kind BEFORE INSERT OR UPDATE OF scheme, res_kind ON public.identifiers FOR EACH ROW EXECUTE FUNCTION public.identifiers_check_kind();


--
-- Name: items items_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER items_res_delete AFTER DELETE ON public.items FOR EACH ROW EXECUTE FUNCTION public.res_delete();


--
-- Name: manifestations manifestations_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER manifestations_res_delete AFTER DELETE ON public.manifestations FOR EACH ROW EXECUTE FUNCTION public.res_delete();


--
-- Name: notes notes_touch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER notes_touch BEFORE UPDATE ON public.notes FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: persons persons_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER persons_res_delete AFTER DELETE ON public.persons FOR EACH ROW EXECUTE FUNCTION public.res_delete();


--
-- Name: places places_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER places_res_delete AFTER DELETE ON public.places FOR EACH ROW EXECUTE FUNCTION public.res_delete();


--
-- Name: projects projects_lo_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER projects_lo_sync AFTER INSERT OR DELETE OR UPDATE OF code ON public.projects FOR EACH STATEMENT EXECUTE FUNCTION public.lo_sync_trigger();


--
-- Name: works works_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER works_res_delete AFTER DELETE ON public.works FOR EACH ROW EXECUTE FUNCTION public.res_delete();


--
-- Name: agents agents_agent_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_agent_type_fkey FOREIGN KEY (agent_type) REFERENCES public.agent_types(code);


--
-- Name: agents agents_id_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_id_kind_fkey FOREIGN KEY (id, kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: cards cards_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: cards cards_res_id_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_res_id_res_kind_fkey FOREIGN KEY (res_id, res_kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: catalogue_headings catalogue_headings_function_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogue_headings
    ADD CONSTRAINT catalogue_headings_function_fkey FOREIGN KEY (function) REFERENCES public.heading_functions(code);


--
-- Name: catalogue_headings catalogue_headings_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogue_headings
    ADD CONSTRAINT catalogue_headings_record_id_fkey FOREIGN KEY (record_id) REFERENCES public.identifiers(id) ON DELETE CASCADE;


--
-- Name: catalogue_headings catalogue_headings_vocabulary_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogue_headings
    ADD CONSTRAINT catalogue_headings_vocabulary_fkey FOREIGN KEY (vocabulary) REFERENCES public.heading_vocabularies(code);


--
-- Name: catalogue_headings catalogue_headings_work_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogue_headings
    ADD CONSTRAINT catalogue_headings_work_id_fkey FOREIGN KEY (work_id) REFERENCES public.works(id) ON DELETE CASCADE;


--
-- Name: citations citations_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citations
    ADD CONSTRAINT citations_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: citations citations_cited_id_cited_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citations
    ADD CONSTRAINT citations_cited_id_cited_kind_fkey FOREIGN KEY (cited_id, cited_kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: citations citations_citing_expression_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citations
    ADD CONSTRAINT citations_citing_expression_id_fkey FOREIGN KEY (citing_expression_id) REFERENCES public.expressions(id) ON DELETE CASCADE;


--
-- Name: citations citations_citing_manifestation_id_citing_expression_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.citations
    ADD CONSTRAINT citations_citing_manifestation_id_citing_expression_id_fkey FOREIGN KEY (citing_manifestation_id, citing_expression_id) REFERENCES public.manifestation_expressions(manifestation_id, expression_id) ON DELETE CASCADE;


--
-- Name: collective_name_attestations collective_name_attestations_name_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_name_attestations
    ADD CONSTRAINT collective_name_attestations_name_id_fkey FOREIGN KEY (name_id) REFERENCES public.collective_names(id) ON DELETE CASCADE;


--
-- Name: collective_name_attestations collective_name_attestations_res_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_name_attestations
    ADD CONSTRAINT collective_name_attestations_res_id_fkey FOREIGN KEY (res_id) REFERENCES public.res(id) ON DELETE CASCADE;


--
-- Name: collective_names collective_names_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_names
    ADD CONSTRAINT collective_names_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: collective_names collective_names_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_names
    ADD CONSTRAINT collective_names_certainty_fkey FOREIGN KEY (certainty) REFERENCES public.certainties(code);


--
-- Name: collective_names collective_names_collective_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_names
    ADD CONSTRAINT collective_names_collective_id_fkey FOREIGN KEY (collective_id) REFERENCES public.collectives(id) ON DELETE CASCADE;


--
-- Name: collective_names collective_names_conversion_scheme_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_names
    ADD CONSTRAINT collective_names_conversion_scheme_fkey FOREIGN KEY (conversion_scheme) REFERENCES public.conversion_schemes(code);


--
-- Name: collective_names collective_names_derived_from_collective_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_names
    ADD CONSTRAINT collective_names_derived_from_collective_id_fkey FOREIGN KEY (derived_from, collective_id) REFERENCES public.collective_names(id, collective_id) ON DELETE CASCADE;


--
-- Name: collective_names collective_names_lang_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_names
    ADD CONSTRAINT collective_names_lang_fkey FOREIGN KEY (lang) REFERENCES public.languages(code);


--
-- Name: collective_names collective_names_name_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_names
    ADD CONSTRAINT collective_names_name_type_fkey FOREIGN KEY (name_type) REFERENCES public.name_types(code);


--
-- Name: collective_names collective_names_script_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collective_names
    ADD CONSTRAINT collective_names_script_fkey FOREIGN KEY (script) REFERENCES public.scripts(code);


--
-- Name: collectives collectives_category_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collectives
    ADD CONSTRAINT collectives_category_fkey FOREIGN KEY (category) REFERENCES public.collective_categories(code);


--
-- Name: collectives collectives_id_agent_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collectives
    ADD CONSTRAINT collectives_id_agent_type_fkey FOREIGN KEY (id, agent_type) REFERENCES public.agents(id, agent_type) ON DELETE CASCADE;


--
-- Name: collectives collectives_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collectives
    ADD CONSTRAINT collectives_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.collectives(id) ON DELETE RESTRICT;


--
-- Name: concept_names concept_names_concept_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_names
    ADD CONSTRAINT concept_names_concept_id_fkey FOREIGN KEY (concept_id) REFERENCES public.concepts(id) ON DELETE CASCADE;


--
-- Name: concept_names concept_names_lang_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concept_names
    ADD CONSTRAINT concept_names_lang_fkey FOREIGN KEY (lang) REFERENCES public.languages(code);


--
-- Name: concepts concepts_category_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concepts
    ADD CONSTRAINT concepts_category_fkey FOREIGN KEY (category) REFERENCES public.concept_categories(code);


--
-- Name: concepts concepts_id_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.concepts
    ADD CONSTRAINT concepts_id_kind_fkey FOREIGN KEY (id, kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: contributions contributions_agent_id_agent_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_agent_id_agent_kind_fkey FOREIGN KEY (agent_id, agent_kind) REFERENCES public.res(id, kind) ON DELETE RESTRICT;


--
-- Name: contributions contributions_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: contributions contributions_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_certainty_fkey FOREIGN KEY (certainty) REFERENCES public.certainties(code);


--
-- Name: contributions contributions_res_id_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_res_id_res_kind_fkey FOREIGN KEY (res_id, res_kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: contributions contributions_role_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_role_res_kind_fkey FOREIGN KEY (role, res_kind) REFERENCES public.roles(code, res_kind);


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
-- Name: documents documents_expression_id_work_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_expression_id_work_id_fkey FOREIGN KEY (expression_id, work_id) REFERENCES public.expressions(id, work_id) ON DELETE RESTRICT;


--
-- Name: documents documents_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE RESTRICT;


--
-- Name: documents documents_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_status_fkey FOREIGN KEY (status) REFERENCES public.document_statuses(code);


--
-- Name: documents documents_work_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_work_id_fkey FOREIGN KEY (work_id) REFERENCES public.works(id) ON DELETE CASCADE;


--
-- Name: expressions expressions_id_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expressions
    ADD CONSTRAINT expressions_id_kind_fkey FOREIGN KEY (id, kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: expressions expressions_lang_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expressions
    ADD CONSTRAINT expressions_lang_fkey FOREIGN KEY (lang) REFERENCES public.languages(code);


--
-- Name: expressions expressions_script_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expressions
    ADD CONSTRAINT expressions_script_fkey FOREIGN KEY (script) REFERENCES public.scripts(code);


--
-- Name: expressions expressions_work_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expressions
    ADD CONSTRAINT expressions_work_id_fkey FOREIGN KEY (work_id) REFERENCES public.works(id) ON DELETE RESTRICT;


--
-- Name: generational_labels generational_labels_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generational_labels
    ADD CONSTRAINT generational_labels_code_fkey FOREIGN KEY (code) REFERENCES public.generational_markers(code);


--
-- Name: generational_labels generational_labels_lang_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generational_labels
    ADD CONSTRAINT generational_labels_lang_fkey FOREIGN KEY (lang) REFERENCES public.languages(code);


--
-- Name: heading_resolutions heading_resolutions_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heading_resolutions
    ADD CONSTRAINT heading_resolutions_certainty_fkey FOREIGN KEY (certainty) REFERENCES public.certainties(code);


--
-- Name: heading_resolutions heading_resolutions_heading_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heading_resolutions
    ADD CONSTRAINT heading_resolutions_heading_id_fkey FOREIGN KEY (heading_id) REFERENCES public.catalogue_headings(id) ON DELETE CASCADE;


--
-- Name: heading_resolutions heading_resolutions_res_id_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heading_resolutions
    ADD CONSTRAINT heading_resolutions_res_id_res_kind_fkey FOREIGN KEY (res_id, res_kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: identifier_schemes identifier_schemes_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifier_schemes
    ADD CONSTRAINT identifier_schemes_res_kind_fkey FOREIGN KEY (res_kind) REFERENCES public.res_kinds(code);


--
-- Name: identifiers identifiers_assigned_by_assigned_by_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifiers
    ADD CONSTRAINT identifiers_assigned_by_assigned_by_kind_fkey FOREIGN KEY (assigned_by, assigned_by_kind) REFERENCES public.res(id, kind) ON DELETE RESTRICT;


--
-- Name: identifiers identifiers_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifiers
    ADD CONSTRAINT identifiers_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: identifiers identifiers_corrects_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifiers
    ADD CONSTRAINT identifiers_corrects_fkey FOREIGN KEY (corrects) REFERENCES public.identifiers(id) ON DELETE SET NULL;


--
-- Name: identifiers identifiers_res_id_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifiers
    ADD CONSTRAINT identifiers_res_id_res_kind_fkey FOREIGN KEY (res_id, res_kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: identifiers identifiers_scheme_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifiers
    ADD CONSTRAINT identifiers_scheme_fkey FOREIGN KEY (scheme) REFERENCES public.identifier_schemes(code);


--
-- Name: identifiers identifiers_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifiers
    ADD CONSTRAINT identifiers_status_fkey FOREIGN KEY (status) REFERENCES public.identifier_statuses(code);


--
-- Name: imprint_agents imprint_agents_agent_id_agent_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_agents
    ADD CONSTRAINT imprint_agents_agent_id_agent_kind_fkey FOREIGN KEY (agent_id, agent_kind) REFERENCES public.res(id, kind) ON DELETE RESTRICT;


--
-- Name: imprint_agents imprint_agents_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_agents
    ADD CONSTRAINT imprint_agents_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: imprint_agents imprint_agents_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_agents
    ADD CONSTRAINT imprint_agents_certainty_fkey FOREIGN KEY (certainty) REFERENCES public.certainties(code);


--
-- Name: imprint_agents imprint_agents_collective_name_id_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_agents
    ADD CONSTRAINT imprint_agents_collective_name_id_agent_id_fkey FOREIGN KEY (collective_name_id, agent_id) REFERENCES public.collective_names(id, collective_id) ON DELETE SET NULL (collective_name_id);


--
-- Name: imprint_agents imprint_agents_imprint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_agents
    ADD CONSTRAINT imprint_agents_imprint_id_fkey FOREIGN KEY (imprint_id) REFERENCES public.imprints(id) ON DELETE CASCADE;


--
-- Name: imprint_agents imprint_agents_person_name_id_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_agents
    ADD CONSTRAINT imprint_agents_person_name_id_agent_id_fkey FOREIGN KEY (person_name_id, agent_id) REFERENCES public.person_names(id, person_id) ON DELETE SET NULL (person_name_id);


--
-- Name: imprint_places imprint_places_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_places
    ADD CONSTRAINT imprint_places_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: imprint_places imprint_places_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_places
    ADD CONSTRAINT imprint_places_certainty_fkey FOREIGN KEY (certainty) REFERENCES public.certainties(code);


--
-- Name: imprint_places imprint_places_imprint_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_places
    ADD CONSTRAINT imprint_places_imprint_id_fkey FOREIGN KEY (imprint_id) REFERENCES public.imprints(id) ON DELETE CASCADE;


--
-- Name: imprint_places imprint_places_place_id_place_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprint_places
    ADD CONSTRAINT imprint_places_place_id_place_kind_fkey FOREIGN KEY (place_id, place_kind) REFERENCES public.res(id, kind) ON DELETE RESTRICT;


--
-- Name: imprints imprints_conversion_scheme_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprints
    ADD CONSTRAINT imprints_conversion_scheme_fkey FOREIGN KEY (conversion_scheme) REFERENCES public.conversion_schemes(code);


--
-- Name: imprints imprints_date_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprints
    ADD CONSTRAINT imprints_date_basis_fkey FOREIGN KEY (date_basis) REFERENCES public.bases(code);


--
-- Name: imprints imprints_date_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprints
    ADD CONSTRAINT imprints_date_certainty_fkey FOREIGN KEY (date_certainty) REFERENCES public.certainties(code);


--
-- Name: imprints imprints_derived_from_manifestation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprints
    ADD CONSTRAINT imprints_derived_from_manifestation_id_fkey FOREIGN KEY (derived_from, manifestation_id) REFERENCES public.imprints(id, manifestation_id) ON DELETE CASCADE;


--
-- Name: imprints imprints_function_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprints
    ADD CONSTRAINT imprints_function_fkey FOREIGN KEY (function) REFERENCES public.imprint_functions(code);


--
-- Name: imprints imprints_lang_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprints
    ADD CONSTRAINT imprints_lang_fkey FOREIGN KEY (lang) REFERENCES public.languages(code);


--
-- Name: imprints imprints_manifestation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprints
    ADD CONSTRAINT imprints_manifestation_id_fkey FOREIGN KEY (manifestation_id) REFERENCES public.manifestations(id) ON DELETE CASCADE;


--
-- Name: imprints imprints_script_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imprints
    ADD CONSTRAINT imprints_script_fkey FOREIGN KEY (script) REFERENCES public.scripts(code);


--
-- Name: items items_holder_id_holder_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_holder_id_holder_kind_fkey FOREIGN KEY (holder_id, holder_kind) REFERENCES public.res(id, kind) ON DELETE RESTRICT;


--
-- Name: items items_id_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_id_kind_fkey FOREIGN KEY (id, kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: items items_manifestation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_manifestation_id_fkey FOREIGN KEY (manifestation_id) REFERENCES public.manifestations(id) ON DELETE RESTRICT;


--
-- Name: manifestation_expressions manifestation_expressions_expression_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_expressions
    ADD CONSTRAINT manifestation_expressions_expression_id_fkey FOREIGN KEY (expression_id) REFERENCES public.expressions(id) ON DELETE RESTRICT;


--
-- Name: manifestation_expressions manifestation_expressions_manifestation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_expressions
    ADD CONSTRAINT manifestation_expressions_manifestation_id_fkey FOREIGN KEY (manifestation_id) REFERENCES public.manifestations(id) ON DELETE CASCADE;


--
-- Name: manifestation_statements manifestation_statements_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_statements
    ADD CONSTRAINT manifestation_statements_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: manifestation_statements manifestation_statements_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_statements
    ADD CONSTRAINT manifestation_statements_certainty_fkey FOREIGN KEY (certainty) REFERENCES public.certainties(code);


--
-- Name: manifestation_statements manifestation_statements_conversion_scheme_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_statements
    ADD CONSTRAINT manifestation_statements_conversion_scheme_fkey FOREIGN KEY (conversion_scheme) REFERENCES public.conversion_schemes(code);


--
-- Name: manifestation_statements manifestation_statements_derived_from_manifestation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_statements
    ADD CONSTRAINT manifestation_statements_derived_from_manifestation_id_fkey FOREIGN KEY (derived_from, manifestation_id) REFERENCES public.manifestation_statements(id, manifestation_id) ON DELETE CASCADE;


--
-- Name: manifestation_statements manifestation_statements_lang_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_statements
    ADD CONSTRAINT manifestation_statements_lang_fkey FOREIGN KEY (lang) REFERENCES public.languages(code);


--
-- Name: manifestation_statements manifestation_statements_manifestation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_statements
    ADD CONSTRAINT manifestation_statements_manifestation_id_fkey FOREIGN KEY (manifestation_id) REFERENCES public.manifestations(id) ON DELETE CASCADE;


--
-- Name: manifestation_statements manifestation_statements_script_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_statements
    ADD CONSTRAINT manifestation_statements_script_fkey FOREIGN KEY (script) REFERENCES public.scripts(code);


--
-- Name: manifestation_statements manifestation_statements_source_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_statements
    ADD CONSTRAINT manifestation_statements_source_fkey FOREIGN KEY (source) REFERENCES public.sources(code);


--
-- Name: manifestation_statements manifestation_statements_statement_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestation_statements
    ADD CONSTRAINT manifestation_statements_statement_type_fkey FOREIGN KEY (statement_type) REFERENCES public.statement_types(code);


--
-- Name: manifestations manifestations_category_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestations
    ADD CONSTRAINT manifestations_category_fkey FOREIGN KEY (category) REFERENCES public.manifestation_categories(code);


--
-- Name: manifestations manifestations_id_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifestations
    ADD CONSTRAINT manifestations_id_kind_fkey FOREIGN KEY (id, kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: name_element_placements name_element_placements_locale_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.name_element_placements
    ADD CONSTRAINT name_element_placements_locale_fkey FOREIGN KEY (locale) REFERENCES public.languages(code);


--
-- Name: notes notes_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: particle_rules particle_rules_culture_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.particle_rules
    ADD CONSTRAINT particle_rules_culture_fkey FOREIGN KEY (culture) REFERENCES public.name_cultures(code);


--
-- Name: person_name_attestations person_name_attestations_name_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_name_attestations
    ADD CONSTRAINT person_name_attestations_name_id_fkey FOREIGN KEY (name_id) REFERENCES public.person_names(id) ON DELETE CASCADE;


--
-- Name: person_name_attestations person_name_attestations_res_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_name_attestations
    ADD CONSTRAINT person_name_attestations_res_id_fkey FOREIGN KEY (res_id) REFERENCES public.res(id) ON DELETE CASCADE;


--
-- Name: person_names person_names_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: person_names person_names_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_certainty_fkey FOREIGN KEY (certainty) REFERENCES public.certainties(code);


--
-- Name: person_names person_names_conversion_scheme_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_conversion_scheme_fkey FOREIGN KEY (conversion_scheme) REFERENCES public.conversion_schemes(code);


--
-- Name: person_names person_names_culture_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_culture_fkey FOREIGN KEY (culture) REFERENCES public.name_cultures(code);


--
-- Name: person_names person_names_derived_from_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_derived_from_person_id_fkey FOREIGN KEY (derived_from, person_id) REFERENCES public.person_names(id, person_id) ON DELETE CASCADE;


--
-- Name: person_names person_names_generational_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_generational_fkey FOREIGN KEY (generational) REFERENCES public.generational_markers(code);


--
-- Name: person_names person_names_lang_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_lang_fkey FOREIGN KEY (lang) REFERENCES public.languages(code);


--
-- Name: person_names person_names_name_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_name_type_fkey FOREIGN KEY (name_type) REFERENCES public.name_types(code);


--
-- Name: person_names person_names_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.persons(id) ON DELETE CASCADE;


--
-- Name: person_names person_names_script_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.person_names
    ADD CONSTRAINT person_names_script_fkey FOREIGN KEY (script) REFERENCES public.scripts(code);


--
-- Name: persons persons_id_agent_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_id_agent_type_fkey FOREIGN KEY (id, agent_type) REFERENCES public.agents(id, agent_type) ON DELETE CASCADE;


--
-- Name: place_names place_names_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_names
    ADD CONSTRAINT place_names_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: place_names place_names_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_names
    ADD CONSTRAINT place_names_certainty_fkey FOREIGN KEY (certainty) REFERENCES public.certainties(code);


--
-- Name: place_names place_names_conversion_scheme_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_names
    ADD CONSTRAINT place_names_conversion_scheme_fkey FOREIGN KEY (conversion_scheme) REFERENCES public.conversion_schemes(code);


--
-- Name: place_names place_names_derived_from_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_names
    ADD CONSTRAINT place_names_derived_from_place_id_fkey FOREIGN KEY (derived_from, place_id) REFERENCES public.place_names(id, place_id) ON DELETE CASCADE;


--
-- Name: place_names place_names_lang_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_names
    ADD CONSTRAINT place_names_lang_fkey FOREIGN KEY (lang) REFERENCES public.languages(code);


--
-- Name: place_names place_names_name_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_names
    ADD CONSTRAINT place_names_name_type_fkey FOREIGN KEY (name_type) REFERENCES public.place_name_types(code);


--
-- Name: place_names place_names_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_names
    ADD CONSTRAINT place_names_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(id) ON DELETE CASCADE;


--
-- Name: place_names place_names_script_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_names
    ADD CONSTRAINT place_names_script_fkey FOREIGN KEY (script) REFERENCES public.scripts(code);


--
-- Name: places places_category_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_category_fkey FOREIGN KEY (category) REFERENCES public.place_categories(code);


--
-- Name: places places_id_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_id_kind_fkey FOREIGN KEY (id, kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: places places_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.places(id) ON DELETE RESTRICT;


--
-- Name: project_member_sections project_member_sections_project_id_res_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_member_sections
    ADD CONSTRAINT project_member_sections_project_id_res_id_fkey FOREIGN KEY (project_id, res_id) REFERENCES public.project_members(project_id, res_id) ON DELETE CASCADE;


--
-- Name: project_member_sections project_member_sections_section_id_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_member_sections
    ADD CONSTRAINT project_member_sections_section_id_project_id_fkey FOREIGN KEY (section_id, project_id) REFERENCES public.project_sections(id, project_id) ON DELETE CASCADE;


--
-- Name: project_members project_members_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_members project_members_res_id_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_res_id_res_kind_fkey FOREIGN KEY (res_id, res_kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: project_sections project_sections_parent_id_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_sections
    ADD CONSTRAINT project_sections_parent_id_project_id_fkey FOREIGN KEY (parent_id, project_id) REFERENCES public.project_sections(id, project_id) ON DELETE CASCADE;


--
-- Name: project_sections project_sections_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_sections
    ADD CONSTRAINT project_sections_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_subjects project_subjects_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_subjects
    ADD CONSTRAINT project_subjects_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: project_subjects project_subjects_res_id_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_subjects
    ADD CONSTRAINT project_subjects_res_id_res_kind_fkey FOREIGN KEY (res_id, res_kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: projects projects_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.projects(id) ON DELETE RESTRICT;


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
-- Name: relations relations_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relations
    ADD CONSTRAINT relations_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: relations relations_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relations
    ADD CONSTRAINT relations_certainty_fkey FOREIGN KEY (certainty) REFERENCES public.certainties(code);


--
-- Name: relations relations_from_id_from_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relations
    ADD CONSTRAINT relations_from_id_from_kind_fkey FOREIGN KEY (from_id, from_kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: relations relations_to_id_to_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relations
    ADD CONSTRAINT relations_to_id_to_kind_fkey FOREIGN KEY (to_id, to_kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: relations relations_type_from_kind_to_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relations
    ADD CONSTRAINT relations_type_from_kind_to_kind_fkey FOREIGN KEY (type, from_kind, to_kind) REFERENCES public.relation_types(code, domain_kind, range_kind);


--
-- Name: res res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.res
    ADD CONSTRAINT res_kind_fkey FOREIGN KEY (kind) REFERENCES public.res_kinds(code);


--
-- Name: roles roles_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_res_kind_fkey FOREIGN KEY (res_kind) REFERENCES public.res_kinds(code);


--
-- Name: statement_agents statement_agents_agent_id_agent_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statement_agents
    ADD CONSTRAINT statement_agents_agent_id_agent_kind_fkey FOREIGN KEY (agent_id, agent_kind) REFERENCES public.res(id, kind) ON DELETE RESTRICT;


--
-- Name: statement_agents statement_agents_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statement_agents
    ADD CONSTRAINT statement_agents_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: statement_agents statement_agents_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statement_agents
    ADD CONSTRAINT statement_agents_certainty_fkey FOREIGN KEY (certainty) REFERENCES public.certainties(code);


--
-- Name: statement_agents statement_agents_collective_name_id_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statement_agents
    ADD CONSTRAINT statement_agents_collective_name_id_agent_id_fkey FOREIGN KEY (collective_name_id, agent_id) REFERENCES public.collective_names(id, collective_id) ON DELETE SET NULL (collective_name_id);


--
-- Name: statement_agents statement_agents_person_name_id_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statement_agents
    ADD CONSTRAINT statement_agents_person_name_id_agent_id_fkey FOREIGN KEY (person_name_id, agent_id) REFERENCES public.person_names(id, person_id) ON DELETE SET NULL (person_name_id);


--
-- Name: statement_agents statement_agents_statement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statement_agents
    ADD CONSTRAINT statement_agents_statement_id_fkey FOREIGN KEY (statement_id) REFERENCES public.manifestation_statements(id) ON DELETE CASCADE;


--
-- Name: titles titles_basis_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.titles
    ADD CONSTRAINT titles_basis_fkey FOREIGN KEY (basis) REFERENCES public.bases(code);


--
-- Name: titles titles_certainty_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.titles
    ADD CONSTRAINT titles_certainty_fkey FOREIGN KEY (certainty) REFERENCES public.certainties(code);


--
-- Name: titles titles_conversion_scheme_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.titles
    ADD CONSTRAINT titles_conversion_scheme_fkey FOREIGN KEY (conversion_scheme) REFERENCES public.conversion_schemes(code);


--
-- Name: titles titles_derived_from_res_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.titles
    ADD CONSTRAINT titles_derived_from_res_id_fkey FOREIGN KEY (derived_from, res_id) REFERENCES public.titles(id, res_id) ON DELETE CASCADE;


--
-- Name: titles titles_lang_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.titles
    ADD CONSTRAINT titles_lang_fkey FOREIGN KEY (lang) REFERENCES public.languages(code);


--
-- Name: titles titles_res_id_res_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.titles
    ADD CONSTRAINT titles_res_id_res_kind_fkey FOREIGN KEY (res_id, res_kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- Name: titles titles_script_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.titles
    ADD CONSTRAINT titles_script_fkey FOREIGN KEY (script) REFERENCES public.scripts(code);


--
-- Name: titles titles_source_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.titles
    ADD CONSTRAINT titles_source_fkey FOREIGN KEY (source) REFERENCES public.sources(code);


--
-- Name: titles titles_title_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.titles
    ADD CONSTRAINT titles_title_type_fkey FOREIGN KEY (title_type) REFERENCES public.title_types(code);


--
-- Name: works works_category_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.works
    ADD CONSTRAINT works_category_fkey FOREIGN KEY (category) REFERENCES public.work_categories(code);


--
-- Name: works works_id_kind_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.works
    ADD CONSTRAINT works_id_kind_fkey FOREIGN KEY (id, kind) REFERENCES public.res(id, kind) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--


