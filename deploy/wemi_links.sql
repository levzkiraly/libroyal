-- Deploy libroyal:wemi_links to pg
-- requires: agents
-- The links between entities: typed relations (LRM R18–R29 and extensions),
-- contributions of agents (R5, R6, R10, R11), the agents named in transcribed
-- manifestation statements together with the name form printed there, and
-- identifiers (LRM 5.4: identifiers are nomens).

BEGIN;

-- Relation types needed by critical editions of transmitted texts (e.g. a
-- modern edition of a patristic work: critical text, retroversion, fragments).
INSERT INTO public.relation_types (code, label_en, inverse_label_en, lrm_id, parent, domain_kind, range_kind, note) VALUES
    ('edition_of',      'is critical edition of', 'has critical edition', 'LRM-R24', 'derivation_of',  'expression', 'expression',
     'from the text established by an editor to the transmitted expression it edits'),
    ('retroversion_of', 'is retroversion of',     'has retroversion',     'LRM-R24', 'translation_of', 'expression', 'expression',
     'translation back into the (lost) original language, from the version it is made from'),
    ('transmitted_in',  'is transmitted in',      'transmits',            NULL,      NULL,             'expression', 'expression',
     'extension: an expression (or part of it) survives as quotation in another expression; passages go in locator');

-- ---------------------------------------------------------------------------
-- Relations between res. The relation type fixes the kinds of both ends
-- (composite FK to relation_types). locator: volume number, series number,
-- page range, as written ("I.", "5", "50–53"); position: order among siblings.
-- Symmetric types (alternate_of) are stored once.
CREATE TABLE public.relations (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type      text NOT NULL,
    from_id   bigint NOT NULL,
    from_kind text NOT NULL,
    to_id     bigint NOT NULL,
    to_kind   text NOT NULL,
    locator   text,
    position  integer CHECK (position > 0),
    basis     text REFERENCES public.bases,
    certainty text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    note      text,
    FOREIGN KEY (type, from_kind, to_kind) REFERENCES public.relation_types (code, domain_kind, range_kind),
    FOREIGN KEY (from_id, from_kind) REFERENCES public.res (id, kind) ON DELETE CASCADE,
    FOREIGN KEY (to_id, to_kind) REFERENCES public.res (id, kind) ON DELETE CASCADE,
    UNIQUE (type, from_id, to_id),
    CHECK (from_id <> to_id)
);
CREATE INDEX idx_relations_from ON public.relations (from_id);
CREATE INDEX idx_relations_to   ON public.relations (to_id);

