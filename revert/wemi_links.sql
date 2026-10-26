-- Revert libroyal:wemi_links from pg

BEGIN;

DROP VIEW public.name_attestations;
DROP VIEW public.qa_identifier_checksums;
DROP TABLE public.identifiers;
DROP FUNCTION public.identifiers_check_kind();
DROP FUNCTION public.identifier_checksum_ok(text, text);
DROP FUNCTION public.normalize_identifier(text, text);
DROP TABLE public.statement_agents;
DROP TABLE public.contributions;
DROP TABLE public.relations;
DELETE FROM public.relation_types WHERE code IN ('edition_of', 'retroversion_of', 'transmitted_in');

COMMIT;
