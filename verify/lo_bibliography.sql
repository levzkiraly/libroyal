-- Verify libroyal:lo_bibliography on pg
-- Checks the column contract that LibreOffice (libroyal.odb) reads.

BEGIN;

SELECT "Identifier", "BibliographyType", "Author", "Editor", "Title", "Subtitle", "Year",
       "Publisher", "Address", "Journal", "Volume", "Number", "Pages", "ISBN", "URL",
       "Custom1", "Custom2", "Custom3", "Note", "Annote", "Booktitle", "Chapter", "Edition",
       "Howpublished", "Institution", "Month", "Organizations", "School", "Series",
       "ReportType", "Custom4", "Custom5", "LocalURL"
  FROM public.lo_bibliography WHERE false;
-- one row per migrated entry, labels unique within the view
SELECT 1 / (count(*) = (SELECT count(*) FROM public.legacy_map))::int FROM public.lo_bibliography;
SELECT 1 / (count(*) = count(DISTINCT "Identifier"))::int FROM public.lo_bibliography;

ROLLBACK;
