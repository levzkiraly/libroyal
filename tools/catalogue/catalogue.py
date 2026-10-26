#!/usr/bin/env python3
"""Look up bibliographic entries in reference catalogues and report, field by
field, how the catalogue records compare with our data.

Sources
  oszk   OSZK NEKTÁR, Z39.50 tagetes2.oszk.hu:1616/ANY (HUNMARC)
  mokka  MOKKA, Z39.50 z3950.mokka.hu:2210 (MARC21 export)
  loc    Library of Congress, SRU lx2.loc.gov:210/LCDB (MARC21)
  dnb    Deutsche Nationalbibliothek, SRU services.dnb.de/sru/dnb (MARC21)
  doi    doi.org content negotiation (CSL-JSON; Crossref and DataCite DOIs)
  arcanum  Arcanum ADT public search (no account), only on explicit request
           (--arcanum): one search per entry, slow pace; for articles and
           Hungarian / Romanian periodicals not found in library catalogues

Z39.50 goes through yaz's zoomsh; everything else is the Python standard
library. Nothing is written to the database: the output is a report per entry
(Markdown) plus the raw records, for a human to decide what to accept.

Usage
  catalogue.py legacy [--id N ...] [--arcanum] [--out DIR]   check legacy_works rows
  catalogue.py lookup (--isbn X | --issn X | --lccn X | --doi X |
                       --title T [--author A] [--year Y]) [--source S ...]
  catalogue.py lookup --arcanum "phrase"
Database access (legacy) uses psql with the libpq environment (PGHOST, PGUSER,
PGPASSWORD, PGDATABASE; defaults localhost / postgres / libroyal).
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

MARC_NS = '{http://www.loc.gov/MARC21/slim}'
USER_AGENT = 'libroyal-catalogue/0.1 (bibliographic validation)'
PAUSE = 1.0  # seconds between requests to the same service

# ---------------------------------------------------------------------------
# Fetching

def clean_term(s):
    """Search terms without quotation marks, brackets and ISBD punctuation, which
    make OSZK title searches fail (e.g. A „Magyar Codexek” …)."""
    s = re.sub(r'[„”“"«»‹›\'’‘()\[\]{}:;/=!?–—]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def pqf_term(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def zoom(target, syntax, pqf, limit=5):
    """Run a Z39.50 search with zoomsh; return (hits, [MARCXML strings])."""
    cmd = ['zoomsh', f'connect {target}', f'set preferredRecordSyntax {syntax}',
           f'find {pqf}', f'show 0 {limit} xml', 'quit']
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=90).stdout
    except subprocess.TimeoutExpired:
        return None, []
    m = re.search(r': (\d+) hits', out)
    hits = int(m.group(1)) if m else 0
    recs = re.findall(r'<record xmlns="http://www.loc.gov/MARC21/slim">.*?</record>', out, re.S)
    return hits, recs


def http_get(url, accept=None):
    req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT, **({'Accept': accept} if accept else {})})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode('utf-8')


def loc_sru(cql, limit=5):
    url = 'http://lx2.loc.gov:210/LCDB?' + urllib.parse.urlencode({
        'operation': 'searchRetrieve', 'version': '1.1', 'query': cql,
        'maximumRecords': str(limit), 'recordSchema': 'marcxml'})
    root = ET.fromstring(http_get(url))
    n = root.find('{http://www.loc.gov/zing/srw/}numberOfRecords')
    recs = [ET.tostring(r, encoding='unicode') for r in root.iter(MARC_NS + 'record')]
    return (int(n.text) if n is not None else 0), recs


def doi_csl(doi):
    try:
        return json.loads(http_get('https://doi.org/' + urllib.parse.quote(doi, safe='/'),
                                   accept='application/vnd.citationstyles.csl+json'))
    except Exception as e:  # noqa: BLE001 — reported, not fatal
        return {'error': str(e)}


def dnb_sru(cql, limit=5):
    """DNB SRU. DNB answers 429 when requests come too fast: one retry after
    a pause, then give up for this query (reported, not fatal)."""
    url = 'https://services.dnb.de/sru/dnb?' + urllib.parse.urlencode({
        'operation': 'searchRetrieve', 'version': '1.1', 'query': cql,
        'maximumRecords': str(limit), 'recordSchema': 'MARC21-xml'})
    for attempt in (1, 2):
        try:
            text = http_get(url)
            break
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt == 1:
                time.sleep(15)
                continue
            raise
    root = ET.fromstring(text)
    n = root.find('{http://www.loc.gov/zing/srw/}numberOfRecords')
    recs = [ET.tostring(r, encoding='unicode') for r in root.iter(MARC_NS + 'record')]
    return (int(n.text) if n is not None else 0), recs


SOURCES = {
    'oszk':  dict(kind='z3950', target='tagetes2.oszk.hu:1616/ANY', syntax='usmarc', flavor='hunmarc'),
    'mokka': dict(kind='z3950', target='z3950.mokka.hu:2210',       syntax='usmarc', flavor='marc21'),
    'loc':   dict(kind='sru',   flavor='marc21', fetch=loc_sru,
                  cql={'isbn': 'bath.isbn', 'issn': 'bath.issn', 'lccn': 'bath.lccn', 'title': 'dc.title',
                       'author': 'dc.creator', 'year': 'dc.date'}),
    'dnb':   dict(kind='sru',   flavor='marc21', fetch=dnb_sru,
                  cql={'isbn': 'num', 'issn': 'num', 'title': 'tit', 'author': 'per', 'year': 'jhr'}),
}
PAUSES = {'dnb': 3.0, 'arcanum': 10.0}
# Bib-1 use attributes (OSZK and MOKKA documentation)
USE = {'isbn': 7, 'issn': 8, 'title': 4, 'author': 1003, 'year': 31}


def search(source, limit=5, **q):
    """q: isbn / issn / lccn / title [+ author, year]. Returns (query text, hits, records)."""
    s = SOURCES[source]
    q = {k: (clean_term(str(v)) if k in ('title', 'author') else v) for k, v in q.items()}
    if q.get('title'):  # the title indexes (OSZK, LoC, DNB) ignore leading articles
        q['title'] = re.sub(r"^(the|an?|az?|der|die|das|le|la|les|l'|il|lo|el)\s+", '', q['title'], flags=re.I)
    keys = [k for k in ('isbn', 'issn', 'lccn', 'title', 'author', 'year') if q.get(k)]
    if s['kind'] == 'z3950':
        keys = [k for k in keys if k in USE]
        if not keys:
            return None, 0, []
        terms = [f'@attr 1={USE[k]} {pqf_term(str(q[k]))}' for k in keys]
        pqf = terms[0]
        for t in terms[1:]:
            pqf = f'@and {pqf} {t}'
        hits, recs = zoom(s['target'], s['syntax'], pqf, limit)
        return pqf, hits, recs
    keys = [k for k in keys if k in s['cql']]
    if not keys:
        return None, 0, []
    cql = ' and '.join(f'{s["cql"][k]}="{q[k]}"' for k in keys)
    try:
        hits, recs = s['fetch'](cql, limit)
    except Exception as e:  # noqa: BLE001
        return cql + f'  [error: {e}]', None, []
    return cql, hits, recs

BROWSER_UA = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36'


def arcanum_search(phrase, per_page=5):
    """Arcanum ADT public search (no account). The site rejects non-browser
    user agents. Returns a list of {doc_id, pg, volume, place, cite, url}."""
    import base64
    lst = base64.urlsafe_b64encode(json.dumps({'query': f'SZO=({clean_term(phrase)})'}).encode()).decode().rstrip('=')
    url = f'https://adt.arcanum.com/hu/search/results/?list={lst}&per_page={per_page}&page=1&format=list'
    req = urllib.request.Request(url, headers={'User-Agent': BROWSER_UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        page = r.read().decode('utf-8')
    import html as html_mod
    clean = lambda s: html_mod.unescape(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', '', s))).strip()
    out = []
    for li in re.findall(r'<li class="list-group-item[^"]*result.*?</li>', page, re.S):
        href = re.search(r'href="/hu/view/([^/?"]+)/\?[^"]*?pg=(\d+)"', li)
        vol = re.search(r'<h5>.*?<a [^>]*>(.*?)</a>', li, re.S)
        place = re.search(r'bi-geo-alt-fill"></span>(.*?)</p>', li, re.S)
        cite = re.search(r'class="pdfbkmk"[^>]*>\s*<strong>(.*?)</strong>', li, re.S)
        if href:
            out.append({'doc_id': href.group(1), 'pg': int(href.group(2)),
                        'volume': clean(vol.group(1)) if vol else '', 'place': clean(place.group(1)) if place else '',
                        'cite': clean(cite.group(1)) if cite else '',
                        'url': f'https://adt.arcanum.com/hu/view/{href.group(1)}/?pg={href.group(2)}'})
    return out

# ---------------------------------------------------------------------------
# MARC → comparison fields

def datafields(rec, tag):
    return [d for d in rec.findall(MARC_NS + 'datafield') if d.get('tag') == tag]


def subs(df, code):
    return [s.text or '' for s in df.findall(MARC_NS + 'subfield') if s.get('code') == code]


def control(rec, tag):
    for c in rec.findall(MARC_NS + 'controlfield'):
        if c.get('tag') == tag:
            return c.text or ''
    return ''


def strip_isbd(s):
    """Drop the ISBD punctuation MARC21 keeps at subfield ends (' :', ' /', ',', '.')."""
    s = re.sub(r'\s+', ' ', s or '').strip()
    s = re.sub(r'\s*[:;/,=]$', '', s).strip()
    # a final period is ISBD punctuation, except after an abbreviation (p., ill., kiad.)
    if s.endswith('.') and not re.search(r'(^|[\s(])\w{1,5}\.$', s):
        s = s[:-1].rstrip()
    return s


def first(lst):
    return lst[0] if lst else ''


def name_of(df, flavor):
    a = strip_isbd(first(subs(df, 'a')))
    j = strip_isbd(first(subs(df, 'j'))) if flavor == 'hunmarc' else ''
    d = strip_isbd(first(subs(df, 'd')))
    if re.fullmatch(r'\(?[0-9?.\- ]+\)?', d):
        d = f" ({d.strip('()')})"
    elif d:  # not a date: keep as found (MOKKA exports sometimes put the given name here)
        d = f' [$d {d}]'
    return (f'{a}, {j}' if j else a) + d


def extract(xml, flavor):
    rec = ET.fromstring(xml)
    f = {'record_id': control(rec, '001'), 'leader_type': rec.findtext(MARC_NS + 'leader', '')[6:8]}
    t245 = datafields(rec, '245')
    t = t245[0] if t245 else None
    if t is not None:
        f['title'] = strip_isbd(' '.join(subs(t, 'a')))
        f['subtitle'] = strip_isbd(' '.join(subs(t, 'b')))
        f['part'] = strip_isbd(' '.join(subs(t, 'n') + subs(t, 'p')))
        f['responsibility'] = strip_isbd(' '.join(subs(t, 'c')))
    f['edition'] = strip_isbd(' '.join(sum((subs(d, 'a') for d in datafields(rec, '250')), [])))
    imp = datafields(rec, '264') or datafields(rec, '260')
    f['places'] = [strip_isbd(x) for d in imp for x in subs(d, 'a')]
    f['publishers'] = [strip_isbd(x) for d in imp for x in subs(d, 'b')]
    f['date'] = strip_isbd(' '.join(x for d in imp for x in subs(d, 'c')))
    f['year'] = first(re.findall(r'1[5-9]\d\d|20\d\d', f['date'])) or control(rec, '008')[7:11].strip()
    f['extent'] = ' ; '.join(' : '.join(strip_isbd(x) for x in subs(d, 'a') + subs(d, 'b') if strip_isbd(x))
                             for d in datafields(rec, '300'))
    f['series'] = [strip_isbd(first(subs(d, 'a'))) + (f' ; {strip_isbd(first(subs(d, "v")))}' if subs(d, 'v') else '')
                   for tag in ('490', '440', '830') for d in datafields(rec, tag)]
    f['isbn'] = [strip_isbd(first(subs(d, 'a'))) + ''.join(f' ({strip_isbd(q).strip("()")})' for q in subs(d, 'q') + subs(d, 'j'))
                 for d in datafields(rec, '020') if subs(d, 'a')]
    f['issn'] = [strip_isbd(first(subs(d, 'a'))) for d in datafields(rec, '022') if subs(d, 'a')]
    f['lccn'] = [strip_isbd(first(subs(d, 'a'))) for d in datafields(rec, '010') if subs(d, 'a')]
    f['other_ids'] = [strip_isbd(first(subs(d, 'a'))) for d in datafields(rec, '035') if subs(d, 'a')]
    f['names'] = [name_of(d, flavor) for tag in ('100', '110', '700', '710') for d in datafields(rec, tag)]
    lang = first(sum((subs(d, 'a') for d in datafields(rec, '041')), [])) or control(rec, '008')[35:38]
    f['language'] = lang.strip()
    f['host'] = [strip_isbd(' '.join(subs(d, 't') + subs(d, 'g'))) for d in datafields(rec, '773')]
    f['shelfmarks'] = [strip_isbd(first(subs(d, 'm') or subs(d, 'h'))) + (f' [{first(subs(d, "a"))}]' if subs(d, 'a') else '')
                       for d in datafields(rec, '852') if subs(d, 'm') or subs(d, 'h')]
    f['source_agency'] = ' '.join(strip_isbd(x) for d in datafields(rec, '040') for x in subs(d, 'a') + subs(d, 'd'))
    return f


def from_csl(c):
    if 'error' in c:
        return {'error': c['error']}
    issued = (c.get('issued') or {}).get('date-parts') or [[None]]
    return {
        'record_id': c.get('DOI', ''), 'title': c.get('title', ''), 'subtitle': ' '.join(c.get('subtitle') or []),
        'names': [', '.join(x for x in (a.get('family'), a.get('given')) if x) or a.get('literal', '')
                  for a in c.get('author', [])],
        'year': str(issued[0][0] or ''), 'container': c.get('container-title', ''),
        'volume': c.get('volume', ''), 'issue': c.get('issue', ''), 'pages': c.get('page', ''),
        'publishers': [c['publisher']] if c.get('publisher') else [], 'issn': c.get('ISSN', []),
        'isbn': c.get('ISBN', []), 'type': c.get('type', ''), 'version': c.get('version', ''),
    }

# ---------------------------------------------------------------------------
# Comparison

def norm(s):
    s = unicodedata.normalize('NFKC', s or '').casefold()
    s = re.sub(r'[„”“"\'’‘«»()\[\].,:;!?/–—-]+', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def digits(s):
    return re.sub(r'[^0-9x]', '', (s or '').lower())


def compare(ours, theirs):
    """ours, theirs: plain strings. Status: same / differs / only catalogue / only ours / —."""
    if not ours and not theirs:
        return '—'
    if not ours:
        return 'only catalogue'
    if not theirs:
        return 'only ours'
    a, b = norm(ours), norm(theirs)
    if a == b:
        return 'same'
    if a in b or b in a:
        return 'partial'
    return 'differs'


def compare_field(field, ours, theirs):
    if field in ('ISBN', 'ISSN') and ours and theirs:
        theirs_d = {digits(x.split(' (')[0]) for x in theirs.split(' | ')}
        return 'same' if digits(ours) in theirs_d else 'differs'
    if field == 'authors':
        strip_dates = lambda s: re.sub(r'\s*\([^)]*\)', '', s or '')
        return compare(strip_dates(ours), strip_dates(theirs))
    return compare(ours, theirs)


def score(row, f):
    s = 0
    if row.get('isbn') and any(digits(row['isbn']) == digits(i.split(' (')[0]) or
                               digits(row['isbn'])[-10:-1] == digits(i.split(' (')[0])[-10:-1] for i in f.get('isbn', [])):
        s += 4
    if row.get('year') and row['year'] == f.get('year'):
        s += 1
    if compare(row.get('title'), f.get('title')) in ('same', 'partial'):
        s += 2
    if row.get('authors') and any(norm(a.split(',')[0]) in norm(' '.join(f.get('names', []))) for a in row['authors']):
        s += 1
    # parts of a multi-part work share the title: the part designation decides
    if row.get('subtitle'):
        rec_text = norm(' '.join(f.get(k) or '' for k in ('title', 'subtitle', 'part')))
        years = re.findall(r'1[0-9]{3}', row['subtitle'])
        if norm(row['subtitle']) in rec_text or (years and all(y in rec_text for y in years)):
            s += 3
    return s


def rows_for(row, f):
    """(field, ours, catalogue) triples for the report."""
    pub = ' ; '.join(f.get('publishers', []))
    out = [
        ('title', row.get('title'), f.get('title')),
        ('subtitle', row.get('subtitle'), f.get('subtitle')),
        ('authors', ' ; '.join(row.get('authors') or []), ' ; '.join(f.get('names', []))),
        ('year', row.get('year'), f.get('year')),
    ]
    if 'container' in f:  # DOI / CSL record
        out += [('journal', row.get('journal'), f.get('container')), ('volume', row.get('volume'), f.get('volume')),
                ('issue', row.get('issue'), f.get('issue')), ('pages', row.get('pages'), f.get('pages')),
                ('publisher', row.get('publisher'), pub)]
    else:
        out += [('place', row.get('place'), ' ; '.join(f.get('places', []))), ('publisher', row.get('publisher'), pub),
                ('edition', row.get('edition'), f.get('edition')), ('extent / pages', row.get('pages'), f.get('extent')),
                ('series', ' ; '.join(x for x in (row.get('series'), row.get('number')) if x), ' | '.join(f.get('series', [])))]
    out += [('ISBN', row.get('isbn'), ' | '.join(f.get('isbn', []))), ('ISSN', row.get('series_issn'), ' | '.join(f.get('issn', [])))]
    return out

# ---------------------------------------------------------------------------
# Legacy rows

LEGACY_SQL = """
SELECT coalesce(json_agg(r ORDER BY r.id), '[]') FROM (
  SELECT w.id, w.type, w.title, w.subtitle, w.year, w.publisher, w.place, w.journal, w.volume,
         w.issue, w.pages, w.doi, w.isbn, w.url, w.edition, w.booktitle, w.number,
         s.name AS series, s.issn AS series_issn,
         (SELECT json_agg(p.family_name || coalesce(', ' || p.given_name, '') ORDER BY c.position)
            FROM legacy_work_contributors c JOIN legacy_persons p ON p.id = c.person_id
           WHERE c.work_id = w.id AND c.role = 'author') AS authors,
         (SELECT json_agg(p.family_name ORDER BY c.position)
            FROM legacy_work_contributors c JOIN legacy_persons p ON p.id = c.person_id
           WHERE c.work_id = w.id AND c.role IN ('author', 'editor')) AS family_names
    FROM legacy_works w LEFT JOIN legacy_series s ON s.id = w.series_id) r
