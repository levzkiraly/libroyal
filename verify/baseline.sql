-- Verify libroyal:baseline on pg
-- legacy_rename renames these tables (and drop_legacy drops them): once it is
-- deployed there is nothing of the baseline left to check under these names.

BEGIN;

DO $verify$
BEGIN
    IF EXISTS (SELECT 1 FROM sqitch.changes WHERE project = 'libroyal' AND change = 'legacy_rename') THEN
        RETURN;
    END IF;
    PERFORM id, family_name, given_name, prefix, suffix FROM public.persons WHERE false;
    PERFORM id, name, issn FROM public.series WHERE false;
    PERFORM id, name FROM public.tags WHERE false;
    PERFORM id, type, title, subtitle, year, publisher, place, journal, volume, issue, pages,
            doi, isbn, url, note, series_id, number, booktitle, edition
       FROM public.works WHERE false;
    PERFORM work_id, person_id, role, position FROM public.work_contributors WHERE false;
    PERFORM id, work_id, location_type, mime_type, url FROM public.work_copies WHERE false;
    PERFORM work_id, tag_id FROM public.work_tags WHERE false;
END
$verify$;

ROLLBACK;
