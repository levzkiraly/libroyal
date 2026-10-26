-- Deploy libroyal:vocabularies to pg
-- Controlled vocabularies (reference data). Codes are stable English identifiers;
-- labels are display text. Rows here are part of the design and live in the repo;
-- later additions go into new changes. LRM references: IFLA LRM 2017-12
-- (regulations/IFLA). Hungarian labels are left NULL where no settled term is known.
-- Hungarian LRM terms: mű, kifejezési forma, megjelenési forma, példány; ágens
-- (subclasses: személy, kollektív ágens); hely.

BEGIN;

-- Kinds of res (LRM-E1 subclasses that this database models as entities).
CREATE TABLE public.res_kinds (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text,
    lrm_id   text
);
INSERT INTO public.res_kinds (code, label_en, label_hu, lrm_id) VALUES
    ('work',          'work',          'mű',                'LRM-E2'),
    ('expression',    'expression',    'kifejezési forma',  'LRM-E3'),
    ('manifestation', 'manifestation', 'megjelenési forma', 'LRM-E4'),
    ('item',          'item',          'példány',           'LRM-E5'),
    ('agent',         'agent',         'ágens',             'LRM-E6'),
    ('place',         'place',         'hely',              'LRM-E10');

-- Languages: BCP 47 primary language subtags (ISO 639-1 where it exists, else ISO 639-3).
CREATE TABLE public.languages (
    code     text PRIMARY KEY CHECK (code ~ '^[a-z]{2,3}$'),
    label_en text NOT NULL,
    label_hu text
);
INSERT INTO public.languages (code, label_en, label_hu) VALUES
    ('hu',  'Hungarian',       'magyar'),
    ('en',  'English',         'angol'),
    ('de',  'German',          'német'),
    ('fr',  'French',          'francia'),
    ('it',  'Italian',         'olasz'),
    ('es',  'Spanish',         'spanyol'),
    ('pt',  'Portuguese',      'portugál'),
    ('nl',  'Dutch',           'holland'),
    ('sv',  'Swedish',         'svéd'),
    ('fi',  'Finnish',         'finn'),
    ('la',  'Latin',           'latin'),
    ('grc', 'Ancient Greek',   'ógörög'),
    ('el',  'Modern Greek',    'újgörög'),
    ('he',  'Hebrew',          'héber'),
    ('ar',  'Arabic',          'arab'),
    ('sa',  'Sanskrit',        'szanszkrit'),
    ('ru',  'Russian',         'orosz'),
    ('uk',  'Ukrainian',       'ukrán'),
    ('bg',  'Bulgarian',       'bolgár'),
    ('sr',  'Serbian',         'szerb'),
    ('hr',  'Croatian',        'horvát'),
    ('bs',  'Bosnian',         'bosnyák'),
    ('cnr', 'Montenegrin',     'montenegrói'),
    ('mk',  'Macedonian',      'macedón'),
    ('sq',  'Albanian',        'albán'),
    ('ro',  'Romanian',        'román'),
    ('sk',  'Slovak',          'szlovák'),
    ('cs',  'Czech',           'cseh'),
    ('pl',  'Polish',          'lengyel'),
    ('tr',  'Turkish',         'török');

-- Scripts: ISO 15924 four-letter codes.
CREATE TABLE public.scripts (
    code     text PRIMARY KEY CHECK (code ~ '^[A-Z][a-z]{3}$'),
    label_en text NOT NULL,
    label_hu text
);
INSERT INTO public.scripts (code, label_en, label_hu) VALUES
    ('Latn', 'Latin',          'latin'),
    ('Cyrl', 'Cyrillic',       'cirill'),
    ('Grek', 'Greek',          'görög'),
    ('Hebr', 'Hebrew',         'héber'),
    ('Arab', 'Arabic',         'arab'),
    ('Syrc', 'Syriac',         'szír'),
    ('Copt', 'Coptic',         'kopt'),
    ('Armn', 'Armenian',       'örmény'),
    ('Geor', 'Georgian',       'grúz'),
    ('Glag', 'Glagolitic',     'glagolita'),
    ('Deva', 'Devanagari',     'dévanágari'),
    ('Hani', 'Han',            'kínai (han)'),
    ('Hung', 'Old Hungarian',  'székely-magyar rovás');

