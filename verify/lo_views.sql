-- Verify libroyal:lo_views on pg

BEGIN;

SELECT manifestation_id, "Identifier", "BibliographyType", "LocalURL"
  FROM public.lo_bibliography_rows('global') WHERE false;
SELECT 'public.lo_sync()'::regprocedure;
SELECT 1 / (count(*) = 2)::int FROM pg_trigger
 WHERE tgname IN ('projects_lo_sync', 'documents_lo_sync') AND NOT tgisinternal;
-- every project and document has its view
SELECT 1 / (count(*) = 0)::int FROM (
    SELECT 'lo_project_' || code AS v FROM public.projects
    UNION ALL SELECT 'lo_document_' || code FROM public.documents) x
 WHERE to_regclass('public.' || quote_ident(x.v)) IS NULL;

ROLLBACK;
