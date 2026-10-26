-- Deploy libroyal:legacy_rename to pg
-- requires: baseline
-- requires: lo_bibliography
-- Moves the pre-LRM tables out of the way of the new model. Constraint, index and
-- sequence names are renamed too: Postgres keeps them on table rename, and e.g.
-- works_pkey would collide with the new works table. lo_bibliography keeps working:
-- views reference tables by OID, not by name.

BEGIN;

ALTER TABLE public.works RENAME CONSTRAINT works_pkey TO legacy_works_pkey;
ALTER TABLE public.works RENAME CONSTRAINT works_series_id_fkey TO legacy_works_series_id_fkey;
ALTER TABLE public.works RENAME CONSTRAINT works_type_lo_check TO legacy_works_type_lo_check;
ALTER TABLE public.persons RENAME CONSTRAINT persons_pkey TO legacy_persons_pkey;
ALTER TABLE public.work_contributors RENAME CONSTRAINT work_contributors_person_id_fkey TO legacy_work_contributors_person_id_fkey;
ALTER TABLE public.work_contributors RENAME CONSTRAINT work_contributors_pkey TO legacy_work_contributors_pkey;
ALTER TABLE public.work_contributors RENAME CONSTRAINT work_contributors_position_check TO legacy_work_contributors_position_check;
ALTER TABLE public.work_contributors RENAME CONSTRAINT work_contributors_unique_position TO legacy_work_contributors_unique_position;
ALTER TABLE public.work_contributors RENAME CONSTRAINT work_contributors_work_id_fkey TO legacy_work_contributors_work_id_fkey;
ALTER TABLE public.tags RENAME CONSTRAINT tags_name_key TO legacy_tags_name_key;
ALTER TABLE public.tags RENAME CONSTRAINT tags_pkey TO legacy_tags_pkey;
ALTER TABLE public.work_tags RENAME CONSTRAINT work_tags_pkey TO legacy_work_tags_pkey;
ALTER TABLE public.work_tags RENAME CONSTRAINT work_tags_tag_id_fkey TO legacy_work_tags_tag_id_fkey;
ALTER TABLE public.work_tags RENAME CONSTRAINT work_tags_work_id_fkey TO legacy_work_tags_work_id_fkey;
ALTER TABLE public.series RENAME CONSTRAINT series_pkey TO legacy_series_pkey;
ALTER TABLE public.work_copies RENAME CONSTRAINT work_copies_pkey TO legacy_work_copies_pkey;
ALTER TABLE public.work_copies RENAME CONSTRAINT work_copies_work_id_fkey TO legacy_work_copies_work_id_fkey;

ALTER INDEX public.idx_works_type RENAME TO legacy_idx_works_type;
ALTER INDEX public.idx_works_year RENAME TO legacy_idx_works_year;
ALTER INDEX public.idx_persons_family_name RENAME TO legacy_idx_persons_family_name;
ALTER INDEX public.idx_work_contributors_person RENAME TO legacy_idx_work_contributors_person;
ALTER INDEX public.idx_work_contributors_work_role RENAME TO legacy_idx_work_contributors_work_role;
ALTER INDEX public.idx_tags_name RENAME TO legacy_idx_tags_name;

ALTER SEQUENCE public.persons_id_seq RENAME TO legacy_persons_id_seq;
ALTER SEQUENCE public.series_id_seq RENAME TO legacy_series_id_seq;
ALTER SEQUENCE public.tags_id_seq RENAME TO legacy_tags_id_seq;
ALTER SEQUENCE public.work_copies_id_seq RENAME TO legacy_work_copies_id_seq;
ALTER SEQUENCE public.works_id_seq RENAME TO legacy_works_id_seq;

ALTER TABLE public.works RENAME TO legacy_works;
ALTER TABLE public.work_contributors RENAME TO legacy_work_contributors;
ALTER TABLE public.work_copies RENAME TO legacy_work_copies;
ALTER TABLE public.work_tags RENAME TO legacy_work_tags;
ALTER TABLE public.persons RENAME TO legacy_persons;
ALTER TABLE public.series RENAME TO legacy_series;
ALTER TABLE public.tags RENAME TO legacy_tags;

COMMIT;
