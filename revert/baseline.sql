-- Revert libroyal:baseline from pg

BEGIN;

DROP TABLE public.work_tags;
DROP TABLE public.work_copies;
DROP TABLE public.work_contributors;
DROP TABLE public.works;
DROP TABLE public.tags;
DROP TABLE public.series;
DROP TABLE public.persons;

COMMIT;
