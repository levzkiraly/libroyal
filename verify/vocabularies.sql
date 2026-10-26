-- Verify libroyal:vocabularies on pg
-- every vocabulary exists and is seeded (division by zero on an empty one)

BEGIN;

SELECT 1 / (count(*) > 0)::int FROM public.res_kinds;
SELECT 1 / (count(*) > 0)::int FROM public.languages;
SELECT 1 / (count(*) > 0)::int FROM public.scripts;
SELECT 1 / (count(*) > 0)::int FROM public.conversion_schemes;
SELECT 1 / (count(*) > 0)::int FROM public.work_categories;
SELECT 1 / (count(*) > 0)::int FROM public.manifestation_categories;
SELECT 1 / (count(*) > 0)::int FROM public.relation_types;
SELECT 1 / (count(*) > 0)::int FROM public.roles;
SELECT 1 / (count(*) > 0)::int FROM public.imprint_functions;
SELECT 1 / (count(*) > 0)::int FROM public.identifier_schemes;
SELECT 1 / (count(*) > 0)::int FROM public.identifier_statuses;
SELECT 1 / (count(*) > 0)::int FROM public.title_types;
SELECT 1 / (count(*) > 0)::int FROM public.sources;
SELECT 1 / (count(*) > 0)::int FROM public.statement_types;
SELECT 1 / (count(*) > 0)::int FROM public.place_name_types;
SELECT 1 / (count(*) > 0)::int FROM public.bases;
SELECT 1 / (count(*) > 0)::int FROM public.certainties;

ROLLBACK;
