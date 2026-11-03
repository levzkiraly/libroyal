-- Revert libroyal:manuscript_description from pg

BEGIN;

DELETE FROM public.identifier_statuses WHERE code = 'former';
DELETE FROM public.statement_types WHERE code IN ('dimensions', 'physical_details');
DELETE FROM public.scripts WHERE code = 'Qaaa';
DELETE FROM public.languages WHERE code = 'und';

COMMIT;
