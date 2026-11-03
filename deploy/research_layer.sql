-- Deploy libroyal:research_layer to pg
-- requires: wemi_links
-- requires: places
-- The research layer: what is ours rather than the catalogue's.
--   * projects, with their subjects (any res), members (any WEMI level),
--     and an outline of sections to arrange the members in
--   * documents: own writings. A document is a catalogued work with the
--     expression being written; manifestations follow on publication. An
--     unpublished manuscript is a document.
--   * citations: a text (expression) citing a manifestation or item, with
--     locators on both sides; for published works checkable against reference
--     lists (Crossref), for own drafts ours
--   * notes (titled texts in a project) and cards (the same, about one entry,
--     with a locator)
-- Subjects of catalogued works are not ours to assign: they come from catalogue
-- records, in a later change.

BEGIN;

-- ---------------------------------------------------------------------------
-- Projects

CREATE TABLE public.projects (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code      text NOT NULL UNIQUE CHECK (code ~ '^[a-z][a-z0-9_]{0,39}$'),
    name      text NOT NULL,
    parent_id bigint REFERENCES public.projects ON DELETE RESTRICT,
    note      text,
    CHECK (parent_id <> id)
);
COMMENT ON TABLE public.projects IS 'research projects; code names the generated LibreOffice view (lo_project_<code>)';

CREATE TABLE public.project_subjects (
    project_id bigint NOT NULL REFERENCES public.projects ON DELETE CASCADE,
    res_id     bigint NOT NULL,
    res_kind   text NOT NULL,
    note       text,
    PRIMARY KEY (project_id, res_id),
    FOREIGN KEY (res_id, res_kind) REFERENCES public.res (id, kind) ON DELETE CASCADE
);
COMMENT ON TABLE public.project_subjects IS 'what a project is about: any res, at the level that fits (a work, a manifestation, a person …)';

CREATE TABLE public.project_members (
    project_id bigint NOT NULL REFERENCES public.projects ON DELETE CASCADE,
    res_id     bigint NOT NULL,
    res_kind   text NOT NULL CHECK (res_kind IN ('work', 'expression', 'manifestation', 'item')),
    added_on   date NOT NULL DEFAULT current_date,
    note       text,
    PRIMARY KEY (project_id, res_id),
    FOREIGN KEY (res_id, res_kind) REFERENCES public.res (id, kind) ON DELETE CASCADE
);
CREATE INDEX idx_project_members_res ON public.project_members (res_id);
COMMENT ON TABLE public.project_members IS 'what a project collects; in LibreOffice views a manifestation (an item counts as its manifestation)';

CREATE TABLE public.project_sections (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id bigint NOT NULL REFERENCES public.projects ON DELETE CASCADE,
    parent_id  bigint,
    label      text NOT NULL,
    position   integer NOT NULL DEFAULT 1 CHECK (position > 0),
    note       text,
    UNIQUE (id, project_id),
    FOREIGN KEY (parent_id, project_id) REFERENCES public.project_sections (id, project_id) ON DELETE CASCADE,
    CHECK (parent_id <> id)
);
COMMENT ON TABLE public.project_sections IS 'outline of a project (its own arrangement of the members); parent in the same project';

