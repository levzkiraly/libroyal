-- Verify libroyal:legacy_mapping on pg

BEGIN;

SELECT legacy_id, work_id, expression_id, manifestation_id FROM public.legacy_map WHERE false;
SELECT legacy_id, person_id FROM public.legacy_person_map WHERE false;
SELECT res_id FROM public.legacy_migration_res WHERE false;
SELECT 1 / (count(*) = 1)::int FROM public.relation_types WHERE code = 'other_format_of';

ROLLBACK;
