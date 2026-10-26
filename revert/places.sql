-- Revert libroyal:places from pg

BEGIN;

CREATE OR REPLACE VIEW public.qa_orphan_res AS
SELECT r.id, r.kind, r.created_at
  FROM public.res r
 WHERE (r.kind = 'work'          AND NOT EXISTS (SELECT 1 FROM public.works          x WHERE x.id = r.id))
    OR (r.kind = 'expression'    AND NOT EXISTS (SELECT 1 FROM public.expressions    x WHERE x.id = r.id))
    OR (r.kind = 'manifestation' AND NOT EXISTS (SELECT 1 FROM public.manifestations x WHERE x.id = r.id))
    OR (r.kind = 'item'          AND NOT EXISTS (SELECT 1 FROM public.items          x WHERE x.id = r.id))
    OR (r.kind = 'agent'         AND NOT EXISTS (SELECT 1 FROM public.persons        x WHERE x.id = r.id)
                                 AND NOT EXISTS (SELECT 1 FROM public.collectives    x WHERE x.id = r.id));
DROP TABLE public.place_names;
DROP TABLE public.places;
DROP TABLE public.place_categories;

COMMIT;
