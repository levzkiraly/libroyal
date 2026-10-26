-- Deploy libroyal:wemi_core to pg
-- requires: vocabularies
-- The four LRM levels (work, expression, manifestation, item) on a shared res
-- supertable, plus what is transcribed from manifestations: titles, statements
-- and imprints. Agents and places get their own tables in the next change; the
-- references to them here go through res (id, kind) and are already enforced.

BEGIN;

-- ---------------------------------------------------------------------------
-- res: one identity space for every entity, so that relations, identifiers,
-- contributions, notes and tags can attach to any level through one key.
-- (id, kind) is unique so that other tables can pin the kind they expect.
CREATE TABLE public.res (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kind       text NOT NULL REFERENCES public.res_kinds,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, kind)
);

-- Used as the id default of every entity table, so that a single INSERT into
-- e.g. works also creates its res row.
CREATE FUNCTION public.new_res(p_kind text) RETURNS bigint
    LANGUAGE sql VOLATILE
    AS $$ INSERT INTO public.res (kind) VALUES (p_kind) RETURNING id $$;

-- Deleting an entity row deletes its res row as well (the reverse direction is
-- covered by ON DELETE CASCADE on the (id, kind) foreign keys).
CREATE FUNCTION public.res_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM public.res WHERE id = OLD.id;
    RETURN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Work (LRM-E2)
CREATE TABLE public.works (
    id            bigint PRIMARY KEY DEFAULT public.new_res('work'),
    kind          text NOT NULL DEFAULT 'work' CHECK (kind = 'work'),
    category      text NOT NULL REFERENCES public.work_categories,
    date_text     text,
    date_sort     integer,
    date_sort_end integer,
    note          text,
    FOREIGN KEY (id, kind) REFERENCES public.res (id, kind) ON DELETE CASCADE,
    CHECK (date_sort_end >= date_sort)
);
COMMENT ON COLUMN public.works.date_text IS 'date of the work (of its creation) as to be displayed';
COMMENT ON COLUMN public.works.date_sort IS 'first year, for sorting and filtering';

-- Expression (LRM-E3): always explicit, also when work : expression is 1 : 1.
CREATE TABLE public.expressions (
    id            bigint PRIMARY KEY DEFAULT public.new_res('expression'),
    kind          text NOT NULL DEFAULT 'expression' CHECK (kind = 'expression'),
    work_id       bigint NOT NULL REFERENCES public.works ON DELETE RESTRICT,
    lang          text REFERENCES public.languages,
    script        text REFERENCES public.scripts,
    date_text     text,
    date_sort     integer,
    date_sort_end integer,
    note          text,
    FOREIGN KEY (id, kind) REFERENCES public.res (id, kind) ON DELETE CASCADE,
    CHECK (date_sort_end >= date_sort)
);
CREATE INDEX idx_expressions_work ON public.expressions (work_id);
COMMENT ON COLUMN public.expressions.work_id IS 'LRM-R2: the one work this expression realizes';

-- Manifestation (LRM-E4). Dates and places of publication live in imprints.
CREATE TABLE public.manifestations (
    id       bigint PRIMARY KEY DEFAULT public.new_res('manifestation'),
    kind     text NOT NULL DEFAULT 'manifestation' CHECK (kind = 'manifestation'),
    category text NOT NULL REFERENCES public.manifestation_categories,
    extent   text,
    note     text,
    FOREIGN KEY (id, kind) REFERENCES public.res (id, kind) ON DELETE CASCADE
);

-- LRM-R3: a manifestation embodies one or more expressions (an aggregate many).
CREATE TABLE public.manifestation_expressions (
    manifestation_id bigint NOT NULL REFERENCES public.manifestations ON DELETE CASCADE,
    expression_id    bigint NOT NULL REFERENCES public.expressions ON DELETE RESTRICT,
    position         integer NOT NULL DEFAULT 1 CHECK (position > 0),
    PRIMARY KEY (manifestation_id, expression_id)
);
CREATE INDEX idx_manifestation_expressions_expression ON public.manifestation_expressions (expression_id);