-- Script conversion schemes (LRM-E9-A9 "script conversion"): the extensibility point
-- for transliterations. "generator" names a function/tool able to produce the
-- conversion automatically (NULL: manual only). bcp47_t: optional RFC 6497 "-t-"
-- tag, to be filled once verified against the CLDR registry.
CREATE TABLE public.conversion_schemes (
    code          text PRIMARY KEY,
    label         text NOT NULL,
    source_script text NOT NULL REFERENCES public.scripts,
    target_script text NOT NULL REFERENCES public.scripts,
    lang          text REFERENCES public.languages,
    authority     text,
    revision      text,
    url           text,
    bcp47_t       text,
    generator     text,
    note          text,
    CHECK (source_script <> target_script)
);
INSERT INTO public.conversion_schemes (code, label, source_script, target_script, lang, authority, url) VALUES
    ('ala-lc-ru', 'ALA-LC romanization: Russian',           'Cyrl', 'Latn', 'ru', 'ALA-LC Romanization Tables', 'https://www.loc.gov/catdir/cpso/roman.html'),
    ('ala-lc-uk', 'ALA-LC romanization: Ukrainian',         'Cyrl', 'Latn', 'uk', 'ALA-LC Romanization Tables', 'https://www.loc.gov/catdir/cpso/roman.html'),
    ('ala-lc-bg', 'ALA-LC romanization: Bulgarian',         'Cyrl', 'Latn', 'bg', 'ALA-LC Romanization Tables', 'https://www.loc.gov/catdir/cpso/roman.html'),
    ('ala-lc-sr', 'ALA-LC romanization: Serbian',           'Cyrl', 'Latn', 'sr', 'ALA-LC Romanization Tables', 'https://www.loc.gov/catdir/cpso/roman.html'),
    ('ala-lc-mk', 'ALA-LC romanization: Macedonian',        'Cyrl', 'Latn', 'mk', 'ALA-LC Romanization Tables', 'https://www.loc.gov/catdir/cpso/roman.html'),
    ('ala-lc-el', 'ALA-LC romanization: Greek',             'Grek', 'Latn', NULL, 'ALA-LC Romanization Tables', 'https://www.loc.gov/catdir/cpso/roman.html'),
    ('ala-lc-he', 'ALA-LC romanization: Hebrew and Yiddish','Hebr', 'Latn', 'he', 'ALA-LC Romanization Tables', 'https://www.loc.gov/catdir/cpso/roman.html');

CREATE TABLE public.work_categories (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text,
    note     text
);
INSERT INTO public.work_categories (code, label_en, label_hu, note) VALUES
    ('monograph',       'monograph',          'önálló mű',          NULL),
    ('component',       'component work',     'részdokumentum',     'article, chapter, essay, review: a work published within a host'),
    ('collection',      'aggregating work',   'gyűjteményes mű',    'the editorial plan of an anthology, collected volume or similar (LRM 5.7)'),
    ('serial',          'serial work',        'időszaki kiadvány',  'periodical; LRM 5.8 serial work'),
    ('series',          'monographic series', 'sorozat',            'aggregating work of a monographic series (LRM 5.7)'),
    ('multipart',       'multipart work',     'többrészes mű',      'a work conceived in parts (R18), e.g. a multi-volume history'),
    ('manuscript',      'manuscript text',    'kézirat',            NULL),
    ('audiovisual',     'audiovisual work',   'audiovizuális mű',   'recorded lecture, interview, broadcast'),
    ('online_resource', 'online resource',    'online forrás',      'website, online tool, dataset'),
    ('other',           'other',              'egyéb',              NULL);

CREATE TABLE public.manifestation_categories (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text,
    note     text
);
INSERT INTO public.manifestation_categories (code, label_en, label_hu, note) VALUES
    ('print',        'printed publication',      'nyomtatott kiadvány',          NULL),
    ('set',          'multi-volume set (whole)', 'többkötetes egész',            'has part the volumes (R26)'),
    ('volume',       'volume of a set',          'kötet',                        'part of a set (R26)'),
    ('serial_whole', 'serial (whole run)',       'időszaki kiadvány (egész)',    'the complete serial manifestation; has part the issues (LRM 5.8)'),
    ('issue',        'issue of a serial',        'folyóiratszám',                'aggregate manifestation (LRM 5.8)'),
    ('component',    'component as published',   'közlés a gazdadokumentumban',  'an article or chapter as printed within its host; part of the host (R26)'),
    ('offprint',     'offprint',                 'különnyomat',                  'separately issued by the publisher'),
    ('online',       'online publication',       'online kiadás',                'downloaded copies are items of this manifestation (LRM-E4)'),
    ('reproduction', 'reproduction',             'másolat',                      'scan, photocopy, facsimile; R27/R28 to its source'),
    ('bound_volume', 'bound-with volume',        'kolligátum',                   'singleton manifestation of separately issued items bound together (LRM-E4)'),
    ('manuscript',   'manuscript',               'kézirat',                      'singleton manifestation'),
    ('recording',    'recording',                'felvétel',                     'audio or video recording'),
    ('other',        'other',                    'egyéb',                        NULL);

