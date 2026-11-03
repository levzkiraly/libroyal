-- Verify libroyal:manuscript_description on pg

BEGIN;

SELECT 1 / (count(*) = 1)::int FROM public.languages WHERE code = 'und';
SELECT 1 / (count(*) = 1)::int FROM public.scripts WHERE code = 'Qaaa';
SELECT 1 / (count(*) = 2)::int FROM public.statement_types WHERE code IN ('dimensions', 'physical_details');
SELECT 1 / (count(*) = 1)::int FROM public.identifier_statuses WHERE code = 'former';

ROLLBACK;
