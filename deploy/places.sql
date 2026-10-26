-- Deploy libroyal:places to pg
-- requires: agents
-- Places (LRM-E10: hely), "a cultural construction … contemporary or historical";
-- the government of a territory is a collective agent, not a place. Names are
-- nomens valid for a period (Pozsony / Pressburg / Bratislava), in any language
-- and script, with the shared derived-name columns. What a manifestation prints
-- (Lipcse, Pesten) stays in imprint_places.as_printed and links here.

BEGIN;

CREATE TABLE public.place_categories (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text
);
INSERT INTO public.place_categories (code, label_en, label_hu) VALUES
    ('settlement', 'settlement',            'település'),
    ('district',   'district of a settlement', 'településrész'),
    ('region',     'region',                'tájegység, régió'),
    ('country',    'country',               'ország'),
    ('other',      'other',                 'egyéb');

CREATE TABLE public.places (
    id        bigint PRIMARY KEY DEFAULT public.new_res('place'),
    kind      text NOT NULL DEFAULT 'place' CHECK (kind = 'place'),
    category  text NOT NULL REFERENCES public.place_categories,
    parent_id bigint REFERENCES public.places ON DELETE RESTRICT,
    note      text,
    FOREIGN KEY (id, kind) REFERENCES public.res (id, kind) ON DELETE CASCADE
);
COMMENT ON COLUMN public.places.parent_id IS 'LRM-R34: the larger place this one is part of';
CREATE TRIGGER places_res_delete AFTER DELETE ON public.places FOR EACH ROW EXECUTE FUNCTION public.res_delete();

CREATE TABLE public.place_names (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    place_id          bigint NOT NULL REFERENCES public.places ON DELETE CASCADE,
    name_type         text NOT NULL DEFAULT 'official' REFERENCES public.place_name_types,
    value             text NOT NULL,
    is_preferred      boolean NOT NULL DEFAULT false,
    valid_from_year   integer,
    valid_to_year     integer,
    lang              text REFERENCES public.languages,
    script            text NOT NULL DEFAULT 'Latn' REFERENCES public.scripts,
    derived_from      bigint,
    conversion_scheme text REFERENCES public.conversion_schemes,
    basis             text REFERENCES public.bases,
    certainty         text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    reference_source  text,
    note              text,
    UNIQUE (id, place_id),
    FOREIGN KEY (derived_from, place_id) REFERENCES public.place_names (id, place_id) ON DELETE CASCADE,
    CHECK (conversion_scheme IS NULL OR derived_from IS NOT NULL),
    CHECK (valid_to_year >= valid_from_year)
);
CREATE INDEX idx_place_names_place ON public.place_names (place_id);
-- one preferred name per place and language (e.g. Leipzig for de/en, Lipcse for hu)
CREATE UNIQUE INDEX uq_place_names_preferred ON public.place_names (place_id, lang) WHERE is_preferred;

CREATE OR REPLACE VIEW public.qa_orphan_res AS
SELECT r.id, r.kind, r.created_at
  FROM public.res r
 WHERE (r.kind = 'work'          AND NOT EXISTS (SELECT 1 FROM public.works          x WHERE x.id = r.id))
    OR (r.kind = 'expression'    AND NOT EXISTS (SELECT 1 FROM public.expressions    x WHERE x.id = r.id))
    OR (r.kind = 'manifestation' AND NOT EXISTS (SELECT 1 FROM public.manifestations x WHERE x.id = r.id))
    OR (r.kind = 'item'          AND NOT EXISTS (SELECT 1 FROM public.items          x WHERE x.id = r.id))
    OR (r.kind = 'agent'         AND NOT EXISTS (SELECT 1 FROM public.persons        x WHERE x.id = r.id)
                                 AND NOT EXISTS (SELECT 1 FROM public.collectives    x WHERE x.id = r.id))
    OR (r.kind = 'place'         AND NOT EXISTS (SELECT 1 FROM public.places         x WHERE x.id = r.id));

COMMIT;
