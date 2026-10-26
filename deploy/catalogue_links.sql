-- Deploy libroyal:catalogue_links to pg
-- requires: wemi_links
-- Links to catalogue records describing a manifestation (not to library
-- holdings: following the life cycle of other libraries' copies is out of
-- scope). The record identifier is stored as the catalogue gives it; the URL
-- template turns it into a permalink. Link checks are recorded on the
-- identifier: the last successful retrieval and the last failure (a failure
-- may be temporary or signal a migration of the remote catalogue).

BEGIN;

UPDATE public.identifier_schemes
   SET label = 'OSZK NEKTÁR record', url_template = 'https://nektar.oszk.hu/hu/manifestation/{}',
       note = 'record number as in field 001 (leading zeros are accepted by the permalink)'
 WHERE code = 'oszk';
UPDATE public.identifier_schemes
   SET label = 'MOKKA record', url_template = 'https://odrportal.hu/web/guest/record/-/record/{}',
       note = 'bibMOK… record identifier; permalink on the ODR portal'
 WHERE code = 'mokka';
INSERT INTO public.identifier_schemes (code, label, res_kind, url_template, note) VALUES
    ('lccn',     'LCCN (Library of Congress record)', 'manifestation', 'https://lccn.loc.gov/{}', NULL),
    ('dnb',      'DNB record (IDN)',                  'manifestation', 'https://d-nb.info/{}',   NULL),
    ('arcanum',  'Arcanum ADT document',              'manifestation', 'https://adt.arcanum.com/hu/view/{}/',
     'docId of the digitized volume or issue (an online manifestation); the page goes into qualifier');

ALTER TABLE public.identifiers
    ADD COLUMN checked_on_success date,
    ADD COLUMN checked_on_error   date;
COMMENT ON COLUMN public.identifiers.checked_on_success IS 'last date the identifier or its permalink was successfully checked against the issuing service';
COMMENT ON COLUMN public.identifiers.checked_on_error   IS 'last date a check failed (not cleared by a later success: both dates are kept)';

COMMIT;
