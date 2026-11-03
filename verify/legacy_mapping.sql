-- Verify libroyal:legacy_mapping on pg
-- drop_legacy drops the correspondence tables; other_format_of stays.

BEGIN;

DO $verify$
BEGIN
    IF EXISTS (SELECT 1 FROM sqitch.changes WHERE project = 'libroyal' AND change = 'drop_legacy') THEN
        RETURN;
    END IF;
    PERFORM legacy_id, work_id, expression_id, manifestation_id FROM public.legacy_map WHERE false;
    PERFORM legacy_id, person_id FROM public.legacy_person_map WHERE false;
    PERFORM res_id FROM public.legacy_migration_res WHERE false;
END
$verify$;
SELECT 1 / (count(*) = 1)::int FROM public.relation_types WHERE code = 'other_format_of';

ROLLBACK;
