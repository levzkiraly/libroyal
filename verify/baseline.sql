-- Verify libroyal:baseline on pg

BEGIN;

SELECT id, family_name, given_name, prefix, suffix FROM public.persons WHERE false;
SELECT id, name, issn FROM public.series WHERE false;
SELECT id, name FROM public.tags WHERE false;
SELECT id, type, title, subtitle, year, publisher, place, journal, volume, issue, pages,
       doi, isbn, url, note, series_id, number, booktitle, edition
  FROM public.works WHERE false;
SELECT work_id, person_id, role, position FROM public.work_contributors WHERE false;
SELECT id, work_id, location_type, mime_type, url FROM public.work_copies WHERE false;
SELECT work_id, tag_id FROM public.work_tags WHERE false;

ROLLBACK;
