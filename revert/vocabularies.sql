-- Revert libroyal:vocabularies from pg

BEGIN;

DROP TABLE public.certainties;
DROP TABLE public.bases;
DROP TABLE public.place_name_types;
DROP TABLE public.statement_types;
DROP TABLE public.sources;
DROP TABLE public.title_types;
DROP TABLE public.identifier_statuses;
DROP TABLE public.identifier_schemes;
DROP TABLE public.imprint_functions;
DROP TABLE public.roles;
DROP TABLE public.relation_types;
DROP TABLE public.manifestation_categories;
DROP TABLE public.work_categories;
DROP TABLE public.conversion_schemes;
DROP TABLE public.scripts;
DROP TABLE public.languages;
DROP TABLE public.res_kinds;

COMMIT;
