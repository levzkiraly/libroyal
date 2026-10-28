-- Verify libroyal:citation_names on pg

BEGIN;

SELECT citation_name FROM public.person_names WHERE false;

ROLLBACK;
