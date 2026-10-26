-- Deploy libroyal:agents to pg
-- requires: wemi_core
-- Agents (LRM-E6: ágens) with the subclasses person (LRM-E7: személy) and
-- collective agent (LRM-E8: kollektív ágens), and their names (LRM Nomen, R13).
-- Personal names follow the 2013 catalogue model, restructured after MOKKA KSZ4
-- (regulations/MOKKA/KSZ4.pdf): entry element (rendszó), other name elements
-- (egyéb névelem), qualifiers (kiegészítő adat). Rendering is in name_rendering.

BEGIN;

-- ---------------------------------------------------------------------------
-- Vocabularies

CREATE TABLE public.agent_types (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text,
    lrm_id   text
);
INSERT INTO public.agent_types (code, label_en, label_hu, lrm_id) VALUES
    ('person',     'person',           'személy',         'LRM-E7'),
    ('collective', 'collective agent', 'kollektív ágens', 'LRM-E8');

CREATE TABLE public.collective_categories (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text
);
INSERT INTO public.collective_categories (code, label_en, label_hu) VALUES
    ('publisher',  'publisher',               'kiadó'),
    ('printer',    'printer',                 'nyomda'),
    ('bookseller', 'bookseller, distributor', 'könyvkereskedő, terjesztő'),
    ('library',    'library',                 'könyvtár'),
    ('archive',    'archive',                 'levéltár'),
    ('museum',     'museum',                  'múzeum'),
    ('society',    'society, academy',        'tudományos testület, egyesület'),
    ('university', 'university, school',      'egyetem, iskola'),
    ('church',     'church body',             'egyházi testület'),
    ('government', 'government body',         'állami szerv'),
    ('event',      'event, conference',       'rendezvény, konferencia'),
    ('company',    'company',                 'cég'),
    ('family',     'family',                  'család'),
    ('other',      'other',                   'egyéb');

-- Types of names (nomens) of agents.
CREATE TABLE public.name_types (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text,
    note     text
);
INSERT INTO public.name_types (code, label_en, label_hu, note) VALUES
    ('preferred', 'preferred name',   'egységesített név', 'the authorized form (KSZ4 1.2)'),
    ('variant',   'variant name',     'névváltozat',       'see-reference form (KSZ4 1.3)'),
    ('pseudonym', 'pseudonym',        'álnév',             'KSZ4 2.5'),
    ('birth',     'birth name',       'születési név',     NULL),
    ('married',   'married name',     'asszonynév',        'KSZ4 2.1.4'),
    ('former',    'former name',      'korábbi név',       'name change: see-also reference (KSZ4 1.4)'),
    ('religious', 'religious name',   'vallási név',       'KSZ4 2.4'),
    ('short',     'short form',       'rövid alak',        'abbreviation, acronym'),
    ('erroneous', 'erroneous form',   'hibás névalak',     'a wrong form found in a source; where it appears: attestations, contributions, imprint_agents');

