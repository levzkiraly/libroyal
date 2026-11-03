-- Revert libroyal:drop_legacy from pg
-- Recreates the tables empty, with their constraints, indexes and sequences as
-- they were. The data is not restored: restore the backup taken before the
-- deploy for that.

BEGIN;

CREATE TABLE public.legacy_persons (
    id          bigserial PRIMARY KEY,
    family_name text NOT NULL,
    given_name  text,
    prefix      text,
    suffix      text
);
CREATE INDEX legacy_idx_persons_family_name ON public.legacy_persons (family_name);

CREATE TABLE public.legacy_series (
    id   bigserial PRIMARY KEY,
    name varchar(255) NOT NULL,
    issn varchar(9)
);

CREATE TABLE public.legacy_tags (
    id   bigserial PRIMARY KEY,
    name text NOT NULL UNIQUE
);
CREATE INDEX legacy_idx_tags_name ON public.legacy_tags (name);

CREATE TABLE public.legacy_works (
    id        bigserial PRIMARY KEY,
    type      text NOT NULL,
    title     text NOT NULL,
    subtitle  text,
    year      text,
    publisher text,
    place     text,
    journal   text,
    volume    text,
    issue     text,
    pages     text,
    doi       text,
    isbn      text,
    url       text,
    note      text,
    series_id bigint REFERENCES public.legacy_series ON DELETE SET NULL,
    number    varchar(12),
    booktitle text,
    edition   text,
    CONSTRAINT legacy_works_type_lo_check CHECK (type IN (
        'article', 'book', 'booklet', 'conference', 'inbook', 'incollection', 'inproceedings',
        'journal', 'manual', 'mastersthesis', 'misc', 'phdthesis', 'proceedings', 'techreport',
        'unpublished', 'email', 'www', 'custom1', 'custom2', 'custom3', 'custom4', 'custom5'))
);
CREATE INDEX legacy_idx_works_type ON public.legacy_works (type);
CREATE INDEX legacy_idx_works_year ON public.legacy_works (year);

CREATE TABLE public.legacy_work_contributors (
    work_id    bigint NOT NULL REFERENCES public.legacy_works ON DELETE CASCADE,
    person_id  bigint NOT NULL REFERENCES public.legacy_persons ON DELETE RESTRICT,
    role       text NOT NULL,
    "position" integer NOT NULL CHECK ("position" > 0),
    PRIMARY KEY (work_id, person_id, role),
    CONSTRAINT legacy_work_contributors_unique_position UNIQUE (work_id, role, "position")
);
CREATE INDEX legacy_idx_work_contributors_person ON public.legacy_work_contributors (person_id);
CREATE INDEX legacy_idx_work_contributors_work_role ON public.legacy_work_contributors (work_id, role);

CREATE TABLE public.legacy_work_copies (
    id            bigserial PRIMARY KEY,
    work_id       bigint NOT NULL REFERENCES public.legacy_works ON DELETE CASCADE,
    location_type varchar(12) NOT NULL,
    mime_type     varchar(255) NOT NULL,
    url           text NOT NULL
);

CREATE TABLE public.legacy_work_tags (
    work_id bigint NOT NULL REFERENCES public.legacy_works ON DELETE CASCADE,
    tag_id  bigint NOT NULL REFERENCES public.legacy_tags ON DELETE CASCADE,
    PRIMARY KEY (work_id, tag_id)
);

CREATE TABLE public.legacy_map (
    legacy_id        bigint PRIMARY KEY REFERENCES public.legacy_works,
    work_id          bigint NOT NULL REFERENCES public.works,
    expression_id    bigint NOT NULL REFERENCES public.expressions,
    manifestation_id bigint NOT NULL REFERENCES public.manifestations
);
COMMENT ON TABLE public.legacy_map IS 'pre-LRM legacy_works row → the work, expression and manifestation it was migrated to';

CREATE TABLE public.legacy_person_map (
    legacy_id bigint PRIMARY KEY REFERENCES public.legacy_persons,
    person_id bigint NOT NULL REFERENCES public.persons
);

CREATE TABLE public.legacy_migration_res (res_id bigint PRIMARY KEY);

COMMIT;
