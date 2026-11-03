-- Verify libroyal:legacy_rename on pg
-- Superseded in two steps: wemi_core takes the freed names, drop_legacy drops
-- the legacy_* tables. Each check holds only until its superseding change is
-- deployed.

BEGIN;

DO $verify$
DECLARE
    deployed text[] := ARRAY(SELECT change FROM sqitch.changes WHERE project = 'libroyal');
BEGIN
    IF NOT 'drop_legacy' = ANY (deployed) THEN
        PERFORM id, type, title FROM public.legacy_works WHERE false;
        PERFORM work_id, person_id, role, position FROM public.legacy_work_contributors WHERE false;
        PERFORM id, work_id FROM public.legacy_work_copies WHERE false;
        PERFORM work_id, tag_id FROM public.legacy_work_tags WHERE false;
        PERFORM id, family_name FROM public.legacy_persons WHERE false;
        PERFORM id, name FROM public.legacy_series WHERE false;
        PERFORM id, name FROM public.legacy_tags WHERE false;
    END IF;
    IF NOT 'wemi_core' = ANY (deployed) THEN
        -- the names the new model needs must be free
        IF EXISTS (SELECT 1 FROM pg_class
                    WHERE relnamespace = 'public'::regnamespace
                      AND relname IN ('works', 'works_pkey', 'persons', 'persons_pkey', 'series', 'tags')) THEN
            RAISE EXCEPTION 'names needed by the new model are taken';
        END IF;
    END IF;
END
$verify$;
-- the LibreOffice view still resolves
SELECT "Identifier" FROM public.lo_bibliography WHERE false;

ROLLBACK;
