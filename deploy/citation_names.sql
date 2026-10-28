-- Deploy libroyal:citation_names to pg
-- requires: agents
-- The name a person is cited by in labels ("Name Year"), where it differs from
-- the entry element of the preferred name. Mostly for names whose entry is a
-- given name: "Irenaeus" (entry element, no override) but "Jacobus de Voragine"
-- (the established short form; bare "Jacobus" would be ambiguous).

BEGIN;

ALTER TABLE public.person_names ADD COLUMN citation_name text;
COMMENT ON COLUMN public.person_names.citation_name IS 'name used in citation labels when it differs from the entry element (e.g. Jacobus de Voragine)';

COMMIT;
