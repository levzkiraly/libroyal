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
-- Name: certainties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.certainties (
    code text NOT NULL,
    label_en text NOT NULL,
    label_hu text,
    isbd_mark text
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
-- Name: legacy_map; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_map (
    legacy_id bigint NOT NULL,
    work_id bigint NOT NULL,
    expression_id bigint NOT NULL,
    manifestation_id bigint NOT NULL
);


--
-- Name: TABLE legacy_map; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.legacy_map IS 'pre-LRM legacy_works row → the work, expression and manifestation it was migrated to';


--
-- Name: legacy_migration_res; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_migration_res (
    res_id bigint NOT NULL
);


--
-- Name: legacy_person_map; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_person_map (
    legacy_id bigint NOT NULL,
    person_id bigint NOT NULL
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
-- Name: lo_bibliography; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.lo_bibliography AS
 WITH RECURSIVE cited AS (
         SELECT lm.legacy_id,
            lm.work_id AS w,
            lm.expression_id AS e,
            lm.manifestation_id AS m
           FROM public.legacy_map lm
        ), up AS (
         SELECT c.legacy_id,
            c.m,
            0 AS depth
           FROM cited c
        UNION ALL
         SELECT up.legacy_id,
            r.from_id,
            (up.depth + 1)
           FROM (up
             JOIN public.relations r ON (((r.to_id = up.m) AND (r.type = 'manifestation_has_part'::text))))
        ), pub AS (
         SELECT DISTINCT ON (up.legacy_id) up.legacy_id,
            i.id AS imprint_id,
            i.date_text,
            i.date_sort
           FROM (up
             JOIN public.imprints i ON (((i.manifestation_id = up.m) AND (i.function = 'publication'::text))))
          ORDER BY up.legacy_id, up.depth, i."position"
        ), host AS (
         SELECT c.legacy_id,
            r.from_id AS m,
            r.locator,
            hm.category
           FROM ((cited c
             JOIN public.relations r ON (((r.to_id = c.m) AND (r.type = 'manifestation_has_part'::text))))
             JOIN public.manifestations hm ON ((hm.id = r.from_id)))
        ), serial AS (
         SELECT DISTINCT ON (up.legacy_id) up.legacy_id,
            up.m
           FROM (up
             JOIN public.manifestations sm ON (((sm.id = up.m) AND (sm.category = 'serial_whole'::text))))
          ORDER BY up.legacy_id, up.depth DESC
        ), mtitle AS (
         SELECT t.res_id,
            t.value,
            t.subtitle
           FROM public.titles t
          WHERE ((t.title_type = 'title_proper'::text) AND (t.derived_from IS NULL) AND (t."position" = 1))
        ), pname AS (
         SELECT DISTINCT ON (n.person_id) n.person_id,
            COALESCE(n.citation_name, public.person_name_entry(n.*)) AS key_name,
                CASE
                    WHEN (n.entry = 'given'::text) THEN public.person_name_display(n.*, 'en'::text)
                    ELSE (public.person_name_entry(n.*) || COALESCE((', '::text || public.person_name_rest(n.*)), ''::text))
                END AS full_name
           FROM public.person_names n
          WHERE ((n.name_type = 'preferred'::text) AND (n.script = 'Latn'::text))
          ORDER BY n.person_id, n.derived_from NULLS FIRST
        ), people AS (
         SELECT c.legacy_id,
            ct.role,
            ct."position",
            p.key_name,
            p.full_name
           FROM ((cited c
             JOIN public.contributions ct ON ((((ct.role = 'author'::text) AND (ct.res_id = c.w)) OR ((ct.role = ANY (ARRAY['editor'::text, 'translator'::text])) AND ((ct.res_id = c.e) OR (ct.res_id IN ( SELECT r.to_id
                   FROM public.relations r
                  WHERE ((r.from_id = c.e) AND (r.type = ANY (ARRAY['aggregated_by'::text, 'edition_of'::text]))))))))))
             JOIN pname p ON ((p.person_id = ct.agent_id)))
        ), names AS (
         SELECT people.legacy_id,
            string_agg(people.full_name, '; '::text ORDER BY people."position") FILTER (WHERE (people.role = 'author'::text)) AS authors,
            string_agg(people.full_name, '; '::text ORDER BY people."position") FILTER (WHERE (people.role = 'editor'::text)) AS editors,
            string_agg(people.full_name, '; '::text ORDER BY people."position") FILTER (WHERE (people.role = 'translator'::text)) AS translators,
            array_agg(people.key_name ORDER BY people."position") FILTER (WHERE (people.role = 'author'::text)) AS author_keys,
            array_agg(people.key_name ORDER BY people."position") FILTER (WHERE (people.role = 'editor'::text)) AS editor_keys
           FROM people
          GROUP BY people.legacy_id
        ), base AS (
         SELECT c.legacy_id,
            c.w,
            c.m,
                CASE
                    WHEN ((m.category = 'component'::text) AND (s.m IS NOT NULL)) THEN 'article'::text
                    WHEN (m.category = 'component'::text) THEN 'incollection'::text
                    WHEN (wk.category = 'online_resource'::text) THEN 'misc'::text
                    ELSE 'book'::text
                END AS type,
            n.authors,
            n.editors,
            n.translators,
            COALESCE(n.author_keys, n.editor_keys) AS keys,
                CASE
                    WHEN (h.category = 'set'::text) THEN ( SELECT x.value
                       FROM mtitle x
                      WHERE (x.res_id = h.m))
                    ELSE t.value
                END AS title_value,
                CASE
                    WHEN (h.category = 'set'::text) THEN ( SELECT x.subtitle
                       FROM mtitle x
                      WHERE (x.res_id = h.m))
                    ELSE t.subtitle
                END AS subtitle,
                CASE
                    WHEN (h.category = 'set'::text) THEN (h.locator || COALESCE(((', '::text || t.value) || COALESCE((': '::text || t.subtitle), ''::text)), ''::text))
                    ELSE NULL::text
                END AS volume_label,
            COALESCE((pub.date_sort)::text, pub.date_text) AS year,
            ( SELECT string_agg(cn.value, ' – '::text ORDER BY ia."position") AS string_agg
                   FROM (public.imprint_agents ia
                     JOIN public.collective_names cn ON (((cn.collective_id = ia.agent_id) AND (cn.name_type = 'preferred'::text))))
                  WHERE (ia.imprint_id = pub.imprint_id)) AS publisher,
            ( SELECT string_agg(pn.value, '–'::text ORDER BY ip."position") AS string_agg
                   FROM (public.imprint_places ip
                     JOIN public.place_names pn ON (((pn.place_id = ip.place_id) AND pn.is_preferred)))
                  WHERE (ip.imprint_id = pub.imprint_id)) AS place,
            st.value AS journal,
                CASE
                    WHEN (h.category = 'issue'::text) THEN ( SELECT r.locator
                       FROM public.relations r
                      WHERE ((r.to_id = h.m) AND (r.type = 'manifestation_has_part'::text))
                     LIMIT 1)
                    ELSE NULL::text
                END AS issue_locator,
                CASE
                    WHEN (m.category = 'component'::text) THEN h.locator
                    ELSE "substring"(m.extent, '^pp\. (.+)$'::text)
                END AS pages,
                CASE
                    WHEN ((m.category = 'component'::text) AND (s.m IS NULL)) THEN ( SELECT (ht.value || COALESCE((': '::text || ht.subtitle), ''::text))
                       FROM mtitle ht
                      WHERE (ht.res_id = h.m))
                    ELSE NULL::text
                END AS booktitle,
            ( SELECT x.value
                   FROM public.identifiers x
                  WHERE ((x.res_id = c.m) AND (x.scheme = 'isbn'::text))
                  ORDER BY x.id
                 LIMIT 1) AS isbn,
            ( SELECT ('doi:'::text || x.value)
                   FROM public.identifiers x
                  WHERE ((x.res_id = ANY (ARRAY[c.e, c.w, c.m])) AND (x.scheme = 'doi'::text))
                  ORDER BY x.id
                 LIMIT 1) AS doi,
            ( SELECT i.url
                   FROM public.items i
                  WHERE ((i.url IS NOT NULL) AND ((i.manifestation_id = c.m) OR (i.manifestation_id IN ( SELECT r.from_id
                           FROM public.relations r
                          WHERE ((r.to_id = c.m) AND (r.type = ANY (ARRAY['reproduction_of'::text, 'alternate_of'::text])))
                        UNION
                         SELECT r.to_id
                           FROM public.relations r
                          WHERE ((r.from_id = c.m) AND (r.type = 'alternate_of'::text))))))
                  ORDER BY i.id
                 LIMIT 1) AS url,
            ( SELECT i.path
                   FROM public.items i
                  WHERE ((i.manifestation_id = c.m) AND (i.path IS NOT NULL))
                  ORDER BY i.id
                 LIMIT 1) AS local_path,
            ( SELECT ms.value
                   FROM public.manifestation_statements ms
                  WHERE ((ms.manifestation_id = c.m) AND (ms.statement_type = 'edition'::text) AND (ms.derived_from IS NULL))
                  ORDER BY ms."position"
                 LIMIT 1) AS edition,
            ( SELECT wt.value
                   FROM (public.relations r
                     JOIN public.titles wt ON (((wt.res_id = r.to_id) AND (wt.title_type = 'preferred'::text))))
                  WHERE ((r.from_id = c.m) AND (r.type = 'in_series'::text))
                  ORDER BY r.id
                 LIMIT 1) AS series_name,
            ( SELECT r.locator
                   FROM public.relations r
                  WHERE ((r.from_id = c.m) AND (r.type = 'in_series'::text))
                  ORDER BY r.id
                 LIMIT 1) AS series_number,
            m.note,
            ( SELECT string_agg(tg.name, '; '::text ORDER BY tg.name) AS string_agg
                   FROM (public.legacy_work_tags lt
                     JOIN public.legacy_tags tg ON ((tg.id = lt.tag_id)))
                  WHERE (lt.work_id = c.legacy_id)) AS tags,
            COALESCE(( SELECT pt.value
                   FROM ((public.relations r
                     JOIN public.works pw ON (((pw.id = r.from_id) AND (pw.category = 'multipart'::text))))
                     JOIN public.titles pt ON (((pt.res_id = pw.id) AND (pt.title_type = 'preferred'::text))))
                  WHERE ((r.to_id = c.w) AND (r.type = 'work_has_part'::text))
                 LIMIT 1), t.value) AS block_title,
            ( SELECT r.locator
                   FROM public.relations r
                  WHERE ((r.to_id = c.w) AND (r.type = 'work_has_part'::text))
                 LIMIT 1) AS part_locator,
            pub.date_text AS date_full
           FROM ((((((((cited c
             JOIN public.manifestations m ON ((m.id = c.m)))
             JOIN public.works wk ON ((wk.id = c.w)))
             LEFT JOIN names n ON ((n.legacy_id = c.legacy_id)))
             LEFT JOIN mtitle t ON ((t.res_id = c.m)))
             LEFT JOIN pub ON ((pub.legacy_id = c.legacy_id)))
             LEFT JOIN host h ON ((h.legacy_id = c.legacy_id)))
             LEFT JOIN serial s ON ((s.legacy_id = c.legacy_id)))
             LEFT JOIN mtitle st ON ((st.res_id = s.m)))
        ), labelled AS (
         SELECT b.legacy_id,
            b.w,
            b.m,
            b.type,
            b.authors,
            b.editors,
            b.translators,
            b.keys,
            b.title_value,
            b.subtitle,
            b.volume_label,
            b.year,
            b.publisher,
            b.place,
            b.journal,
            b.issue_locator,
            b.pages,
            b.booktitle,
            b.isbn,
            b.doi,
            b.url,
            b.local_path,
            b.edition,
            b.series_name,
            b.series_number,
            b.note,
            b.tags,
            b.block_title,
            b.part_locator,
            b.date_full,
            ((COALESCE(
                CASE
                    WHEN (cardinality(b.keys) >= 5) THEN (b.keys[1] || ' et al.'::text)
                    ELSE array_to_string(b.keys, '–'::text)
                END, '[no-author]'::text) || ' '::text) || COALESCE(b.year, '[no-year]'::text)) AS label0
           FROM base b
        ), keyed AS (
         SELECT l.legacy_id,
            l.w,
            l.m,
            l.type,
            l.authors,
            l.editors,
            l.translators,
            l.keys,
            l.title_value,
            l.subtitle,
            l.volume_label,
            l.year,
            l.publisher,
            l.place,
            l.journal,
            l.issue_locator,
            l.pages,
            l.booktitle,
            l.isbn,
            l.doi,
            l.url,
            l.local_path,
            l.edition,
            l.series_name,
            l.series_number,
            l.note,
            l.tags,
            l.block_title,
            l.part_locator,
            l.date_full,
            l.label0,
            (l.label0 ||
                CASE
                    WHEN (count(*) OVER (PARTITION BY l.label0) > 1) THEN chr((96 + (row_number() OVER (PARTITION BY l.label0 ORDER BY (regexp_replace(l.block_title, '^(a|az|the|an?|der|die|das|le|la|les|l''|il|lo|el)\s+'::text, ''::text, 'i'::text) COLLATE "hu-HU-x-icu"), l.date_full, l.part_locator, (regexp_replace(l.title_value, '^(a|az|the|an?|der|die|das|le|la|les|l''|il|lo|el)\s+'::text, ''::text, 'i'::text) COLLATE "hu-HU-x-icu"), l.legacy_id))::integer))
                    ELSE ''::text
                END) AS label
           FROM labelled l
        )
 SELECT label AS "Identifier",
        CASE type
            WHEN 'article'::text THEN 0
            WHEN 'book'::text THEN 1
            WHEN 'incollection'::text THEN 5
            WHEN 'misc'::text THEN 10
            ELSE NULL::integer
        END AS "BibliographyType",
    authors AS "Author",
    editors AS "Editor",
    (title_value || COALESCE((': '::text || subtitle), ''::text)) AS "Title",
    subtitle AS "Subtitle",
    year AS "Year",
    publisher AS "Publisher",
    place AS "Address",
    journal AS "Journal",
    COALESCE(volume_label,
        CASE
            WHEN (issue_locator ~ ', '::text) THEN split_part(issue_locator, ', '::text, 1)
            WHEN (issue_locator ~ '/'::text) THEN split_part(issue_locator, '/'::text, 1)
            ELSE NULL::text
        END) AS "Volume",
    COALESCE(
        CASE
            WHEN (issue_locator ~ ', '::text) THEN "substring"(issue_locator, ', (.*)$'::text)
            WHEN (issue_locator ~ '/'::text) THEN "substring"(issue_locator, '/(.*)$'::text)
            ELSE issue_locator
        END, series_number) AS "Number",
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
-- Name: certainties certainties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certainties
    ADD CONSTRAINT certainties_pkey PRIMARY KEY (code);


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
-- Name: legacy_map legacy_map_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_map
    ADD CONSTRAINT legacy_map_pkey PRIMARY KEY (legacy_id);


--
-- Name: legacy_migration_res legacy_migration_res_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_migration_res
    ADD CONSTRAINT legacy_migration_res_pkey PRIMARY KEY (res_id);


--
-- Name: legacy_person_map legacy_person_map_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_person_map
    ADD CONSTRAINT legacy_person_map_pkey PRIMARY KEY (legacy_id);


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
-- Name: idx_contributions_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contributions_agent ON public.contributions USING btree (agent_id);


--
-- Name: idx_expressions_work; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expressions_work ON public.expressions USING btree (work_id);


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
-- Name: collectives collectives_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER collectives_res_delete AFTER DELETE ON public.collectives FOR EACH ROW EXECUTE FUNCTION public.res_delete();


--
-- Name: expressions expressions_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER expressions_res_delete AFTER DELETE ON public.expressions FOR EACH ROW EXECUTE FUNCTION public.res_delete();


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
-- Name: persons persons_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER persons_res_delete AFTER DELETE ON public.persons FOR EACH ROW EXECUTE FUNCTION public.res_delete();


--
-- Name: places places_res_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER places_res_delete AFTER DELETE ON public.places FOR EACH ROW EXECUTE FUNCTION public.res_delete();


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
-- Name: legacy_map legacy_map_expression_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_map
    ADD CONSTRAINT legacy_map_expression_id_fkey FOREIGN KEY (expression_id) REFERENCES public.expressions(id);


--
-- Name: legacy_map legacy_map_legacy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_map
    ADD CONSTRAINT legacy_map_legacy_id_fkey FOREIGN KEY (legacy_id) REFERENCES public.legacy_works(id);


--
-- Name: legacy_map legacy_map_manifestation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_map
    ADD CONSTRAINT legacy_map_manifestation_id_fkey FOREIGN KEY (manifestation_id) REFERENCES public.manifestations(id);


--
-- Name: legacy_map legacy_map_work_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_map
    ADD CONSTRAINT legacy_map_work_id_fkey FOREIGN KEY (work_id) REFERENCES public.works(id);


--
-- Name: legacy_person_map legacy_person_map_legacy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_person_map
    ADD CONSTRAINT legacy_person_map_legacy_id_fkey FOREIGN KEY (legacy_id) REFERENCES public.legacy_persons(id);


--
-- Name: legacy_person_map legacy_person_map_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_person_map
    ADD CONSTRAINT legacy_person_map_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.persons(id);


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


