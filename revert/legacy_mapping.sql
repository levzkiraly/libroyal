-- Revert libroyal:legacy_mapping from pg
-- Fails while migrated data still uses other_format_of: undo the data first
-- (restore the backup taken before the migration).

BEGIN;

DROP TABLE public.legacy_migration_res;
DROP TABLE public.legacy_person_map;
DROP TABLE public.legacy_map;

DELETE FROM public.relation_types WHERE code = 'other_format_of';

COMMIT;
