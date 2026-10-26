-- Verify libroyal:catalogue_links on pg

BEGIN;

SELECT checked_on_success, checked_on_error FROM public.identifiers WHERE false;
SELECT 1 / (count(*) = 3)::int FROM public.identifier_schemes WHERE code IN ('lccn', 'dnb', 'arcanum');
SELECT 1 / (count(*) = 2)::int FROM public.identifier_schemes WHERE code IN ('oszk', 'mokka') AND url_template IS NOT NULL;

ROLLBACK;
