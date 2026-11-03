-- Deploy libroyal:manuscript_description to pg
-- requires: catalogue_links
-- Vocabulary needed to describe manuscripts as their catalogues do:
--   * language 'und' (ISO 639-2: undetermined), for a text whose language has
--     not been established ('zxx', no linguistic content, would claim asemic
--     writing)
--   * script 'Qaaa' (ISO 15924 private-use range Qaaa–Qabx) for the script of
--     the Rohonc Codex, a distinct script without an ISO code ('Zzzz' would
--     only say "uncoded")
--   * statement types for ISBD area 5 beyond the extent: dimensions, other
--     physical details (material, illustration), recorded as the catalogue
--     words them
--   * identifier status 'former' (a superseded shelfmark, still found in older
--     literature)

BEGIN;

INSERT INTO public.languages (code, label_en, label_hu) VALUES
    ('und', 'undetermined', 'meghatározatlan');

INSERT INTO public.scripts (code, label_en, label_hu) VALUES
    ('Qaaa', 'Rohonc script (ISO 15924 private use)', 'rohonci írás (ISO 15924 magánhasználatú kód)');

INSERT INTO public.statement_types (code, label_en, label_hu) VALUES
    ('dimensions',       'dimensions (ISBD 5.3)',              'méret'),
    ('physical_details', 'other physical details (ISBD 5.2)', 'egyéb fizikai jellemzők');

INSERT INTO public.identifier_statuses (code, label_en, label_hu, note) VALUES
    ('former', 'former', 'korábbi', 'superseded by a later value, still found in older literature');

COMMIT;
