-- Revert libroyal:wemi_core from pg

BEGIN;

DROP VIEW public.qa_orphan_res;
DROP VIEW public.qa_manifestations_without_expression;
DROP TABLE public.imprint_agents;
DROP TABLE public.imprint_places;
DROP TABLE public.imprints;
DROP TABLE public.manifestation_statements;
DROP TABLE public.titles;
DROP TABLE public.items;
DROP TABLE public.manifestation_expressions;
DROP TABLE public.manifestations;
DROP TABLE public.expressions;
DROP TABLE public.works;
DROP FUNCTION public.res_delete();
DROP FUNCTION public.new_res(text);
DROP TABLE public.res;

COMMIT;