-- ---------------------------------------------------------------------------
-- Contributions: who did what at which level. The role fixes the level
-- (author → work, translator → expression, owner → item; composite FK to roles).
-- Name forms are not recorded here: the form printed on a manifestation is in
-- statement_agents. Publishing, printing, distribution are imprints.
CREATE TABLE public.contributions (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    res_id     bigint NOT NULL,
    res_kind   text NOT NULL,
    agent_id   bigint NOT NULL,
    agent_kind text NOT NULL DEFAULT 'agent' CHECK (agent_kind = 'agent'),
    role       text NOT NULL,
    position   integer NOT NULL DEFAULT 1 CHECK (position > 0),
    basis      text REFERENCES public.bases,
    certainty  text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    note       text,
    FOREIGN KEY (res_id, res_kind) REFERENCES public.res (id, kind) ON DELETE CASCADE,
    FOREIGN KEY (agent_id, agent_kind) REFERENCES public.res (id, kind) ON DELETE RESTRICT,
    FOREIGN KEY (role, res_kind) REFERENCES public.roles (code, res_kind),
    UNIQUE (res_id, agent_id, role),
    UNIQUE (res_id, role, position) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX idx_contributions_agent ON public.contributions (agent_id);

-- ---------------------------------------------------------------------------
-- Agents named in a transcribed statement of a manifestation (usually the
-- statement of responsibility), with the name form used there: the
-- manifestation-level counterpart of imprint_agents. Each row attests a name
-- form (LRM-E9-A6); the statement's source says where it was printed. The name
-- must belong to the row's agent (composite FKs). An agent named but not (yet)
-- identified is recorded by as_printed alone.
CREATE TABLE public.statement_agents (
    statement_id       bigint NOT NULL REFERENCES public.manifestation_statements ON DELETE CASCADE,
    position           integer NOT NULL CHECK (position > 0),
    agent_id           bigint,
    agent_kind         text NOT NULL DEFAULT 'agent' CHECK (agent_kind = 'agent'),
    person_name_id     bigint,
    collective_name_id bigint,
    as_printed         text,
    basis              text NOT NULL DEFAULT 'transcribed' REFERENCES public.bases,
    certainty          text NOT NULL DEFAULT 'certain' REFERENCES public.certainties,
    note               text,
    PRIMARY KEY (statement_id, position),
    FOREIGN KEY (agent_id, agent_kind) REFERENCES public.res (id, kind) ON DELETE RESTRICT,
    FOREIGN KEY (person_name_id, agent_id)
        REFERENCES public.person_names (id, person_id) ON DELETE SET NULL (person_name_id),
    FOREIGN KEY (collective_name_id, agent_id)
        REFERENCES public.collective_names (id, collective_id) ON DELETE SET NULL (collective_name_id),
    CHECK (agent_id IS NOT NULL OR as_printed IS NOT NULL),
    CHECK (num_nonnulls(person_name_id, collective_name_id) <= 1)
);
CREATE INDEX idx_statement_agents_agent ON public.statement_agents (agent_id);

-- ---------------------------------------------------------------------------
-- Identifiers. value: as recorded (as printed for ISBNs); normalized: computed
-- for matching and uniqueness checks. status: valid / invalid_checksum /
-- misprint / cancelled / reused / unverified. corrects: on a corrected row,
-- the erroneous row it replaces ("ISBN 963-9191-29-2 [!963-9161-60-8]",
-- MOKKA KSZ2 8.3.4). qualifier: e.g. "köt.", "fűzött", "vol. 2", "set".
-- assigned_by: the assigning agent (LRM-R14), e.g. the library of a shelfmark.

CREATE FUNCTION public.normalize_identifier(p_scheme text, p_value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN p_scheme IN ('isbn', 'issn', 'issn_l') THEN upper(regexp_replace(p_value, '[^0-9Xx]', '', 'g'))
        WHEN p_scheme = 'doi'   THEN lower(regexp_replace(btrim(p_value), '^(https?://(dx\.)?doi\.org/|doi:)', '', 'i'))
        -- full URI, shortened orcid.org/… form (ORCID display guidelines) or an informal ORCID: prefix
        -- canonical form 0000-0000-0000-000X, also from unhyphenated input
        WHEN p_scheme = 'orcid' THEN regexp_replace(
            upper(regexp_replace(regexp_replace(btrim(p_value), '^((https?://)?(www\.)?orcid\.org/|orcid:\s*)', '', 'i'), '[\s-]', '', 'g')),
            '^(.{4})(.{4})(.{4})(.{4})$', '\1-\2-\3-\4')
        WHEN p_scheme = 'wikidata' THEN upper(btrim(p_value))
        ELSE btrim(p_value) END
$$;

-- Check digit of an ISBN-10/13, ISSN or ORCID iD (ISO/IEC 7064 MOD 11-2), from the
-- normalized form; NULL if not applicable.
CREATE FUNCTION public.identifier_checksum_ok(p_scheme text, p_normalized text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    s int := 0;
    d int;
    i int;
BEGIN
    IF p_scheme = 'isbn' AND p_normalized ~ '^[0-9]{9}[0-9X]$' THEN
        FOR i IN 1..10 LOOP
            d := CASE WHEN substr(p_normalized, i, 1) = 'X' THEN 10 ELSE substr(p_normalized, i, 1)::int END;
            s := s + (11 - i) * d;
        END LOOP;
        RETURN s % 11 = 0;
    ELSIF p_scheme = 'isbn' AND p_normalized ~ '^[0-9]{13}$' THEN
        FOR i IN 1..13 LOOP
            s := s + substr(p_normalized, i, 1)::int * CASE WHEN i % 2 = 0 THEN 3 ELSE 1 END;
        END LOOP;
        RETURN s % 10 = 0;
    ELSIF p_scheme IN ('issn', 'issn_l') AND p_normalized ~ '^[0-9]{7}[0-9X]$' THEN
        FOR i IN 1..7 LOOP
            s := s + (9 - i) * substr(p_normalized, i, 1)::int;
        END LOOP;
        d := (11 - s % 11) % 11;
        RETURN substr(p_normalized, 8, 1) = CASE WHEN d = 10 THEN 'X' ELSE d::text END;
    ELSIF p_scheme = 'orcid' AND replace(p_normalized, '-', '') ~ '^[0-9]{15}[0-9X]$' THEN
        FOR i IN 1..15 LOOP
            s := (s + substr(replace(p_normalized, '-', ''), i, 1)::int) * 2;
        END LOOP;
        d := (12 - s % 11) % 11;
        RETURN right(p_normalized, 1) = CASE WHEN d = 10 THEN 'X' ELSE d::text END;
    ELSIF p_scheme IN ('isbn', 'issn', 'issn_l', 'orcid') THEN
        RETURN false;  -- wrong length or characters
    END IF;
    RETURN NULL;
END $$;

CREATE TABLE public.identifiers (
    id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    res_id           bigint NOT NULL,
    res_kind         text NOT NULL,
    scheme           text NOT NULL REFERENCES public.identifier_schemes,
    value            text NOT NULL,
    normalized       text NOT NULL GENERATED ALWAYS AS (public.normalize_identifier(scheme, value)) STORED,
    status           text NOT NULL DEFAULT 'valid' REFERENCES public.identifier_statuses,
    qualifier        text,
    assigned_by      bigint,
    assigned_by_kind text NOT NULL DEFAULT 'agent' CHECK (assigned_by_kind = 'agent'),
    corrects         bigint REFERENCES public.identifiers ON DELETE SET NULL,
    basis            text REFERENCES public.bases,
    note             text,
    FOREIGN KEY (res_id, res_kind) REFERENCES public.res (id, kind) ON DELETE CASCADE,
    FOREIGN KEY (assigned_by, assigned_by_kind) REFERENCES public.res (id, kind) ON DELETE RESTRICT,
    UNIQUE (res_id, scheme, normalized),
    CHECK (corrects <> id)
);
CREATE INDEX idx_identifiers_res ON public.identifiers (res_id);
CREATE INDEX idx_identifiers_lookup ON public.identifiers (scheme, normalized);

-- A scheme bound to a level (identifier_schemes.res_kind) only applies there:
-- an ISBN identifies a manifestation, an ISSN a serial work, ORCID an agent.
CREATE FUNCTION public.identifiers_check_kind() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE v_kind text;
BEGIN
    SELECT res_kind INTO v_kind FROM public.identifier_schemes WHERE code = NEW.scheme;
    IF v_kind IS NOT NULL AND v_kind <> NEW.res_kind THEN
        RAISE EXCEPTION 'identifier scheme % applies to %, not to %', NEW.scheme, v_kind, NEW.res_kind;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER identifiers_check_kind BEFORE INSERT OR UPDATE OF scheme, res_kind ON public.identifiers
    FOR EACH ROW EXECUTE FUNCTION public.identifiers_check_kind();

-- ---------------------------------------------------------------------------
-- Views

-- Identifiers recorded as valid whose check digit (ISBN, ISSN, ORCID) fails (to be set to
-- invalid_checksum or misprint, or corrected).
CREATE VIEW public.qa_identifier_checksums AS
SELECT i.id, i.res_id, i.scheme, i.value, i.status
  FROM public.identifiers i
 WHERE i.status = 'valid'
   AND public.identifier_checksum_ok(i.scheme, i.normalized) IS FALSE;

-- Every place where a personal or collective name form is attested: explicit
-- attestations, statements of responsibility and imprints of manifestations.
CREATE VIEW public.name_attestations AS
SELECT 'person' AS name_kind, a.name_id, 'attestation' AS via, a.res_id, a.source_text, a.locator
  FROM public.person_name_attestations a
UNION ALL
SELECT 'collective', a.name_id, 'attestation', a.res_id, a.source_text, a.locator
  FROM public.collective_name_attestations a
UNION ALL
SELECT CASE WHEN sa.person_name_id IS NOT NULL THEN 'person' ELSE 'collective' END,
       coalesce(sa.person_name_id, sa.collective_name_id), 'statement', ms.manifestation_id, NULL, ms.source
  FROM public.statement_agents sa
  JOIN public.manifestation_statements ms ON ms.id = sa.statement_id
 WHERE num_nonnulls(sa.person_name_id, sa.collective_name_id) = 1
UNION ALL
SELECT CASE WHEN ia.person_name_id IS NOT NULL THEN 'person' ELSE 'collective' END,
       coalesce(ia.person_name_id, ia.collective_name_id), 'imprint', im.manifestation_id, NULL, im.function
  FROM public.imprint_agents ia
  JOIN public.imprints im ON im.id = ia.imprint_id
 WHERE num_nonnulls(ia.person_name_id, ia.collective_name_id) = 1;

COMMIT;
