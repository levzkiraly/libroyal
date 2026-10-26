-- Verify libroyal:name_rendering on pg
-- Checks the rendering rules on fixed examples (division by zero on a mismatch).

BEGIN;

SELECT 1 / (public.particle_rule('van', 'dutch') = false)::int;
SELECT 1 / (public.particle_rule('van', 'belgian') = true)::int;
SELECT 1 / (public.particle_rule('van der', 'dutch') = false)::int;
SELECT 1 / (public.particle_rule('D’', 'italian') = true)::int;
SELECT 1 / (public.particle_rule('in ''t', 'dutch') = false)::int;
SELECT 1 / (public.particle_rule('de', 'hungarian') = true)::int;
SELECT 1 / (public.particle_joiner('d''', NULL) = '')::int;
SELECT 1 / (public.particle_joiner('''t', NULL) = ' ')::int;
SELECT id, person_id, name_type, script, heading, heading_full, display_hu, display_en,
       sort_entry, sort_rest, sort_numeral FROM public.person_names_rendered WHERE false;
SELECT id FROM public.qa_person_names_particle_undecided WHERE false;

ROLLBACK;
