-- Deploy libroyal:subjects to pg
-- requires: wemi_links
-- requires: places
-- Subjects as the catalogues give them. Subjects of catalogued works are not
-- ours to assign: every subject link goes back to a heading in a catalogue
-- record.
--   * concepts: a res kind for what is neither work, agent nor place (LRM-E1:
--     Res "includes both material or physical things and concepts"); a time
--     span named as a subject is a concept of category time_span until the
--     model has Time-span (LRM-E11)
--   * catalogue_headings: the access points of a catalogue record as recorded
--     (LRM-E9 nomens: string, scheme, reference source): subject (6XX), genre/
--     form (655), classification (050, 080, 082) and uncontrolled keyword
--     (653), with the subfields and the record they come from
--   * heading_resolutions: which res a heading, or one subfield of it,
--     designates (LRM-R13 inverse); a heading can stay unresolved
--   * work_subjects and work_genre_forms: derived from the two (LRM-R12)

BEGIN;

INSERT INTO public.res_kinds (code, label_en, label_hu, lrm_id) VALUES
    ('concept', 'concept', 'fogalom', NULL);

INSERT INTO public.identifier_schemes (code, label, res_kind, url_template, note) VALUES
    ('gnd', 'Gemeinsame Normdatei', NULL, 'https://d-nb.info/gnd/{}', 'persons, collectives, works, places, subjects');

-- ---------------------------------------------------------------------------
-- Concepts

CREATE TABLE public.concept_categories (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text
);
INSERT INTO public.concept_categories (code, label_en, label_hu) VALUES
    ('topic',     'topic',                    'téma'),
    ('time_span', 'time span (as a subject)', 'időszak (tárgyként)');

CREATE TABLE public.concepts (
    id       bigint PRIMARY KEY DEFAULT public.new_res('concept'),
    kind     text NOT NULL DEFAULT 'concept' CHECK (kind = 'concept'),
    category text NOT NULL DEFAULT 'topic' REFERENCES public.concept_categories,
    note     text,
    FOREIGN KEY (id, kind) REFERENCES public.res (id, kind) ON DELETE CASCADE
);
CREATE TRIGGER concepts_res_delete AFTER DELETE ON public.concepts FOR EACH ROW EXECUTE FUNCTION public.res_delete();

CREATE TABLE public.concept_names (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    concept_id   bigint NOT NULL REFERENCES public.concepts ON DELETE CASCADE,
    value        text NOT NULL,
    lang         text REFERENCES public.languages,
    is_preferred boolean NOT NULL DEFAULT false,
    note         text,
    UNIQUE (concept_id, value, lang)
);
CREATE INDEX idx_concept_names_concept ON public.concept_names (concept_id);
CREATE UNIQUE INDEX uq_concept_names_preferred ON public.concept_names (concept_id, lang) WHERE is_preferred;
COMMENT ON TABLE public.concept_names IS 'our labels of a concept, one preferred per language; the catalogues'' forms are in catalogue_headings';

CREATE OR REPLACE VIEW public.qa_orphan_res AS
SELECT r.id, r.kind, r.created_at
  FROM public.res r
 WHERE (r.kind = 'work'          AND NOT EXISTS (SELECT 1 FROM public.works          x WHERE x.id = r.id))
    OR (r.kind = 'expression'    AND NOT EXISTS (SELECT 1 FROM public.expressions    x WHERE x.id = r.id))
    OR (r.kind = 'manifestation' AND NOT EXISTS (SELECT 1 FROM public.manifestations x WHERE x.id = r.id))
    OR (r.kind = 'item'          AND NOT EXISTS (SELECT 1 FROM public.items          x WHERE x.id = r.id))
    OR (r.kind = 'agent'         AND NOT EXISTS (SELECT 1 FROM public.persons        x WHERE x.id = r.id)
                                 AND NOT EXISTS (SELECT 1 FROM public.collectives    x WHERE x.id = r.id))
    OR (r.kind = 'place'         AND NOT EXISTS (SELECT 1 FROM public.places         x WHERE x.id = r.id))
    OR (r.kind = 'concept'       AND NOT EXISTS (SELECT 1 FROM public.concepts       x WHERE x.id = r.id));

