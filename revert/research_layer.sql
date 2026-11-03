-- Revert libroyal:research_layer from pg

BEGIN;

DROP TABLE public.cards;
DROP TABLE public.notes;
DROP FUNCTION public.touch_updated_at();
DROP TABLE public.citations;
DROP TABLE public.documents;
ALTER TABLE public.expressions DROP CONSTRAINT expressions_id_work_id_key;
DROP TABLE public.document_statuses;
DROP TABLE public.project_member_sections;
DROP TABLE public.project_sections;
DROP TABLE public.project_members;
DROP TABLE public.project_subjects;
DROP TABLE public.projects;

COMMIT;
