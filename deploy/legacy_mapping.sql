-- Deploy libroyal:legacy_mapping to pg
-- requires: catalogue_links
-- Structure for carrying the pre-LRM entries (legacy_works) into the four-level
-- model: the correspondence tables, and the work-to-work relation type the
-- serials need. The migration itself is data and lives outside this repository.

BEGIN;

INSERT INTO public.relation_types (code, label_en, inverse_label_en, lrm_id, parent, domain_kind, range_kind, note) VALUES
    ('other_format_of', 'is other format of', 'is other format of', NULL, NULL, 'work', 'work',
     'extension (LRM 5.8 invites serial-specific relationships): print and online serial works of the same publication; symmetric, stored once');

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

-- Every res created by the migration (lets it be undone selectively).
CREATE TABLE public.legacy_migration_res (res_id bigint PRIMARY KEY);

COMMIT;