-- ---------------------------------------------------------------------------
-- Headings as recorded

CREATE TABLE public.heading_functions (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text,
    marc     text NOT NULL
);
INSERT INTO public.heading_functions (code, label_en, label_hu, marc) VALUES
    ('subject',        'subject',                'tárgy',             '600–651'),
    ('genre_form',     'genre/form',             'műfaj, forma',      '655'),
    ('classification', 'classification',         'osztályozás',       '050, 080, 082'),
    ('keyword',        'uncontrolled keyword',   'kulcsszó',          '653');

CREATE TABLE public.heading_vocabularies (
    code text PRIMARY KEY,
    label text NOT NULL,
    marc text NOT NULL,
    note text
);
COMMENT ON TABLE public.heading_vocabularies IS 'where a heading''s form comes from: a subject vocabulary, a classification, or none (as the record codes it)';
INSERT INTO public.heading_vocabularies (code, label, marc, note) VALUES
    ('lcsh',         'Library of Congress Subject Headings',     '6XX ind2 0; $2 lcsh', NULL),
    ('lcsh_hun',     'LCSH in Hungarian translation',            '$2 lcsh//hun',        'code lcsh with the language addition hun (LoC Source Codes, Structure: code, slash, edition/language/date addition; 3-letter MARC language code); the empty slot between the slashes is not explained there'),
    ('lcgft',        'LC Genre/Form Terms',                      '655 $2 lcgft',        NULL),
    ('gnd',          'Gemeinsame Normdatei',                     '$2 gnd',              NULL),
    ('oszk',         'OSZK subject terms',                       '$2 oszk',             'local code, not in the LoC source code lists (2026-11-03); MOKKA TAR guide gives it as a $2 example (650/655 #7)'),
    ('szte',         'source coded "szte"',                      '$2 szte',             'local code, not in the LoC source code lists (2026-11-03); presumably the Szeged university library, like klte in the MOKKA TAR guide; not documented'),
    ('doktip',       'OSZK document types',                      '655 $2 doktip',       'local code, not in the LoC source code lists (2026-11-03); OSZK''s document-type terms (e.g. egyetemi jegyzet, elektronikus dokumentum), not documented'),
    ('unspecified',  'source not specified',                     '6XX ind2 4',          NULL),
    ('uncontrolled', 'uncontrolled',                             '653',                 NULL),
    ('udc',          'Universal Decimal Classification',         '080',                 NULL),
    ('ddc',          'Dewey Decimal Classification',             '082 ($2 edition)',    NULL),
    ('lcc',          'Library of Congress Classification',       '050',                 NULL);

CREATE TABLE public.catalogue_headings (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    work_id       bigint NOT NULL REFERENCES public.works ON DELETE CASCADE,
    record_id     bigint NOT NULL REFERENCES public.identifiers ON DELETE CASCADE,
    function      text NOT NULL REFERENCES public.heading_functions,
    vocabulary    text NOT NULL REFERENCES public.heading_vocabularies,
    tag           text NOT NULL CHECK (tag ~ '^[0-9]{3}$'),
    indicators    text NOT NULL DEFAULT '  ' CHECK (length(indicators) = 2),
    value         text NOT NULL,
    subfields     jsonb NOT NULL CHECK (jsonb_typeof(subfields) = 'array'),
    authority_uri text,
    position      integer NOT NULL CHECK (position > 0),
    rejected      text,
    note          text,
    UNIQUE (record_id, position),
    CHECK (rejected <> '')
);
CREATE INDEX idx_catalogue_headings_work ON public.catalogue_headings (work_id);
COMMENT ON TABLE public.catalogue_headings IS 'access points of a catalogue record as recorded (nomens); record_id is the record''s identifier on the manifestation, work_id the work it describes';
COMMENT ON COLUMN public.catalogue_headings.value IS 'the heading as a string: subfields joined (" -- " between subdivisions)';
COMMENT ON COLUMN public.catalogue_headings.subfields IS 'the field''s subfields in order, [["a", "Cryptography"], ["z", "Hungary"]]';
COMMENT ON COLUMN public.catalogue_headings.position IS 'order of the field among the record''s access points';
COMMENT ON COLUMN public.catalogue_headings.rejected IS 'why the heading is not accepted for the work (e.g. a form term that describes its subject, not the work); a rejected heading stays as recorded and is not resolved';

