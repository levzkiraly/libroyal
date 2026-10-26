-- Revert libroyal:agents from pg

BEGIN;

DROP VIEW public.qa_agents_without_preferred_name;
CREATE OR REPLACE VIEW public.qa_orphan_res AS
SELECT r.id, r.kind, r.created_at
  FROM public.res r
 WHERE (r.kind = 'work'          AND NOT EXISTS (SELECT 1 FROM public.works          x WHERE x.id = r.id))
    OR (r.kind = 'expression'    AND NOT EXISTS (SELECT 1 FROM public.expressions    x WHERE x.id = r.id))
    OR (r.kind = 'manifestation' AND NOT EXISTS (SELECT 1 FROM public.manifestations x WHERE x.id = r.id))
    OR (r.kind = 'item'          AND NOT EXISTS (SELECT 1 FROM public.items          x WHERE x.id = r.id));
ALTER TABLE public.imprint_agents DROP COLUMN collective_name_id, DROP COLUMN person_name_id;
DROP TABLE public.collective_name_attestations;
DROP TABLE public.person_name_attestations;
DROP TABLE public.collective_names;
DROP TABLE public.person_names;
DROP TABLE public.collectives;
DROP TABLE public.persons;
DROP TABLE public.agents;
DROP FUNCTION public.new_agent(text);
DROP TABLE public.generational_labels;
DROP TABLE public.generational_markers;
DROP TABLE public.particle_rules;
DROP TABLE public.name_cultures;
DROP TABLE public.name_types;
DROP TABLE public.collective_categories;
DROP TABLE public.agent_types;

COMMIT;
