-- Revert libroyal:legacy_rename from pg

BEGIN;

ALTER TABLE public.legacy_works RENAME TO works;
ALTER TABLE public.legacy_work_contributors RENAME TO work_contributors;
ALTER TABLE public.legacy_work_copies RENAME TO work_copies;
ALTER TABLE public.legacy_work_tags RENAME TO work_tags;
ALTER TABLE public.legacy_persons RENAME TO persons;
ALTER TABLE public.legacy_series RENAME TO series;
ALTER TABLE public.legacy_tags RENAME TO tags;

ALTER TABLE public.works RENAME CONSTRAINT legacy_works_pkey TO works_pkey;
ALTER TABLE public.works RENAME CONSTRAINT legacy_works_series_id_fkey TO works_series_id_fkey;
ALTER TABLE public.works RENAME CONSTRAINT legacy_works_type_lo_check TO works_type_lo_check;
ALTER TABLE public.persons RENAME CONSTRAINT legacy_persons_pkey TO persons_pkey;
ALTER TABLE public.work_contributors RENAME CONSTRAINT legacy_work_contributors_person_id_fkey TO work_contributors_person_id_fkey;
ALTER TABLE public.work_contributors RENAME CONSTRAINT legacy_work_contributors_pkey TO work_contributors_pkey;
ALTER TABLE public.work_contributors RENAME CONSTRAINT legacy_work_contributors_position_check TO work_contributors_position_check;
ALTER TABLE public.work_contributors RENAME CONSTRAINT legacy_work_contributors_unique_position TO work_contributors_unique_position;
ALTER TABLE public.work_contributors RENAME CONSTRAINT legacy_work_contributors_work_id_fkey TO work_contributors_work_id_fkey;
ALTER TABLE public.tags RENAME CONSTRAINT legacy_tags_name_key TO tags_name_key;
ALTER TABLE public.tags RENAME CONSTRAINT legacy_tags_pkey TO tags_pkey;
ALTER TABLE public.work_tags RENAME CONSTRAINT legacy_work_tags_pkey TO work_tags_pkey;
ALTER TABLE public.work_tags RENAME CONSTRAINT legacy_work_tags_tag_id_fkey TO work_tags_tag_id_fkey;
ALTER TABLE public.work_tags RENAME CONSTRAINT legacy_work_tags_work_id_fkey TO work_tags_work_id_fkey;
ALTER TABLE public.series RENAME CONSTRAINT legacy_series_pkey TO series_pkey;
ALTER TABLE public.work_copies RENAME CONSTRAINT legacy_work_copies_pkey TO work_copies_pkey;
ALTER TABLE public.work_copies RENAME CONSTRAINT legacy_work_copies_work_id_fkey TO work_copies_work_id_fkey;

ALTER INDEX public.legacy_idx_works_type RENAME TO idx_works_type;
ALTER INDEX public.legacy_idx_works_year RENAME TO idx_works_year;
ALTER INDEX public.legacy_idx_persons_family_name RENAME TO idx_persons_family_name;
ALTER INDEX public.legacy_idx_work_contributors_person RENAME TO idx_work_contributors_person;
ALTER INDEX public.legacy_idx_work_contributors_work_role RENAME TO idx_work_contributors_work_role;
ALTER INDEX public.legacy_idx_tags_name RENAME TO idx_tags_name;

ALTER SEQUENCE public.legacy_persons_id_seq RENAME TO persons_id_seq;
ALTER SEQUENCE public.legacy_series_id_seq RENAME TO series_id_seq;
ALTER SEQUENCE public.legacy_tags_id_seq RENAME TO tags_id_seq;
ALTER SEQUENCE public.legacy_work_copies_id_seq RENAME TO work_copies_id_seq;
ALTER SEQUENCE public.legacy_works_id_seq RENAME TO works_id_seq;

COMMIT;