-- Nationality or language area of a name, deciding the treatment of particles
-- (KSZ4 2.1.2.3: kind 'language_area' are the starred entries of the table).
-- particles_in_entry: the general rule of the notes to that table — TRUE: every
-- particle belongs to the entry element (note a), FALSE: none does (note b),
-- NULL: decided per particle by particle_rules, or by the linguistic origin of
-- the name (notes c, d), in which case the name needs an explicit decision.
CREATE TABLE public.name_cultures (
    code               text PRIMARY KEY,
    label_en           text NOT NULL,
    label_hu           text,
    kind               text NOT NULL CHECK (kind IN ('nation', 'language_area')),
    particles_in_entry boolean,
    note               text
);
INSERT INTO public.name_cultures (code, label_en, label_hu, kind, particles_in_entry, note) VALUES
    ('hungarian',  'Hungarian',  'magyar',     'nation',        TRUE,  'KSZ4 2.1.2.3 note a'),
    ('english',    'English language area', 'angol nyelvterület', 'language_area', TRUE, 'KSZ4 2.1.2.3 note a'),
    ('afrikaans',  'Afrikaans',  'afrikansz',  'nation',        TRUE,  'KSZ4 2.1.2.3 note a'),
    ('belarusian', 'Belarusian', 'belorusz',   'nation',        TRUE,  'KSZ4 2.1.2.3 note a'),
    ('brazilian',  'Brazilian',  'brazil',     'nation',        TRUE,  'KSZ4 2.1.2.3 note a'),
    ('irish',      'Irish',      'ír',         'nation',        TRUE,  'KSZ4 2.1.2.3 note a'),
    ('italian',    'Italian',    'olasz',      'nation',        TRUE, 'KSZ4 2.1.2.3 note a; also the table'),
    ('russian',    'Russian',    'orosz',      'nation',        TRUE, 'KSZ4 2.1.2.3 note a'),
    ('ukrainian',  'Ukrainian',  'ukrán',      'nation',        TRUE, 'KSZ4 2.1.2.3 note a'),
    ('czech',      'Czech',      'cseh',       'nation',        FALSE, 'KSZ4 2.1.2.3 note b'),
    ('slovak',     'Slovak',     'szlovák',    'nation',        FALSE, 'KSZ4 2.1.2.3 note b'),
    ('danish',     'Danish',     'dán',        'nation',        NULL, 'KSZ4 2.1.2.3 note c: by the linguistic origin of the name'),
    ('finnish',    'Finnish',    'finn',       'nation',        NULL, 'KSZ4 2.1.2.3 note c'),
    ('swedish',    'Swedish',    'svéd',       'nation',        NULL, 'KSZ4 2.1.2.3 note c; table: af'),
    ('maltese',    'Maltese',    'máltai',     'nation',        NULL, 'KSZ4 2.1.2.3 note d: Romance particles entry, Germanic ones other element'),
    ('norwegian',  'Norwegian',  'norvég',     'nation',        NULL, 'KSZ4 2.1.2.3 note d'),
    ('german',     'German language area', 'német nyelvterület', 'language_area', NULL, 'KSZ4 2.1.2.3 table; note d for Romance particles'),
    ('belgian',    'Belgian',    'belga',      'nation',        NULL, 'KSZ4 2.1.2.3 table'),
    ('dutch',      'Dutch',      'holland',    'nation',        NULL, 'KSZ4 2.1.2.3 table'),
    ('french',     'French language area', 'francia nyelvterület', 'language_area', NULL, 'KSZ4 2.1.2.3 table'),
    ('portuguese', 'Portuguese language area', 'portugál nyelvterület', 'language_area', NULL, 'KSZ4 2.1.2.3 table'),
    ('spanish',    'Spanish language area', 'spanyol nyelvterület', 'language_area', NULL, 'KSZ4 2.1.2.3 table; article particles only'),
    ('romanian',   'Romanian',   'román',      'nation',        NULL, 'KSZ4 2.1.2.3 table'),
    ('romansh',    'Romansh',    'rétoromán',  'nation',        NULL, 'KSZ4 2.1.2.3 table'),
    ('welsh',      'Welsh',      'walesi',     'nation',        NULL, 'KSZ4 2.1.2.3 table'),
    ('other',      'other',      'egyéb',      'nation',        NULL, 'KSZ4 2.1.2.3 unknown nationality: decide by the linguistic origin of the name');

