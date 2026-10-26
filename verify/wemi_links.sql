-- Verify libroyal:wemi_links on pg

BEGIN;

SELECT id, type, from_id, from_kind, to_id, to_kind, locator, position, basis, certainty, note FROM public.relations WHERE false;
SELECT id, res_id, res_kind, agent_id, agent_kind, role, position, basis, certainty, note FROM public.contributions WHERE false;
SELECT statement_id, position, agent_id, agent_kind, person_name_id, collective_name_id, as_printed, basis, certainty, note
  FROM public.statement_agents WHERE false;
SELECT id, res_id, res_kind, scheme, value, normalized, status, qualifier, assigned_by, assigned_by_kind, corrects, basis, note
  FROM public.identifiers WHERE false;
SELECT id FROM public.qa_identifier_checksums WHERE false;
SELECT name_kind, name_id, via, res_id, source_text, locator FROM public.name_attestations WHERE false;
-- check digits: valid ISBN-13 (Filoramo, Hungarian ed.), valid ISBN-10, valid ISSN, broken ISBN-13
SELECT 1 / (public.identifier_checksum_ok('isbn', public.normalize_identifier('isbn', '978-963-9302-33-4')))::int;
SELECT 1 / (public.identifier_checksum_ok('isbn', public.normalize_identifier('isbn', '0-306-40615-2')))::int;
SELECT 1 / (public.identifier_checksum_ok('issn', public.normalize_identifier('issn', '0133-5987')))::int;
SELECT 1 / (NOT public.identifier_checksum_ok('isbn', '9789639302335'))::int;
-- ORCID: the example iD of the ORCID documentation, given in three accepted forms
SELECT 1 / (public.identifier_checksum_ok('orcid', public.normalize_identifier('orcid', 'https://orcid.org/0000-0002-1825-0097')))::int;
SELECT 1 / (public.normalize_identifier('orcid', 'ORCID: 0000-0002-1825-0097') = '0000-0002-1825-0097')::int;
SELECT 1 / (public.normalize_identifier('orcid', 'orcid.org/0000-0002-1825-0097') = '0000-0002-1825-0097')::int;
SELECT 1 / (public.normalize_identifier('orcid', '000000021825009x') = '0000-0002-1825-009X')::int;
SELECT 1 / (NOT public.identifier_checksum_ok('orcid', '0000-0002-1825-0098'))::int;
SELECT 1 / (count(*) = 3)::int FROM public.relation_types WHERE code IN ('edition_of', 'retroversion_of', 'transmitted_in');

ROLLBACK;