-- Relationship types between res. Rows read "from <label_en> to"; inverse_label_en
-- reads the other way. domain_kind/range_kind are enforced through a composite FK
-- on the relations table. parent: refinement of a broader type (e.g. of LRM-R24).
CREATE TABLE public.relation_types (
    code             text PRIMARY KEY,
    label_en         text NOT NULL,
    inverse_label_en text NOT NULL,
    lrm_id           text,
    parent           text REFERENCES public.relation_types,
    domain_kind      text NOT NULL REFERENCES public.res_kinds,
    range_kind       text NOT NULL REFERENCES public.res_kinds,
    note             text,
    UNIQUE (code, domain_kind, range_kind)
);
INSERT INTO public.relation_types (code, label_en, inverse_label_en, lrm_id, parent, domain_kind, range_kind, note) VALUES
    ('work_has_part',          'has part',                    'is part of',            'LRM-R18', NULL,            'work',          'work',          'inherent part of the work (multipart novel, volume of a planned history)'),
    ('work_precedes',          'precedes',                    'succeeds',              'LRM-R19', NULL,            'work',          'work',          NULL),
    ('work_accompanies',       'accompanies',                 'is accompanied by',     'LRM-R20', NULL,            'work',          'work',          NULL),
    ('work_inspires',          'is inspiration for',          'is inspired by',        'LRM-R21', NULL,            'work',          'work',          NULL),
    ('transformation_of',      'is a transformation of',      'was transformed into',  'LRM-R22', NULL,            'work',          'work',          'from the new work to its source'),
    ('expression_has_part',    'has part',                    'is part of',            'LRM-R23', NULL,            'expression',    'expression',    NULL),
    ('derivation_of',          'is derivation of',            'has derivation',        'LRM-R24', NULL,            'expression',    'expression',    'from the derived expression to its source'),
    ('revision_of',            'is revision of',              'has revision',          'LRM-R24', 'derivation_of', 'expression',    'expression',    NULL),
    ('translation_of',         'is translation of',           'has translation',       'LRM-R24', 'derivation_of', 'expression',    'expression',    NULL),
    ('adaptation_of',          'is adaptation of',            'has adaptation',        'LRM-R24', 'derivation_of', 'expression',    'expression',    NULL),
    ('aggregated_by',          'was aggregated by',           'aggregated',            'LRM-R25', NULL,            'expression',    'expression',    'from the aggregated expression to the aggregating expression'),
    ('manifestation_has_part', 'has part',                    'is part of',            'LRM-R26', NULL,            'manifestation', 'manifestation', 'set/volume, serial/issue, host/component'),
    ('reproduction_of',        'is reproduction of',          'has reproduction',      'LRM-R27', NULL,            'manifestation', 'manifestation', 'from the reproduction to its source'),
    ('reproduction_of_item',   'is reproduction of',          'has reproduction',      'LRM-R28', NULL,            'manifestation', 'item',          'from the reproduction to the specific source item'),
    ('alternate_of',           'has alternate',               'has alternate',         'LRM-R29', NULL,            'manifestation', 'manifestation', 'symmetric'),
    ('offprint_of',            'is offprint of',              'has offprint',          NULL,      NULL,            'manifestation', 'manifestation', 'extension: from the offprint to the component as published in the host'),
    ('binds',                  'binds together',              'is bound in',           NULL,      NULL,            'manifestation', 'manifestation', 'extension: from a bound-with volume to each constituent manifestation'),
    ('in_series',              'is issued in series',         'includes in series',    NULL,      NULL,            'manifestation', 'work',          'extension: from a manifestation to the series work; the number goes in locator'),
    ('derived_from_text_in',   'is derived from the text in', 'is the source text of', NULL,      NULL,            'expression',    'manifestation', 'extension: when the source of a derivation is identified only by a manifestation');

