-- Deploy libroyal:name_rendering to pg
-- requires: agents
-- Rendering of personal names from their structured columns:
--   heading   the MOKKA KSZ4 heading: entry element, other name elements,
--             qualifiers ("Gogh, Vincent van", "Babits Mihály",
--             "Kálmán (Magyarország: király), I., Könyves", "Ábrányi Kornél (id.)")
--   display   the natural form in a given output language ("I. János Pál",
--             "ifj. Ábrányi Kornél", "Kornél Ábrányi Jr.", "Vincent van Gogh")
--   sort      entry and other elements as separate columns in Hungarian
--             collation, regnal numeral as an integer (II < IX < X)
-- Where titles, numerals and markers go is not stored with the name: it is
-- decided per output language by name_element_placements.

BEGIN;

-- Position of name elements in the natural (display) form, per output language.
CREATE TABLE public.name_element_placements (
    locale   text NOT NULL REFERENCES public.languages,
    element  text NOT NULL CHECK (element IN ('numeral', 'generational', 'epithet', 'predicate')),
    position text NOT NULL CHECK (position IN ('before', 'after')),
    PRIMARY KEY (locale, element)
);
INSERT INTO public.name_element_placements (locale, element, position) VALUES
    ('hu', 'numeral', 'before'), ('hu', 'generational', 'before'), ('hu', 'epithet', 'before'), ('hu', 'predicate', 'before'),
    ('en', 'numeral', 'after'),  ('en', 'generational', 'after'),  ('en', 'epithet', 'after'),  ('en', 'predicate', 'before'),
    ('de', 'numeral', 'after'),  ('de', 'generational', 'after'),  ('de', 'epithet', 'after'),  ('de', 'predicate', 'before'),
    ('fr', 'numeral', 'after'),  ('fr', 'generational', 'after'),  ('fr', 'epithet', 'after'),  ('fr', 'predicate', 'before');

-- Particle as stored in particle_rules: trimmed, lower case, ’ → '.
CREATE FUNCTION public.normalize_particle(p text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$ SELECT lower(replace(btrim(p), '’', '''')) $$;

-- KSZ4 2.1.2.3: does the particle belong to the entry element for this name
-- culture? Whole particle first, then its first word, then the culture's
-- general rule. NULL: undecided (see qa_person_names_particle_undecided).
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

-- Space between particle and family name: none after an elided particle
-- (d'Artagnan, dell'Acqua, O'Brien), one otherwise (van Gogh, 't Hooft).
CREATE FUNCTION public.particle_joiner(p_particle text, p_joined boolean) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN coalesce(p_joined, public.normalize_particle(p_particle) LIKE '%''') THEN ''
        ELSE ' ' END
$$;

CREATE FUNCTION public.particle_in_entry(n public.person_names) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$ SELECT coalesce(n.particle_in_entry, public.particle_rule(n.particle, n.culture)) $$;

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

-- Entry element (rendszó) and the other name elements that directly follow it.
CREATE FUNCTION public.person_name_entry(n public.person_names) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT CASE
        WHEN n.entry = 'given' THEN n.given_name
        WHEN n.particle IS NOT NULL AND public.particle_in_entry(n) IS TRUE
            THEN n.particle || public.particle_joiner(n.particle, n.particle_joined) || n.family_name
        ELSE n.family_name END
$$;

CREATE FUNCTION public.person_name_rest(n public.person_names) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT nullif(concat_ws(' ',
        CASE WHEN n.entry = 'family' THEN n.given_name END,
        n.patronymic,
        CASE WHEN n.entry = 'family' AND n.particle IS NOT NULL
              AND public.particle_in_entry(n) IS NOT TRUE THEN n.particle END), '')
$$;

-- KSZ4 heading without life dates.
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

-- KSZ4 heading with the person's dates: "Babits Mihály (1883-1941)".
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

-- Natural form for an output language (default placements: English).
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

-- All renderings in one place; sort columns carry the Hungarian collation, so a
-- plain ORDER BY sort_entry, sort_rest, sort_numeral NULLS FIRST sorts correctly.
CREATE VIEW public.person_names_rendered AS
SELECT n.id,
       n.person_id,
       n.name_type,
       n.script,
       public.person_name_heading(n)      AS heading,
       public.person_name_heading_full(n) AS heading_full,
       public.person_name_display(n, 'hu') AS display_hu,
       public.person_name_display(n, 'en') AS display_en,
       (coalesce(n.sort_override, public.person_name_entry(n)) COLLATE "hu-HU-x-icu") AS sort_entry,
       (CASE WHEN n.sort_override IS NULL
             THEN concat_ws(' ', public.person_name_rest(n), n.epithet, n.predicate) END COLLATE "hu-HU-x-icu") AS sort_rest,
       n.numeral AS sort_numeral
  FROM public.person_names n;

CREATE VIEW public.qa_person_names_particle_undecided AS
SELECT n.id, n.person_id, n.family_name, n.particle, n.culture
  FROM public.person_names n
 WHERE n.particle IS NOT NULL
   AND n.heading_override IS NULL
   AND public.particle_in_entry(n) IS NULL;

COMMIT;
