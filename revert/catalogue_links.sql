-- Revert libroyal:catalogue_links from pg

BEGIN;

ALTER TABLE public.identifiers DROP COLUMN checked_on_error, DROP COLUMN checked_on_success;
DELETE FROM public.identifier_schemes WHERE code IN ('lccn', 'dnb', 'arcanum');
UPDATE public.identifier_schemes SET label = 'MOKKA record ID',          url_template = NULL, note = NULL WHERE code = 'mokka';
UPDATE public.identifier_schemes SET label = 'OSZK catalogue record ID', url_template = NULL, note = NULL WHERE code = 'oszk';

COMMIT;
