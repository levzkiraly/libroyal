-- Revert libroyal:citation_names from pg

BEGIN;

ALTER TABLE public.person_names DROP COLUMN citation_name;

COMMIT;
