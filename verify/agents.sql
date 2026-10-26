-- Verify libroyal:agents on pg

BEGIN;

SELECT 1 / (count(*) > 0)::int FROM public.agent_types;
SELECT 1 / (count(*) > 0)::int FROM public.collective_categories;
SELECT 1 / (count(*) > 0)::int FROM public.name_types;
SELECT 1 / (count(*) > 0)::int FROM public.name_cultures;
SELECT 1 / (count(*) > 0)::int FROM public.particle_rules;
SELECT 1 / (count(*) > 0)::int FROM public.generational_labels;
SELECT id, kind, agent_type, note FROM public.agents WHERE false;
SELECT id, agent_type, birth_text, birth_year, death_text, death_year, floruit_text, note FROM public.persons WHERE false;
SELECT id, agent_type, category, parent_id, start_text, start_year, end_text, end_year, note FROM public.collectives WHERE false;
SELECT id, person_id, name_type, entry, name_order, culture, family_name, given_name, patronymic,
       particle, particle_in_entry, particle_joined, predicate, epithet, noble_title, numeral,
       generational, generational_ordinal, qualifier, heading_override, display_override, sort_override, lang, script,
       derived_from, conversion_scheme, basis, certainty, note
  FROM public.person_names WHERE false;
SELECT id, collective_id, name_type, value, valid_from_year, valid_to_year, lang, script, derived_from,
       conversion_scheme, basis, certainty, note
  FROM public.collective_names WHERE false;
SELECT id, name_id, res_id, source_text, locator, note FROM public.person_name_attestations WHERE false;
SELECT id, name_id, res_id, source_text, locator, note FROM public.collective_name_attestations WHERE false;
SELECT person_name_id, collective_name_id FROM public.imprint_agents WHERE false;
SELECT id, agent_type FROM public.qa_agents_without_preferred_name WHERE false;
SELECT has_function_privilege('public.new_agent(text)', 'execute');

ROLLBACK;
