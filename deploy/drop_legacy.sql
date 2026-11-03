-- Deploy libroyal:drop_legacy to pg
-- requires: lo_bibliography
-- requires: legacy_mapping
-- Drop the pre-LRM tables (renamed legacy_* by legacy_rename) and the
-- correspondence tables of legacy_mapping. Their content is in the four-level
-- model (audited 2026-11-02: nothing left unmigrated but the one tag, replaced
-- by project membership); no record of the old ids is kept. The relation type
-- other_format_of stays: the migrated serials use it. No CASCADE: anything
-- still depending on these tables makes the deploy fail.

BEGIN;

DROP TABLE public.legacy_map;
DROP TABLE public.legacy_person_map;
DROP TABLE public.legacy_migration_res;

DROP TABLE public.legacy_work_tags;
DROP TABLE public.legacy_work_copies;
DROP TABLE public.legacy_work_contributors;
DROP TABLE public.legacy_works;
DROP TABLE public.legacy_tags;
DROP TABLE public.legacy_series;
DROP TABLE public.legacy_persons;

COMMIT;