-- Item (LRM-E5): exemplifies exactly one manifestation (LRM-R4). holder: the
-- agent currently holding it (own library or another); ownership history goes
-- into contributions with the owner/former_owner roles.
CREATE TABLE public.items (
    id               bigint PRIMARY KEY DEFAULT public.new_res('item'),
    kind             text NOT NULL DEFAULT 'item' CHECK (kind = 'item'),
    manifestation_id bigint NOT NULL REFERENCES public.manifestations ON DELETE RESTRICT,
    holder_id        bigint,
    holder_kind      text NOT NULL DEFAULT 'agent' CHECK (holder_kind = 'agent'),
    location         text,
    path             text,
    url              text,
    mime_type        text,
    note             text,
    FOREIGN KEY (id, kind) REFERENCES public.res (id, kind) ON DELETE CASCADE,
    FOREIGN KEY (holder_id, holder_kind) REFERENCES public.res (id, kind) ON DELETE RESTRICT
);
CREATE INDEX idx_items_manifestation ON public.items (manifestation_id);
COMMENT ON COLUMN public.items.location IS 'place within the holding (room, shelf); not a shelfmark — shelfmarks are identifiers';
COMMENT ON COLUMN public.items.path IS 'local file path of a digital item';

CREATE TRIGGER works_res_delete          AFTER DELETE ON public.works          FOR EACH ROW EXECUTE FUNCTION public.res_delete();
CREATE TRIGGER expressions_res_delete    AFTER DELETE ON public.expressions    FOR EACH ROW EXECUTE FUNCTION public.res_delete();
CREATE TRIGGER manifestations_res_delete AFTER DELETE ON public.manifestations FOR EACH ROW EXECUTE FUNCTION public.res_delete();
CREATE TRIGGER items_res_delete          AFTER DELETE ON public.items          FOR EACH ROW EXECUTE FUNCTION public.res_delete();

-- ---------------------------------------------------------------------------
-- Name-bearing rows below share one pattern (LRM Nomen, R17, E9-A9):
--   lang, script            language and script of the string
--   derived_from            the row it was derived from (transliteration, …);
--                           must belong to the same owner (composite FK)
--   conversion_scheme       the scheme used when the derivation changes script
--   basis, certainty        how the value was established

-- Titles of works, expressions and manifestations.
CREATE TABLE public.titles (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    res_id            bigint NOT NULL,
    res_kind          text NOT NULL CHECK (res_kind IN ('work', 'expression', 'manifestation')),
    title_type        text NOT NULL REFERENCES public.title_types,
    source            text REFERENCES public.sources,
    value             text NOT NULL,
    subtitle          text,
    lang              text REFERENCES public.languages,
    script            text NOT NULL DEFAULT 'Latn' REFERENCES public.scripts,
    derived_from      bigint,
    conversion_scheme text REFERENCES public.conversion_schemes,
    basis             text REFERENCES public.bases,
    certainty         text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    position          integer NOT NULL DEFAULT 1 CHECK (position > 0),
    note              text,
    FOREIGN KEY (res_id, res_kind) REFERENCES public.res (id, kind) ON DELETE CASCADE,
    UNIQUE (id, res_id),
    FOREIGN KEY (derived_from, res_id) REFERENCES public.titles (id, res_id) ON DELETE CASCADE,
    CHECK (conversion_scheme IS NULL OR derived_from IS NOT NULL)
);
CREATE INDEX idx_titles_res ON public.titles (res_id);
COMMENT ON COLUMN public.titles.source IS 'for manifestations: where the title was transcribed from';

-- Transcribed statements of a manifestation that have no structured home of
-- their own (LRM-E4-A4): responsibility, edition, series, extent, other.
CREATE TABLE public.manifestation_statements (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    manifestation_id  bigint NOT NULL REFERENCES public.manifestations ON DELETE CASCADE,
    statement_type    text NOT NULL REFERENCES public.statement_types,
    source            text REFERENCES public.sources,
    value             text NOT NULL,
    lang              text REFERENCES public.languages,
    script            text NOT NULL DEFAULT 'Latn' REFERENCES public.scripts,
    derived_from      bigint,
    conversion_scheme text REFERENCES public.conversion_schemes,
    basis             text NOT NULL DEFAULT 'transcribed' REFERENCES public.bases,
    certainty         text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    position          integer NOT NULL DEFAULT 1 CHECK (position > 0),
    note              text,
    UNIQUE (id, manifestation_id),
    FOREIGN KEY (derived_from, manifestation_id) REFERENCES public.manifestation_statements (id, manifestation_id) ON DELETE CASCADE,
    CHECK (conversion_scheme IS NULL OR derived_from IS NOT NULL)
);
CREATE INDEX idx_manifestation_statements_manifestation ON public.manifestation_statements (manifestation_id);