CREATE TABLE public.project_member_sections (
    project_id bigint NOT NULL,
    res_id     bigint NOT NULL,
    section_id bigint NOT NULL,
    PRIMARY KEY (section_id, res_id),
    FOREIGN KEY (project_id, res_id) REFERENCES public.project_members (project_id, res_id) ON DELETE CASCADE,
    FOREIGN KEY (section_id, project_id) REFERENCES public.project_sections (id, project_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- Documents

CREATE TABLE public.document_statuses (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text NOT NULL,
    position integer NOT NULL
);
INSERT INTO public.document_statuses (code, label_en, label_hu, position) VALUES
    ('draft',     'draft',     'készülő',     1),
    ('submitted', 'submitted', 'beküldött',   2),
    ('accepted',  'accepted',  'elfogadott',  3),
    ('published', 'published', 'megjelent',   4),
    ('abandoned', 'abandoned', 'abbahagyott', 5);

ALTER TABLE public.expressions ADD UNIQUE (id, work_id);

CREATE TABLE public.documents (
    work_id       bigint PRIMARY KEY REFERENCES public.works ON DELETE CASCADE,
    expression_id bigint NOT NULL,
    project_id    bigint NOT NULL REFERENCES public.projects ON DELETE RESTRICT,
    code          text NOT NULL UNIQUE CHECK (code ~ '^[a-z][a-z0-9_]{0,39}$'),
    status        text NOT NULL DEFAULT 'draft' REFERENCES public.document_statuses,
    note          text,
    FOREIGN KEY (expression_id, work_id) REFERENCES public.expressions (id, work_id) ON DELETE RESTRICT
);
COMMENT ON TABLE public.documents IS 'own writings: the work, the expression being written (whose citations make its bibliography), project and status; code names the generated LibreOffice view (lo_document_<code>)';

-- ---------------------------------------------------------------------------
-- Citations

CREATE TABLE public.citations (
    id                      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    citing_expression_id    bigint NOT NULL REFERENCES public.expressions ON DELETE CASCADE,
    citing_manifestation_id bigint,
    citing_locator          text,
    citing_note             text,
    citing_note_locator     text,
    cited_id                bigint NOT NULL,
    cited_kind              text NOT NULL CHECK (cited_kind IN ('manifestation', 'item')),
    cited_locator           text,
    position                integer CHECK (position > 0),
    basis                   text REFERENCES public.bases,
    note                    text,
    FOREIGN KEY (citing_manifestation_id, citing_expression_id)
        REFERENCES public.manifestation_expressions (manifestation_id, expression_id) ON DELETE CASCADE,
    FOREIGN KEY (cited_id, cited_kind) REFERENCES public.res (id, kind) ON DELETE CASCADE
);
CREATE INDEX idx_citations_citing ON public.citations (citing_expression_id);
CREATE INDEX idx_citations_cited ON public.citations (cited_id);
COMMENT ON TABLE public.citations IS 'a text citing a manifestation or item; one row per citation (a pair may recur in several notes)';
COMMENT ON COLUMN public.citations.citing_manifestation_id IS 'the manifestation whose pagination the citing locators refer to; NULL for an unpublished text';
COMMENT ON COLUMN public.citations.citing_locator IS 'where the reference stands, e.g. "p. 191"';
COMMENT ON COLUMN public.citations.citing_note IS 'the note carrying the reference, e.g. "n. 8"';
COMMENT ON COLUMN public.citations.citing_note_locator IS 'where the note itself stands, e.g. "p. 195" (endnotes)';
COMMENT ON COLUMN public.citations.cited_locator IS 'the part of the cited entry referred to, e.g. "esp. 15, 18–19"';
COMMENT ON COLUMN public.citations.position IS 'order among the references of the same note or place';

-- ---------------------------------------------------------------------------
-- Notes and cards

CREATE FUNCTION public.touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END $$;

CREATE TABLE public.notes (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id bigint NOT NULL REFERENCES public.projects ON DELETE CASCADE,
    title      text NOT NULL,
    body       text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_notes_project ON public.notes (project_id);
COMMENT ON TABLE public.notes IS 'titled texts of a project (body in Markdown)';
CREATE TRIGGER notes_touch BEFORE UPDATE ON public.notes
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TABLE public.cards (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id bigint NOT NULL REFERENCES public.projects ON DELETE CASCADE,
    res_id     bigint NOT NULL,
    res_kind   text NOT NULL CHECK (res_kind IN ('work', 'expression', 'manifestation', 'item')),
    locator    text,
    title      text NOT NULL,
    body       text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (res_id, res_kind) REFERENCES public.res (id, kind) ON DELETE CASCADE
);
CREATE INDEX idx_cards_project ON public.cards (project_id);
CREATE INDEX idx_cards_res ON public.cards (res_id);
COMMENT ON TABLE public.cards IS 'titled texts of a project about one entry, at a locator (e.g. "f. 223v"); several cards per entry';
CREATE TRIGGER cards_touch BEFORE UPDATE ON public.cards
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

COMMIT;
