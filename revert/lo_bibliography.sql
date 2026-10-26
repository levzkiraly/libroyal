-- Revert libroyal:lo_bibliography from pg

BEGIN;

DROP VIEW public.lo_bibliography;

COMMIT;