-- Contributor roles; res_kind is the level the role attaches to (composite FK on
-- contributions). Publishing, printing and distribution are imprint functions, not roles.
CREATE TABLE public.roles (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text,
    res_kind text NOT NULL REFERENCES public.res_kinds,
    lrm_id   text,
    UNIQUE (code, res_kind)
);
INSERT INTO public.roles (code, label_en, label_hu, res_kind, lrm_id) VALUES
    ('author',       'author',       'szerző',             'work',       'LRM-R5'),
    ('compiler',     'compiler',     'összeállító',        'work',       'LRM-R5'),
    ('translator',   'translator',   'fordító',            'expression', 'LRM-R6'),
    ('editor',       'editor',       'szerkesztő',         'expression', 'LRM-R6'),
    ('reviser',      'reviser',      'átdolgozó',          'expression', 'LRM-R6'),
    ('illustrator',  'illustrator',  'illusztrátor',       'expression', 'LRM-R6'),
    ('owner',        'owner',        'tulajdonos',         'item',       'LRM-R10'),
    ('former_owner', 'former owner', 'korábbi tulajdonos', 'item',       'LRM-R10'),
    ('binder',       'binder',       'könyvkötő',          'item',       'LRM-R11'),
    ('annotator',    'annotator',    'jegyzetelő',         'item',       'LRM-R11');

-- Imprint functions (statement groups of place(s) + agent(s) on a manifestation).
-- LRM-R7 "creation broadly includes the publication process"; R8 manufacture; R9 distribution.
CREATE TABLE public.imprint_functions (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text,
    lrm_id   text
);
INSERT INTO public.imprint_functions (code, label_en, label_hu, lrm_id) VALUES
    ('publication',  'publication',  'megjelentetés', 'LRM-R7'),
    ('distribution', 'distribution', 'terjesztés',    'LRM-R9'),
    ('printing',     'printing',     'nyomtatás',     'LRM-R8'),
    ('production',   'production',   'előállítás',    'LRM-R7');

-- Identifier schemes (identifiers are Nomens: LRM 5.4). res_kind NULL: any level.
CREATE TABLE public.identifier_schemes (
    code         text PRIMARY KEY,
    label        text NOT NULL,
    res_kind     text REFERENCES public.res_kinds,
    url_template text,
    note         text
);
INSERT INTO public.identifier_schemes (code, label, res_kind, url_template, note) VALUES
    ('isbn',        'ISBN',                       'manifestation', NULL, NULL),
    ('issn',        'ISSN',                       'work',          'https://portal.issn.org/resource/ISSN/{}', 'identifies a serial work (LRM 5.8)'),
    ('issn_l',      'ISSN-L',                     'work',          'https://portal.issn.org/resource/ISSN-L/{}', NULL),
    ('doi',         'DOI',                        NULL,            'https://doi.org/{}', NULL),
    ('mokka',       'MOKKA record ID',            'manifestation', NULL, NULL),
    ('oszk',        'OSZK catalogue record ID',   'manifestation', NULL, NULL),
    ('mtmt_pub',    'MTMT publication ID',        NULL,            NULL, NULL),
    ('s2cid',       'Semantic Scholar Corpus ID', NULL,            'https://api.semanticscholar.org/CorpusID:{}', NULL),
    ('shelfmark',   'shelfmark / call number',    'item',          NULL, 'the holding library is the assigning agent'),
    ('inventory',   'inventory number',           'item',          NULL, NULL),
    ('barcode',     'barcode',                    'item',          NULL, NULL),
    ('orcid',       'ORCID',                      'agent',         'https://orcid.org/{}', NULL),
    ('mtmt_author', 'MTMT author ID',             'agent',         NULL, NULL),
    ('viaf',        'VIAF',                       'agent',         'https://viaf.org/viaf/{}', NULL),
    ('geonames',    'GeoNames ID',                'place',         'https://www.geonames.org/{}', NULL),
    ('wikidata',    'Wikidata QID',               NULL,            'https://www.wikidata.org/wiki/{}', NULL);

