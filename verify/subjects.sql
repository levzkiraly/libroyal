-- Verify libroyal:subjects on pg

BEGIN;

SELECT 1 / (count(*) = 1)::int FROM public.res_kinds WHERE code = 'concept';
SELECT 1 / (count(*) = 1)::int FROM public.identifier_schemes WHERE code = 'gnd';
SELECT id, kind, category FROM public.concepts WHERE false;
SELECT concept_id, value, lang, is_preferred FROM public.concept_names WHERE false;
SELECT work_id, record_id, function, vocabulary, tag, indicators, value, subfields, authority_uri, position, rejected
  FROM public.catalogue_headings WHERE false;
SELECT heading_id, res_id, res_kind, part, certainty FROM public.heading_resolutions WHERE false;
SELECT work_id, res_id, res_kind, certain, heading_ids FROM public.work_subjects WHERE false;
SELECT work_id, res_id, res_kind, heading_ids FROM public.work_genre_forms WHERE false;
SELECT 1 / (count(*) = 0)::int FROM public.qa_headings_off_work;
SELECT 'public.heading_resolution_check()'::regprocedure;

ROLLBACK;
