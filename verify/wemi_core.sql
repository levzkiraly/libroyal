-- Verify libroyal:wemi_core on pg

BEGIN;

SELECT id, kind, created_at FROM public.res WHERE false;
SELECT id, kind, category, date_text, date_sort, date_sort_end, note FROM public.works WHERE false;
SELECT id, kind, work_id, lang, script, date_text, date_sort, date_sort_end, note FROM public.expressions WHERE false;
SELECT id, kind, category, extent, note FROM public.manifestations WHERE false;
SELECT manifestation_id, expression_id, position FROM public.manifestation_expressions WHERE false;
SELECT id, kind, manifestation_id, holder_id, holder_kind, location, path, url, mime_type, note FROM public.items WHERE false;
SELECT id, res_id, res_kind, title_type, source, value, subtitle, lang, script, derived_from,
       conversion_scheme, basis, certainty, position, note FROM public.titles WHERE false;
SELECT id, manifestation_id, statement_type, source, value, lang, script, derived_from,
       conversion_scheme, basis, certainty, position, note FROM public.manifestation_statements WHERE false;
SELECT id, manifestation_id, function, position, date_as_printed, date_text, date_sort, date_sort_end,
       date_basis, date_certainty, lang, script, derived_from, conversion_scheme, note FROM public.imprints WHERE false;
SELECT imprint_id, position, place_id, place_kind, as_printed, basis, certainty, note FROM public.imprint_places WHERE false;
SELECT imprint_id, position, agent_id, agent_kind, as_printed, basis, certainty, note FROM public.imprint_agents WHERE false;
SELECT id, category FROM public.qa_manifestations_without_expression WHERE false;
SELECT id, kind, created_at FROM public.qa_orphan_res WHERE false;
SELECT has_function_privilege('public.new_res(text)', 'execute');

ROLLBACK;
