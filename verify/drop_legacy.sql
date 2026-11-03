-- Verify libroyal:drop_legacy on pg

BEGIN;

SELECT 1 / (count(*) = 0)::int FROM pg_class
 WHERE relnamespace = 'public'::regnamespace AND relname LIKE 'legacy\_%';
SELECT 1 / (count(*) = 1)::int FROM public.relation_types WHERE code = 'other_format_of';

ROLLBACK;