-- ---------------------------------------------------------------------------
-- Resolution

CREATE FUNCTION public.heading_resolution_check() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.catalogue_headings WHERE id = NEW.heading_id AND rejected IS NOT NULL) THEN
        RAISE EXCEPTION 'heading % is rejected and cannot be resolved', NEW.heading_id;
    END IF;
    RETURN NEW;
END $$;

CREATE TABLE public.heading_resolutions (
    heading_id bigint NOT NULL REFERENCES public.catalogue_headings ON DELETE CASCADE,
    res_id     bigint NOT NULL,
    res_kind   text NOT NULL,
    part       integer CHECK (part > 0),
    certainty  text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    note       text,
    PRIMARY KEY (heading_id, res_id),
    FOREIGN KEY (res_id, res_kind) REFERENCES public.res (id, kind) ON DELETE CASCADE
);
CREATE INDEX idx_heading_resolutions_res ON public.heading_resolutions (res_id);
CREATE TRIGGER heading_resolutions_check BEFORE INSERT OR UPDATE ON public.heading_resolutions
    FOR EACH ROW EXECUTE FUNCTION public.heading_resolution_check();
COMMENT ON TABLE public.heading_resolutions IS 'the res a heading designates; part = the subfield (1-based, in subfields) for one part of a pre-coordinated heading, NULL for the whole';

CREATE VIEW public.work_subjects AS
SELECT h.work_id, r.res_id, r.res_kind,
       bool_or(r.certainty = 'certain') AS certain,
       array_agg(DISTINCT h.id ORDER BY h.id) AS heading_ids
  FROM public.catalogue_headings h JOIN public.heading_resolutions r ON r.heading_id = h.id
 WHERE h.function IN ('subject', 'keyword')
 GROUP BY h.work_id, r.res_id, r.res_kind;
COMMENT ON VIEW public.work_subjects IS 'LRM-R12 work has as subject res, from resolved headings; certain = at least one heading resolves to it with certainty';

CREATE VIEW public.work_genre_forms AS
SELECT h.work_id, r.res_id, r.res_kind, array_agg(DISTINCT h.id ORDER BY h.id) AS heading_ids
  FROM public.catalogue_headings h JOIN public.heading_resolutions r ON r.heading_id = h.id
 WHERE h.function = 'genre_form'
 GROUP BY h.work_id, r.res_id, r.res_kind;

CREATE VIEW public.qa_unresolved_headings AS
SELECT h.*
  FROM public.catalogue_headings h
 WHERE h.function <> 'classification' AND h.rejected IS NULL
   AND NOT EXISTS (SELECT 1 FROM public.heading_resolutions r WHERE r.heading_id = h.id);

-- the record must be an identifier of a manifestation embodying the work
CREATE VIEW public.qa_headings_off_work AS
SELECT h.id, h.work_id, i.res_id AS record_res_id, i.res_kind AS record_res_kind
  FROM public.catalogue_headings h JOIN public.identifiers i ON i.id = h.record_id
 WHERE i.res_kind <> 'manifestation'
    OR NOT EXISTS (SELECT 1 FROM public.manifestation_expressions me JOIN public.expressions e ON e.id = me.expression_id
                    WHERE me.manifestation_id = i.res_id AND e.work_id = h.work_id);

COMMIT;