-- KSZ4 2.1.2.3 table: is a separately written particle part of the entry element
-- (rendszó) or written after the given name (egyéb névelem)? particle is stored
-- normalized: lower case, apostrophe as U+0027. Lookup tries the whole particle,
-- then its first word (the table lists e.g. "de (de la, de los)" under "de").
-- Apostrophes lost in the PDF text were restored from the printed table.
CREATE TABLE public.particle_rules (
    particle text NOT NULL CHECK (particle = lower(particle) AND particle !~ '’'),
    culture  text NOT NULL REFERENCES public.name_cultures,
    in_entry boolean NOT NULL,
    PRIMARY KEY (particle, culture)
);
INSERT INTO public.particle_rules (particle, culture, in_entry)
SELECT p, c, e FROM (VALUES
    ('a', 'romanian', TRUE), ('a', 'romansh', TRUE),
    ('ab', 'welsh', TRUE),
    ('af', 'swedish', FALSE),
    ('al', 'romanian', TRUE),
    ('am', 'german', TRUE),
    ('an', 'german', FALSE),
    ('ap', 'welsh', TRUE),
    ('auf', 'german', FALSE),
    ('auf ''m', 'german', TRUE),
    ('aus', 'german', FALSE),
    ('aus ''m', 'german', TRUE),
    ('bei', 'german', FALSE),
    ('beim', 'german', TRUE),
    ('d''', 'italian', TRUE), ('d''', 'belgian', TRUE),
    ('d''', 'french', FALSE), ('d''', 'dutch', FALSE), ('d''', 'portuguese', FALSE),
    ('da', 'italian', TRUE), ('da', 'portuguese', FALSE),
    ('dagli', 'italian', TRUE), ('dagl''', 'italian', TRUE),
    ('dalla', 'italian', TRUE), ('dalle', 'italian', TRUE),
    ('das', 'german', FALSE),
    ('de', 'belgian', TRUE), ('de', 'italian', TRUE),
    ('de', 'french', FALSE), ('de', 'dutch', FALSE), ('de', 'portuguese', FALSE),
    ('de', 'romanian', FALSE), ('de', 'spanish', FALSE),
    ('degli', 'italian', TRUE), ('degl''', 'italian', TRUE),
    ('del', 'italian', TRUE), ('del', 'spanish', FALSE),
    ('della', 'italian', TRUE), ('delle', 'italian', TRUE),
    ('den', 'belgian', TRUE), ('den', 'dutch', FALSE),
    ('der', 'belgian', TRUE), ('der', 'dutch', FALSE), ('der', 'german', FALSE),
    ('des', 'belgian', TRUE), ('des', 'french', TRUE),
    ('di', 'italian', TRUE),
    ('die', 'german', FALSE),
    ('do', 'portuguese', FALSE),
    ('dos', 'portuguese', FALSE),
    ('du', 'belgian', TRUE), ('du', 'french', TRUE),
    ('gli', 'italian', TRUE), ('gl''', 'italian', TRUE),
    ('i', 'italian', TRUE),
    ('il', 'italian', TRUE),
    ('im', 'german', TRUE),
    ('in', 'german', FALSE),
    ('in ''t', 'belgian', TRUE), ('in ''t', 'dutch', FALSE),
    ('l''', 'belgian', TRUE), ('l''', 'french', TRUE), ('l''', 'italian', TRUE),
    ('la', 'belgian', TRUE), ('la', 'french', TRUE), ('la', 'italian', TRUE), ('la', 'spanish', TRUE),
    ('las', 'spanish', TRUE),
    ('le', 'belgian', TRUE), ('le', 'french', TRUE), ('le', 'italian', TRUE),
    ('les', 'belgian', TRUE), ('les', 'french', TRUE),
    ('lo', 'italian', TRUE), ('lo', 'spanish', TRUE),
    ('los', 'spanish', TRUE),
    ('met', 'belgian', TRUE), ('met', 'dutch', FALSE),
    ('op', 'belgian', TRUE), ('op', 'dutch', FALSE),
    ('''s', 'belgian', TRUE), ('''s', 'dutch', FALSE),
    ('''t', 'belgian', TRUE), ('''t', 'dutch', FALSE),
    ('te', 'belgian', TRUE), ('te', 'dutch', FALSE),
    ('ter', 'belgian', TRUE), ('ter', 'dutch', FALSE),
    ('thoe', 'belgian', TRUE), ('thoe', 'dutch', FALSE),
    ('toe', 'belgian', TRUE), ('toe', 'dutch', FALSE),
    ('uit den', 'belgian', TRUE), ('uit den', 'dutch', FALSE),
    ('uyt den', 'belgian', TRUE), ('uyt den', 'dutch', FALSE),
    ('uut den', 'belgian', TRUE), ('uut den', 'dutch', FALSE),
    ('uut ''t', 'belgian', TRUE), ('uut ''t', 'dutch', FALSE),
    ('uyter', 'belgian', TRUE), ('uyter', 'dutch', FALSE),
    ('van', 'belgian', TRUE), ('van', 'dutch', FALSE), ('van', 'german', FALSE),
    ('van ''s', 'belgian', TRUE), ('van ''s', 'dutch', FALSE),
    ('van ''t', 'belgian', TRUE), ('van ''t', 'dutch', FALSE),
    ('vande', 'belgian', TRUE), ('vande', 'dutch', FALSE),
    ('vanden', 'belgian', TRUE), ('vanden', 'dutch', FALSE),
    ('vander', 'belgian', TRUE), ('vander', 'dutch', FALSE),
    ('ver', 'belgian', TRUE), ('ver', 'dutch', TRUE),
    ('vom', 'german', TRUE),
    ('von', 'german', FALSE),
    ('voor', 'belgian', TRUE), ('voor', 'dutch', FALSE),
    ('z', 'czech', FALSE),
    ('zu', 'german', FALSE),
    ('zum', 'german', TRUE),
    ('zur', 'german', TRUE)
) AS v (p, c, e);

-- Generational markers (KSZ4 4.3 rokonsági kiegészítő adat) are stored as codes;
-- their label depends on the language (Dumas père / id. Dumas / Dumas Sr.).
CREATE TABLE public.generational_markers (
    code     text PRIMARY KEY,
    label_en text NOT NULL
);
INSERT INTO public.generational_markers (code, label_en) VALUES
    ('senior',  'senior'),
    ('junior',  'junior'),
    ('ordinal', 'ordinal (II, III …), with person_names.generational_ordinal');

CREATE TABLE public.generational_labels (
    code  text NOT NULL REFERENCES public.generational_markers,
    lang  text NOT NULL REFERENCES public.languages,
    label text NOT NULL,
    PRIMARY KEY (code, lang)
);
INSERT INTO public.generational_labels (code, lang, label) VALUES
    ('senior', 'hu', 'id.'),   ('junior', 'hu', 'ifj.'),
    ('senior', 'en', 'Sr.'),   ('junior', 'en', 'Jr.'),
    ('senior', 'fr', 'père'),  ('junior', 'fr', 'fils'),
    ('senior', 'de', 'd. Ä.'), ('junior', 'de', 'd. J.');

-- ---------------------------------------------------------------------------
-- Agents

-- Used as the id default of persons and collectives: creates the res row and
-- the agents row, so that a single INSERT into persons is enough.
CREATE FUNCTION public.new_agent(p_type text) RETURNS bigint
    LANGUAGE plpgsql VOLATILE
    AS $$
DECLARE v_id bigint;
BEGIN
    INSERT INTO public.res (kind) VALUES ('agent') RETURNING id INTO v_id;
    INSERT INTO public.agents (id, agent_type) VALUES (v_id, p_type);
    RETURN v_id;
END $$;

CREATE TABLE public.agents (
    id         bigint PRIMARY KEY,
    kind       text NOT NULL DEFAULT 'agent' CHECK (kind = 'agent'),
    agent_type text NOT NULL REFERENCES public.agent_types,
    note       text,
    FOREIGN KEY (id, kind) REFERENCES public.res (id, kind) ON DELETE CASCADE,
    UNIQUE (id, agent_type)
);

CREATE TABLE public.persons (
    id           bigint PRIMARY KEY DEFAULT public.new_agent('person'),
    agent_type   text NOT NULL DEFAULT 'person' CHECK (agent_type = 'person'),
    birth_text   text,
    birth_year   integer,
    death_text   text,
    death_year   integer,
    floruit_text text,
    note         text,
    FOREIGN KEY (id, agent_type) REFERENCES public.agents (id, agent_type) ON DELETE CASCADE
);
COMMENT ON COLUMN public.persons.birth_text IS 'as to be displayed, e.g. 1824, 1824?, ca. 1500';
COMMENT ON COLUMN public.persons.floruit_text IS 'period of activity when life dates are unknown, e.g. 15. sz. (KSZ4 4.2)';

CREATE TABLE public.collectives (
    id             bigint PRIMARY KEY DEFAULT public.new_agent('collective'),
    agent_type     text NOT NULL DEFAULT 'collective' CHECK (agent_type = 'collective'),
    category       text NOT NULL REFERENCES public.collective_categories,
    parent_id      bigint REFERENCES public.collectives ON DELETE RESTRICT,
    start_text     text,
    start_year     integer,
    end_text       text,
    end_year       integer,
    note           text,
    FOREIGN KEY (id, agent_type) REFERENCES public.agents (id, agent_type) ON DELETE CASCADE
);
COMMENT ON COLUMN public.collectives.parent_id IS 'LRM-R31: the larger collective this one is part of';

CREATE TRIGGER agents_res_delete      AFTER DELETE ON public.agents      FOR EACH ROW EXECUTE FUNCTION public.res_delete();
CREATE TRIGGER persons_res_delete     AFTER DELETE ON public.persons     FOR EACH ROW EXECUTE FUNCTION public.res_delete();
CREATE TRIGGER collectives_res_delete AFTER DELETE ON public.collectives FOR EACH ROW EXECUTE FUNCTION public.res_delete();

-- ---------------------------------------------------------------------------
-- Personal names. One row per name form (preferred, variants, pseudonyms,
-- erroneous forms, transliterations). Columns follow KSZ4 1.8 / 3.1–3.3 / 4.3:
--   entry          which element is the entry element: the family name (modern
--                  names) or the given name (rulers, popes, saints, medieval names
--                  and names without family name: KSZ4 2.2.3, 2.3, 2.4)
--   particle       névelőzék as written (d', van der, de la); whether it joins the
--                  entry element follows particle_rules unless particle_in_entry
--                  overrides; whether it is written without space follows its
--                  final apostrophe unless particle_joined overrides
--   predicate      előnév as written (somlyói); epithet: állandósult melléknév
--                  (Könyves, Szent, Alexandriai); noble_title: inherited title as
--                  written (conte di, baron de la Brède et de)
--   numeral        regnal or religious ordinal (KSZ4 3.1), an integer
--   generational   senior/junior/ordinal code (KSZ4 4.3), labelled per language
--   qualifier      other qualifier in parentheses (Magyarország: király; pápa;
--                  festő; álnév) — the life dates come from persons
--   heading_override / display_override / sort_override for names the columns
--                  cannot express, typically noble names as entry element
--                  (Cavour, Montesquieu: KSZ4 2.1.6, 3.2)
-- Titles of address and academic titles are not part of a name (KSZ4 1.8.2);
-- they belong to transcribed statements only.
CREATE TABLE public.person_names (
    id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    person_id            bigint NOT NULL REFERENCES public.persons ON DELETE CASCADE,
    name_type            text NOT NULL DEFAULT 'preferred' REFERENCES public.name_types,
    entry                text NOT NULL DEFAULT 'family' CHECK (entry IN ('family', 'given')),
    name_order           text NOT NULL DEFAULT 'given_first' CHECK (name_order IN ('family_first', 'given_first')),
    culture              text REFERENCES public.name_cultures,
    family_name          text,
    given_name           text,
    patronymic           text,
    particle             text,
    particle_in_entry    boolean,
    particle_joined      boolean,
    predicate            text,
    epithet              text,
    noble_title          text,
    numeral              integer CHECK (numeral > 0),
    generational         text REFERENCES public.generational_markers,
    generational_ordinal integer CHECK (generational_ordinal > 1),
    qualifier            text,
    heading_override     text,
    display_override     text,
    sort_override        text,
    lang                 text REFERENCES public.languages,
    script               text NOT NULL DEFAULT 'Latn' REFERENCES public.scripts,
    derived_from         bigint,
    conversion_scheme    text REFERENCES public.conversion_schemes,
    basis                text REFERENCES public.bases,
    certainty            text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    note                 text,
    UNIQUE (id, person_id),
    FOREIGN KEY (derived_from, person_id) REFERENCES public.person_names (id, person_id) ON DELETE CASCADE,
    CHECK (conversion_scheme IS NULL OR derived_from IS NOT NULL),
    CHECK (family_name IS NOT NULL OR given_name IS NOT NULL OR heading_override IS NOT NULL),
    CHECK (entry = 'given' OR family_name IS NOT NULL OR heading_override IS NOT NULL),
    CHECK ((generational = 'ordinal') = (generational_ordinal IS NOT NULL))
);
CREATE INDEX idx_person_names_person ON public.person_names (person_id);
CREATE UNIQUE INDEX uq_person_names_preferred ON public.person_names (person_id, script)
    WHERE name_type = 'preferred' AND derived_from IS NULL;

-- Names of collective agents: a single string per form, valid for a period
-- (name changes), with the shared nomen columns.
CREATE TABLE public.collective_names (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    collective_id     bigint NOT NULL REFERENCES public.collectives ON DELETE CASCADE,
    name_type         text NOT NULL DEFAULT 'preferred' REFERENCES public.name_types,
    value             text NOT NULL,
    valid_from_year   integer,
    valid_to_year     integer,
    lang              text REFERENCES public.languages,
    script            text NOT NULL DEFAULT 'Latn' REFERENCES public.scripts,
    derived_from      bigint,
    conversion_scheme text REFERENCES public.conversion_schemes,
    basis             text REFERENCES public.bases,
    certainty         text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    note              text,
    UNIQUE (id, collective_id),
    FOREIGN KEY (derived_from, collective_id) REFERENCES public.collective_names (id, collective_id) ON DELETE CASCADE,
    CHECK (conversion_scheme IS NULL OR derived_from IS NOT NULL),
    CHECK (valid_to_year >= valid_from_year)
);
CREATE INDEX idx_collective_names_collective ON public.collective_names (collective_id);

-- ---------------------------------------------------------------------------
-- Attestations of name forms (LRM-E9-A6 reference source, many per name): where
-- a form is found other than in the statements of a manifestation linked to the
-- agent — a reference work, another author's text, a catalogue record. Forms
-- printed on a manifestation are attested by the linking row itself
-- (imprint_agents.*_name_id here; contributions.name_id in a later change).
CREATE TABLE public.person_name_attestations (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name_id     bigint NOT NULL REFERENCES public.person_names ON DELETE CASCADE,
    res_id      bigint REFERENCES public.res ON DELETE CASCADE,
    source_text text,
    locator     text,
    note        text,
    CHECK (res_id IS NOT NULL OR source_text IS NOT NULL)
);
CREATE INDEX idx_person_name_attestations_name ON public.person_name_attestations (name_id);
CREATE INDEX idx_person_name_attestations_res  ON public.person_name_attestations (res_id);

CREATE TABLE public.collective_name_attestations (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name_id     bigint NOT NULL REFERENCES public.collective_names ON DELETE CASCADE,
    res_id      bigint REFERENCES public.res ON DELETE CASCADE,
    source_text text,
    locator     text,
    note        text,
    CHECK (res_id IS NOT NULL OR source_text IS NOT NULL)
);
CREATE INDEX idx_collective_name_attestations_name ON public.collective_name_attestations (name_id);
CREATE INDEX idx_collective_name_attestations_res  ON public.collective_name_attestations (res_id);

-- The form of a publisher's, printer's or distributor's name as found in an
-- imprint (as_printed keeps the exact transcription). The name must belong to
-- the agent of the row (composite FKs); at most one of the two is set.
ALTER TABLE public.imprint_agents
    ADD COLUMN person_name_id     bigint,
    ADD COLUMN collective_name_id bigint,
    ADD FOREIGN KEY (person_name_id, agent_id)
        REFERENCES public.person_names (id, person_id) ON DELETE SET NULL (person_name_id),
    ADD FOREIGN KEY (collective_name_id, agent_id)
        REFERENCES public.collective_names (id, collective_id) ON DELETE SET NULL (collective_name_id),
    ADD CHECK (num_nonnulls(person_name_id, collective_name_id) <= 1);

-- ---------------------------------------------------------------------------
-- Quality checks: extend qa_orphan_res to agents; list agents without a
-- preferred name.
CREATE OR REPLACE VIEW public.qa_orphan_res AS
SELECT r.id, r.kind, r.created_at
  FROM public.res r
 WHERE (r.kind = 'work'          AND NOT EXISTS (SELECT 1 FROM public.works          x WHERE x.id = r.id))
    OR (r.kind = 'expression'    AND NOT EXISTS (SELECT 1 FROM public.expressions    x WHERE x.id = r.id))
    OR (r.kind = 'manifestation' AND NOT EXISTS (SELECT 1 FROM public.manifestations x WHERE x.id = r.id))
    OR (r.kind = 'item'          AND NOT EXISTS (SELECT 1 FROM public.items          x WHERE x.id = r.id))
    OR (r.kind = 'agent'         AND NOT EXISTS (SELECT 1 FROM public.persons        x WHERE x.id = r.id)
                                 AND NOT EXISTS (SELECT 1 FROM public.collectives    x WHERE x.id = r.id));

CREATE VIEW public.qa_agents_without_preferred_name AS
SELECT a.id, a.agent_type
  FROM public.agents a
 WHERE NOT EXISTS (SELECT 1 FROM public.person_names n     WHERE n.person_id = a.id     AND n.name_type = 'preferred')
   AND NOT EXISTS (SELECT 1 FROM public.collective_names n WHERE n.collective_id = a.id AND n.name_type = 'preferred');

COMMIT;