CREATE TABLE public.identifier_statuses (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text,
    note     text
);
INSERT INTO public.identifier_statuses (code, label_en, label_hu, note) VALUES
    ('valid',            'valid',               'érvényes',            NULL),
    ('invalid_checksum', 'invalid check digit', 'hibás ellenőrzőszám', 'detectable by computation'),
    ('misprint',         'misprinted',          'sajtóhibás',          'printed wrongly; the correct value is a separate row'),
    ('cancelled',        'cancelled',           'törölt',              NULL),
    ('reused',           'also used elsewhere', 'más kiadványon is',   'the publisher printed the same identifier on another manifestation'),
    ('unverified',       'unverified',          'ellenőrizetlen',      NULL);

CREATE TABLE public.title_types (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text,
    note     text
);
INSERT INTO public.title_types (code, label_en, label_hu, note) VALUES
    ('preferred',    'preferred title',   'egységesített cím', 'the title by which a work or expression is identified'),
    ('title_proper', 'title proper',      'főcím',             'the main title of a manifestation, from its preferred source'),
    ('parallel',     'parallel title',    'párhuzamos cím',    'the title in another language or script on the same source'),
    ('variant',      'variant title',     'változat',          'cover, spine, caption or other differing title (see source)'),
    ('corrected',    'corrected title',   'helyesbített cím',  'the correct form of a misprinted title'),
    ('translated',   'translated title',  'fordított cím',     'devised translation for citation'),
    ('abbreviated',  'abbreviated title', 'rövidített cím',    'e.g. journal abbreviation');

-- Sources of transcribed data on a manifestation.
CREATE TABLE public.sources (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text
);
INSERT INTO public.sources (code, label_en, label_hu) VALUES
    ('title_page',    'title page',                'címlap'),
    ('verso',         'title page verso',          'címlap verzója'),
    ('half_title',    'half title',                'szennycímlap'),
    ('cover',         'cover',                     'borító'),
    ('spine',         'spine',                     'gerinc'),
    ('colophon',      'colophon',                  'kolofon'),
    ('caption',       'caption',                   'fejléc'),
    ('running_title', 'running title',             'élőfej'),
    ('container',     'container',                 'tok'),
    ('label',         'label',                     'címke'),
    ('other_inside',  'elsewhere in the resource', 'a dokumentum más része'),
    ('external',      'external source',           'külső forrás'),
    ('devised',       'devised by cataloguer',     'katalogizáló által adott');

CREATE TABLE public.statement_types (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text
);
INSERT INTO public.statement_types (code, label_en, label_hu) VALUES
    ('responsibility', 'statement of responsibility', 'szerzőségi közlés'),
    ('edition',        'edition statement',           'kiadásjelzés'),
    ('series',         'series statement',            'sorozati közlés'),
    ('extent',         'extent',                      'terjedelem'),
    ('other',          'other statement',             'egyéb közlés');

CREATE TABLE public.place_name_types (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text
);
INSERT INTO public.place_name_types (code, label_en, label_hu) VALUES
    ('official',     'official name',   'hivatalos név'),
    ('exonym',       'exonym',          'exonima'),
    ('historical',   'historical name', 'történeti név'),
    ('abbreviation', 'abbreviation',    'rövidítés'),
    ('variant',      'variant',         'változat');

-- Basis of a recorded value (ISBD brackets and [!] corrections, in structured form).
CREATE TABLE public.bases (
    code     text PRIMARY KEY,
    label_en text NOT NULL,
    label_hu text,
    note     text
);
INSERT INTO public.bases (code, label_en, label_hu, note) VALUES
    ('transcribed', 'transcribed from the resource',    'a dokumentumról átírt',    NULL),
    ('corrected',   'corrected',                        'helyesbített',             'the resource states otherwise: ISBD "[!...]"'),
    ('supplied',    'supplied from an external source', 'külső forrásból pótolt',   'ISBD square brackets'),
    ('inferred',    'inferred',                         'következtetett',           NULL),
    ('devised',     'devised by the cataloguer',        'katalogizáló által adott', NULL),
    ('generated',   'generated',                        'gépileg előállított',      'e.g. a transliteration produced by a conversion scheme generator');

CREATE TABLE public.certainties (
    code      text PRIMARY KEY,
    label_en  text NOT NULL,
    label_hu  text,
    isbd_mark text
);
INSERT INTO public.certainties (code, label_en, label_hu, isbd_mark) VALUES
    ('certain',     'certain',     'biztos',         NULL),
    ('probable',    'probable',    'valószínű',      '?'),
    ('approximate', 'approximate', 'hozzávetőleges', 'ca.');

COMMIT;
