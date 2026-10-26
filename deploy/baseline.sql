-- Deploy libroyal:baseline to pg
-- Generated from pg_dump --schema-only of the live libroyal DB, 2026-10-21.

BEGIN;

-- Name: persons; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.persons (
    id bigint NOT NULL,
    family_name text NOT NULL,
    given_name text,
    prefix text,
    suffix text
);

-- Name: series; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.series (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    issn character varying(9)
);

-- Name: tags; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.tags (
    id bigint NOT NULL,
    name text NOT NULL
);

-- Name: work_contributors; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.work_contributors (
    work_id bigint NOT NULL,
    person_id bigint NOT NULL,
    role text NOT NULL,
    "position" integer NOT NULL,
    CONSTRAINT work_contributors_position_check CHECK (("position" > 0))
);

-- Name: work_copies; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.work_copies (
    id bigint NOT NULL,
    work_id bigint NOT NULL,
    location_type character varying(12) NOT NULL,
    mime_type character varying(255) NOT NULL,
    url text NOT NULL
);

-- Name: work_tags; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.work_tags (
    work_id bigint NOT NULL,
    tag_id bigint NOT NULL
);

-- Name: works; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.works (
    id bigint NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    subtitle text,
    year text,
    publisher text,
    place text,
    journal text,
    volume text,
    issue text,
    pages text,
    doi text,
    isbn text,
    url text,
    note text,
    series_id bigint,
    number character varying(12),
    booktitle text,
    edition text,
    CONSTRAINT works_type_lo_check CHECK ((type = ANY (ARRAY['article'::text, 'book'::text, 'booklet'::text, 'conference'::text, 'inbook'::text, 'incollection'::text, 'inproceedings'::text, 'journal'::text, 'manual'::text, 'mastersthesis'::text, 'misc'::text, 'phdthesis'::text, 'proceedings'::text, 'techreport'::text, 'unpublished'::text, 'email'::text, 'www'::text, 'custom1'::text, 'custom2'::text, 'custom3'::text, 'custom4'::text, 'custom5'::text])))
);

-- Name: persons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.persons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Name: persons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.persons_id_seq OWNED BY public.persons.id;

-- Name: series_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.series_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Name: series_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.series_id_seq OWNED BY public.series.id;

-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;

-- Name: work_copies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.work_copies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Name: work_copies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.work_copies_id_seq OWNED BY public.work_copies.id;

-- Name: works_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.works_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Name: works_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.works_id_seq OWNED BY public.works.id;

-- Name: persons id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.persons ALTER COLUMN id SET DEFAULT nextval('public.persons_id_seq'::regclass);

-- Name: series id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.series ALTER COLUMN id SET DEFAULT nextval('public.series_id_seq'::regclass);

-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);

-- Name: work_copies id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.work_copies ALTER COLUMN id SET DEFAULT nextval('public.work_copies_id_seq'::regclass);

-- Name: works id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.works ALTER COLUMN id SET DEFAULT nextval('public.works_id_seq'::regclass);

-- Name: persons persons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_pkey PRIMARY KEY (id);

-- Name: series series_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.series
    ADD CONSTRAINT series_pkey PRIMARY KEY (id);

-- Name: tags tags_name_key; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_name_key UNIQUE (name);

-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);

-- Name: work_contributors work_contributors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.work_contributors
    ADD CONSTRAINT work_contributors_pkey PRIMARY KEY (work_id, person_id, role);

-- Name: work_contributors work_contributors_unique_position; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.work_contributors
    ADD CONSTRAINT work_contributors_unique_position UNIQUE (work_id, role, "position");

-- Name: work_copies work_copies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.work_copies
    ADD CONSTRAINT work_copies_pkey PRIMARY KEY (id);

-- Name: work_tags work_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.work_tags
    ADD CONSTRAINT work_tags_pkey PRIMARY KEY (work_id, tag_id);

-- Name: works works_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.works
    ADD CONSTRAINT works_pkey PRIMARY KEY (id);

-- Name: idx_persons_family_name; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_persons_family_name ON public.persons USING btree (family_name);

-- Name: idx_tags_name; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_tags_name ON public.tags USING btree (name);

-- Name: idx_work_contributors_person; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_work_contributors_person ON public.work_contributors USING btree (person_id);

-- Name: idx_work_contributors_work_role; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_work_contributors_work_role ON public.work_contributors USING btree (work_id, role);

-- Name: idx_works_type; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_works_type ON public.works USING btree (type);

-- Name: idx_works_year; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_works_year ON public.works USING btree (year);

-- Name: work_contributors work_contributors_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.work_contributors
    ADD CONSTRAINT work_contributors_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.persons(id) ON DELETE RESTRICT;

-- Name: work_contributors work_contributors_work_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.work_contributors
    ADD CONSTRAINT work_contributors_work_id_fkey FOREIGN KEY (work_id) REFERENCES public.works(id) ON DELETE CASCADE;

-- Name: work_copies work_copies_work_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.work_copies
    ADD CONSTRAINT work_copies_work_id_fkey FOREIGN KEY (work_id) REFERENCES public.works(id) ON DELETE CASCADE;

-- Name: work_tags work_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.work_tags
    ADD CONSTRAINT work_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;

-- Name: work_tags work_tags_work_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.work_tags
    ADD CONSTRAINT work_tags_work_id_fkey FOREIGN KEY (work_id) REFERENCES public.works(id) ON DELETE CASCADE;

-- Name: works works_series_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.works
    ADD CONSTRAINT works_series_id_fkey FOREIGN KEY (series_id) REFERENCES public.series(id) ON DELETE SET NULL;


--
--

COMMIT;