-- Imprints: a manifestation's sequence of statement groups, each with its own
-- place(s) and agent(s) (ISBD area 4; MOKKA KSZ2 4.2–4.3), per function
-- (publication R7, printing R8, distribution R9, production R7). No place row
-- means [S.l.], no agent row means [s.n.]. The date of the group is here too.
CREATE TABLE public.imprints (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    manifestation_id  bigint NOT NULL REFERENCES public.manifestations ON DELETE CASCADE,
    function          text NOT NULL DEFAULT 'publication' REFERENCES public.imprint_functions,
    position          integer NOT NULL DEFAULT 1 CHECK (position > 0),
    date_as_printed   text,
    date_text         text,
    date_sort         integer,
    date_sort_end     integer,
    date_basis        text REFERENCES public.bases,
    date_certainty    text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    lang              text REFERENCES public.languages,
    script            text NOT NULL DEFAULT 'Latn' REFERENCES public.scripts,
    derived_from      bigint,
    conversion_scheme text REFERENCES public.conversion_schemes,
    note              text,
    UNIQUE (id, manifestation_id),
    FOREIGN KEY (derived_from, manifestation_id) REFERENCES public.imprints (id, manifestation_id) ON DELETE CASCADE,
    CHECK (conversion_scheme IS NULL OR derived_from IS NOT NULL),
    CHECK (date_sort_end >= date_sort)
);
CREATE INDEX idx_imprints_manifestation ON public.imprints (manifestation_id);
COMMENT ON COLUMN public.imprints.date_as_printed IS 'the date exactly as on the resource (e.g. 1985 where 1958 is correct)';
COMMENT ON COLUMN public.imprints.date_text IS 'the established date as to be displayed';

CREATE TABLE public.imprint_places (
    imprint_id bigint NOT NULL REFERENCES public.imprints ON DELETE CASCADE,
    position   integer NOT NULL CHECK (position > 0),
    place_id   bigint,
    place_kind text NOT NULL DEFAULT 'place' CHECK (place_kind = 'place'),
    as_printed text,
    basis      text NOT NULL DEFAULT 'transcribed' REFERENCES public.bases,
    certainty  text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    note       text,
    PRIMARY KEY (imprint_id, position),
    FOREIGN KEY (place_id, place_kind) REFERENCES public.res (id, kind) ON DELETE RESTRICT,
    CHECK (place_id IS NOT NULL OR as_printed IS NOT NULL)
);
CREATE INDEX idx_imprint_places_place ON public.imprint_places (place_id);

CREATE TABLE public.imprint_agents (
    imprint_id bigint NOT NULL REFERENCES public.imprints ON DELETE CASCADE,
    position   integer NOT NULL CHECK (position > 0),
    agent_id   bigint,
    agent_kind text NOT NULL DEFAULT 'agent' CHECK (agent_kind = 'agent'),
    as_printed text,
    basis      text NOT NULL DEFAULT 'transcribed' REFERENCES public.bases,
    certainty  text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    note       text,
    PRIMARY KEY (imprint_id, position),
    FOREIGN KEY (agent_id, agent_kind) REFERENCES public.res (id, kind) ON DELETE RESTRICT,
    CHECK (agent_id IS NOT NULL OR as_printed IS NOT NULL)
);
CREATE INDEX idx_imprint_agents_agent ON public.imprint_agents (agent_id);

-- ---------------------------------------------------------------------------
-- Quality checks. Rules that would block step-by-step data entry (e.g. in
-- LibreOffice Base forms) are reported here instead of being enforced.
CREATE VIEW public.qa_manifestations_without_expression AS
SELECT m.id, m.category
  FROM public.manifestations m
 WHERE NOT EXISTS (SELECT 1 FROM public.manifestation_expressions me WHERE me.manifestation_id = m.id);

CREATE VIEW public.qa_orphan_res AS
SELECT r.id, r.kind, r.created_at
  FROM public.res r
 WHERE (r.kind = 'work'          AND NOT EXISTS (SELECT 1 FROM public.works          x WHERE x.id = r.id))
    OR (r.kind = 'expression'    AND NOT EXISTS (SELECT 1 FROM public.expressions    x WHERE x.id = r.id))
    OR (r.kind = 'manifestation' AND NOT EXISTS (SELECT 1 FROM public.manifestations x WHERE x.id = r.id))
    OR (r.kind = 'item'          AND NOT EXISTS (SELECT 1 FROM public.items          x WHERE x.id = r.id));

COMMIT;
