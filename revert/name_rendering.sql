-- Revert libroyal:name_rendering from pg

BEGIN;

DROP VIEW public.qa_person_names_particle_undecided;
DROP VIEW public.person_names_rendered;
DROP FUNCTION public.person_name_display(public.person_names, text);
DROP FUNCTION public.person_name_heading_full(public.person_names);
DROP FUNCTION public.person_name_heading(public.person_names);
DROP FUNCTION public.person_name_rest(public.person_names);
DROP FUNCTION public.person_name_entry(public.person_names);
DROP FUNCTION public.generational_label(public.person_names, text);
DROP FUNCTION public.particle_in_entry(public.person_names);
DROP FUNCTION public.particle_joiner(text, boolean);
DROP FUNCTION public.particle_rule(text, text);
DROP FUNCTION public.normalize_particle(text);
DROP TABLE public.name_element_placements;

COMMIT;
