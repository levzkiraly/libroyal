-- Verify libroyal:research_layer on pg

BEGIN;

SELECT id, code, name, parent_id, note FROM public.projects WHERE false;
SELECT project_id, res_id, res_kind, note FROM public.project_subjects WHERE false;
SELECT project_id, res_id, res_kind, added_on, note FROM public.project_members WHERE false;
SELECT id, project_id, parent_id, label, position, note FROM public.project_sections WHERE false;
SELECT project_id, res_id, section_id FROM public.project_member_sections WHERE false;
SELECT work_id, expression_id, project_id, code, status, note FROM public.documents WHERE false;
SELECT id, citing_expression_id, citing_manifestation_id, citing_locator, citing_note, citing_note_locator,
       cited_id, cited_kind, cited_locator, position, basis, note FROM public.citations WHERE false;
SELECT id, project_id, title, body, created_at, updated_at FROM public.notes WHERE false;
SELECT id, project_id, res_id, res_kind, locator, title, body, created_at, updated_at FROM public.cards WHERE false;
SELECT 1 / (count(*) = 5)::int FROM public.document_statuses;

ROLLBACK;
