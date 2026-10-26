-- Verify libroyal:lo_bibliography on pg
-- Checks the column contract that LibreOffice (libroyal.odb) reads.

BEGIN;

SELECT "Identifier", "BibliographyType", "Author", "Editor", "Title", "Subtitle", "Year",
       "Publisher", "Address", "Journal", "Volume", "Number", "Pages", "ISBN", "URL",
       "Custom1", "Custom2", "Custom3", "Note", "Annote", "Booktitle", "Chapter", "Edition",
       "Howpublished", "Institution", "Month", "Organizations", "School", "Series",
       "ReportType", "Custom4", "Custom5", "LocalURL"
  FROM public.lo_bibliography WHERE false;

ROLLBACK;
