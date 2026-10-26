-- Verify libroyal:legacy_rename on pg

BEGIN;

SELECT id, type, title FROM public.legacy_works WHERE false;
SELECT work_id, person_id, role, position FROM public.legacy_work_contributors WHERE false;
SELECT id, work_id FROM public.legacy_work_copies WHERE false;
SELECT work_id, tag_id FROM public.legacy_work_tags WHERE false;
SELECT id, family_name FROM public.legacy_persons WHERE false;
SELECT id, name FROM public.legacy_series WHERE false;
SELECT id, name FROM public.legacy_tags WHERE false;
-- the names the new model needs must be free (division by zero otherwise)
SELECT 1 / (count(*) = 0)::int FROM pg_class
 WHERE relnamespace = 'public'::regnamespace
   AND relname IN ('works', 'works_pkey', 'persons', 'persons_pkey', 'series', 'tags');
-- the LibreOffice view still resolves
SELECT "Identifier" FROM public.lo_bibliography WHERE false;

ROLLBACK;
