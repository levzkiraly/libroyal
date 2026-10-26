-- Verify libroyal:places on pg

BEGIN;

SELECT 1 / (count(*) > 0)::int FROM public.place_categories;
SELECT id, kind, category, parent_id, note FROM public.places WHERE false;
SELECT id, place_id, name_type, value, is_preferred, valid_from_year, valid_to_year, lang, script,
       derived_from, conversion_scheme, basis, certainty, reference_source, note
  FROM public.place_names WHERE false;

ROLLBACK;