"""


def load_legacy():
    env = {**os.environ}
    args = ['psql', '-XAt', '-h', env.get('PGHOST', 'localhost'), '-U', env.get('PGUSER', 'postgres'),
            '-d', env.get('PGDATABASE', 'libroyal'), '-c', LEGACY_SQL]
    return json.loads(subprocess.run(args, capture_output=True, text=True, check=True, env=env).stdout)


def plan(row):
    """Which searches to run for a legacy row: list of (source, query dict)."""
    p = []
    fam = (row.get('family_names') or [''])[0]
    main_title = re.split(r'\s+Vol\.\s', row['title'])[0]
    if row.get('doi'):
        p.append(('doi', {'doi': re.sub(r'^doi:\s*', '', row['doi'], flags=re.I)}))
    if row.get('isbn'):
        p += [(s, {'isbn': row['isbn'], '_fallback': {'title': main_title, 'author': fam}})
              for s in ('oszk', 'mokka', 'loc', 'dnb')]
    elif row['type'] in ('book', 'misc'):
        # parts of multi-part works often lack the author in the part record:
        # on no hit, retry with title + year
        p += [(s, {'title': main_title, 'author': fam,
                   '_fallback': {'title': main_title, 'year': row.get('year')} if row.get('year') else None})
              for s in ('oszk', 'mokka', 'loc', 'dnb')]
    elif row['type'] == 'incollection' and row.get('booktitle'):
        host = re.split(r'\s*:\s*', row['booktitle'])[0]
        p += [(s, {'title': host}) for s in ('oszk', 'mokka', 'loc', 'dnb')]
    if row['type'] == 'article' and not row.get('doi'):
        p += [(s, {'title': main_title, 'author': fam}) for s in ('oszk', 'mokka')]
    if row['type'] == 'article' and row.get('journal'):
        jt = re.sub(r'\s*\(.*?\)\s*$', '', row['journal'])
        p += [(s, {'title': jt, '_serial': True}) for s in ('oszk', 'mokka')]
    if row.get('series'):
        p += [(s, {'title': row['series'], '_serial': True}) for s in ('oszk', 'mokka')]
    return p

# ---------------------------------------------------------------------------
# Report

def md_cell(s):
    return (s or '').replace('|', '\\|').replace('\n', ' ')


def run_entry(row, outdir, rawdir, use_arcanum=False):
    key = f"{row['id']:03d}"
    lines = [f"# Legacy {row['id']}: {', '.join(row.get('family_names') or ['?'])} {row.get('year') or ''} — {row['title']}", '']
    summary = []
    last = {}
    for source, q in plan(row):
        serial = q.pop('_serial', False)
        fallback = q.pop('_fallback', None)
        pause = PAUSES.get(source, PAUSE)
        if time.time() - last.get(source, 0) < pause:
            time.sleep(pause - (time.time() - last.get(source, 0)))
        if source == 'doi':
            c = doi_csl(q['doi'])
            last[source] = time.time()
            f = from_csl(c)
            (rawdir / f'{key}_doi.json').write_text(json.dumps(c, ensure_ascii=False, indent=1), encoding='utf-8')
            lines += [f"## doi.org — `{q['doi']}`", '']
            if 'error' in f:
                lines += [f"Error: {f['error']}", '']
                summary.append(f'doi: error')
                continue
            cands = [f]
        else:
            query, hits, recs = search(source, limit=20 if serial else 10, **q)
            last[source] = time.time()
            lines += [f"## {source} — `{query}` — {hits if hits is not None else 'error'} hit(s)", '']
            if not recs and fallback:
                time.sleep(PAUSE)
                query, hits, recs = search(source, **fallback)
                last[source] = time.time()
                lines += [f"No hit; fallback `{query}` — {hits if hits is not None else 'error'} hit(s)", '']
            cands = []
            for n, x in enumerate(recs):
                (rawdir / f'{key}_{source}_{n}.xml').write_text(x, encoding='utf-8')
                cands.append(extract(x, SOURCES[source]['flavor']))
            if serial:
                want = norm(q.get('title'))
                cands = [c for c in cands if c.get('leader_type', '')[1:2] == 's']
                cands.sort(key=lambda c: norm(c.get('title')) != want)
                lines.append(f"{len(cands)} serial record(s) among the first {len(recs)} fetched:")
                for c in cands[:5]:
                    lines.append(f"- {c.get('title')} {c.get('subtitle') or ''} — ISSN {', '.join(c.get('issn')) or '—'} — "
                                 f"{c.get('date') or ''} — record {c.get('record_id')} (leader {c.get('leader_type')})")
                lines.append('')
                exact = [c for c in cands if norm(c.get('title')) == want]
                summary.append(f"{source} serial: " + (', '.join(f"`{c.get('record_id')}` ISSN {'/'.join(c.get('issn')) or '—'}"
                                                              for c in exact[:2]) or f'{len(cands)} candidate(s), no exact title'))
                continue
            if not cands:
                summary.append(f'{source}: 0')
                continue
            cands.sort(key=lambda c: -score(row, c))
        for n, f in enumerate(cands):
            lines += [f"### candidate {n + 1}: record `{f.get('record_id')}` (score {score(row, f)})", '',
                      '| field | ours | catalogue | status |', '|---|---|---|---|']
            diffs = 0
            for field, ours, theirs in rows_for(row, f):
                st = compare_field(field, ours, theirs)
                diffs += st in ('differs', 'only catalogue', 'partial')
                lines.append(f'| {field} | {md_cell(ours)} | {md_cell(theirs)} | {st} |')
            extra = [(k, f.get(k)) for k in ('responsibility', 'part', 'language', 'lccn', 'other_ids', 'host',
                                             'shelfmarks', 'source_agency', 'type', 'version') if f.get(k)]
            for k, v in extra:
                lines.append(f"| *{k}* | | {md_cell(' | '.join(v) if isinstance(v, list) else v)} | |")
            lines.append('')
            if n == 0:
                summary.append(f"{source}: best `{f.get('record_id')}` score {score(row, f)}, {diffs} to check")
    if use_arcanum and row['type'] in ('article', 'incollection', 'book'):
        phrase = ' '.join(re.split(r'\s+', clean_term(row['title']))[:8])
        lines += [f"## arcanum — `SZO=({phrase})` (public search)", '']
        try:
            hits = arcanum_search(phrase)
        except Exception as e:  # noqa: BLE001
            hits = None
            lines += [f'Error: {e}', '']
            summary.append('arcanum: error')
        if hits is not None:
            for h in hits:
                lines.append(f"- [{h['volume']}]({h['url']}) — {h['place']} — {h['cite']} — `{h['doc_id']}` pg {h['pg']}")
            lines.append('')
            summary.append(f"arcanum: {len(hits)} hit(s)" + (f" — `{hits[0]['doc_id']}`" if hits else ''))
    (outdir / f"{key}.md").write_text('\n'.join(lines), encoding='utf-8')
    return summary


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    lg = sub.add_parser('legacy')
    lg.add_argument('--id', type=int, nargs='*')
    lg.add_argument('--arcanum', action='store_true', help='also search Arcanum ADT (one request per entry, slow)')
    lg.add_argument('--out', default=str(Path(__file__).resolve().parents[2] / 'validation'))
    lk = sub.add_parser('lookup')
    for k in ('isbn', 'issn', 'lccn', 'doi', 'title', 'author', 'year'):
        lk.add_argument('--' + k)
    lk.add_argument('--source', nargs='*', default=['oszk', 'mokka', 'loc', 'dnb'])
    lk.add_argument('--arcanum', metavar='PHRASE')
    a = ap.parse_args()

    if a.cmd == 'lookup':
        if a.arcanum:
            print(json.dumps(arcanum_search(a.arcanum), ensure_ascii=False, indent=1))
            return
        if a.doi:
            print(json.dumps(from_csl(doi_csl(a.doi)), ensure_ascii=False, indent=1))
            return
        q = {k: getattr(a, k) for k in ('isbn', 'issn', 'lccn', 'title', 'author', 'year') if getattr(a, k)}
        for s in a.source:
            query, hits, recs = search(s, **q)
            print(f'== {s}: {query} — {hits} hit(s)')
            for x in recs:
                print(json.dumps(extract(x, SOURCES[s]['flavor']), ensure_ascii=False, indent=1))
        return

    out = Path(a.out)
    raw = out / 'raw'
    raw.mkdir(parents=True, exist_ok=True)
    rows = [r for r in load_legacy() if not a.id or r['id'] in a.id]
    index = ['# Validation of legacy entries', '', '| id | entry | results |', '|---|---|---|']
    for r in rows:
        print(f"legacy {r['id']}: {r['title'][:60]}", file=sys.stderr)
        summ = run_entry(r, out, raw, a.arcanum)
        index.append(f"| [{r['id']}]({r['id']:03d}.md) | {md_cell(', '.join(r.get('family_names') or []))} "
                     f"{r.get('year') or ''} | {md_cell('<br>'.join(summ))} |")
    (out / 'index.md').write_text('\n'.join(index) + '\n', encoding='utf-8')
    print(f'report: {out / "index.md"}', file=sys.stderr)


if __name__ == '__main__':
    main()
