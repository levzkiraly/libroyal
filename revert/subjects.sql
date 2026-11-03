-- Revert libroyal:subjects from pg
-- Drops the headings, their resolutions and the concepts with their data:
-- restore the backup taken before the deploy to keep them.

BEGIN;

DROP VIEW public.qa_headings_off_work;
DROP VIEW public.qa_unresolved_headings;
DROP VIEW public.work_genre_forms;
DROP VIEW public.work_subjects;
DROP TABLE public.heading_resolutions;
DROP FUNCTION public.heading_resolution_check();
DROP TABLE public.catalogue_headings;
DROP TABLE public.heading_vocabularies;
DROP TABLE public.heading_functions;

CREATE OR REPLACE VIEW public.qa_orphan_res AS
SELECT r.id, r.kind, r.created_at
  FROM public.res r
 WHERE (r.kind = 'work'          AND NOT EXISTS (SELECT 1 FROM public.works          x WHERE x.id = r.id))
    OR (r.kind = 'expression'    AND NOT EXISTS (SELECT 1 FROM public.expressions    x WHERE x.id = r.id))
    OR (r.kind = 'manifestation' AND NOT EXISTS (SELECT 1 FROM public.manifestations x WHERE x.id = r.id))
    OR (r.kind = 'item'          AND NOT EXISTS (SELECT 1 FROM public.items          x WHERE x.id = r.id))
    OR (r.kind = 'agent'         AND NOT EXISTS (SELECT 1 FROM public.persons        x WHERE x.id = r.id)
                                 AND NOT EXISTS (SELECT 1 FROM public.collectives    x WHERE x.id = r.id))
    OR (r.kind = 'place'         AND NOT EXISTS (SELECT 1 FROM public.places         x WHERE x.id = r.id));

DROP TABLE public.concept_names;
DROP TABLE public.concepts;
DROP TABLE public.concept_categories;
DELETE FROM public.res WHERE kind = 'concept';
DELETE FROM public.identifiers WHERE scheme = 'gnd';
DELETE FROM public.identifier_schemes WHERE code = 'gnd';
DELETE FROM public.res_kinds WHERE code = 'concept';

COMMIT;
