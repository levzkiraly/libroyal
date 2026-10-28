# libroyal

Schema of the `libroyal` bibliography database (PostgreSQL 16), managed with
[Sqitch](https://sqitch.org/). This repository holds **structure only**:
tables, views, constraints, and — later — the reference vocabularies the
structure depends on (types, roles, identifier schemes). Catalogue data lives
in database backups, never here.

## Layout

| Path | Content |
|---|---|
| `sqitch.plan` | Ordered list of changes and tags — the source of truth |
| `sqitch.conf` | Engine and default target (`db:pg://postgres@localhost/libroyal`) |
| `deploy/<change>.sql` | Applies a change |
| `revert/<change>.sql` | Undoes exactly that change |
| `verify/<change>.sql` | Fails if the change is not in place (read-only, rolled back) |
| `schema.sql` | Generated snapshot of the deployed structure, for reading and diffing |
| `tools/snapshot.sh` | Regenerates `schema.sql` |

## Changes so far

| Change | Content |
|---|---|
| `baseline` | The structure as it existed before Sqitch (2026-10-21): `works`, `work_contributors`, `persons`, `series`, `tags`, `work_tags`, `work_copies` |
| `lo_bibliography` | The view LibreOffice reads through `libroyal.odb`; its column list is a contract (see `verify/lo_bibliography.sql`) |
| `@baseline` | Tag marking the pre-Sqitch starting point |
| `legacy_rename` | Old tables (and their constraints, indexes, sequences) renamed to `legacy_*`; `lo_bibliography` keeps reading them |
| `vocabularies` | Controlled vocabularies with seed rows: res kinds, languages, scripts, conversion schemes (ALA-LC), categories, relation types (LRM R18–R29 + extensions), roles, imprint functions, identifier schemes and statuses, title types, sources, statement types, place-name types, basis, certainty |
| `wemi_core` | `res` supertable; works, expressions, manifestations, items; titles, manifestation statements, imprints (with places and agents); QA views |
| `agents` | Agents (ágens): persons (személy) and collective agents (kollektív ágens); structured personal names (MOKKA KSZ4), collective names; name types, name cultures, the KSZ4 2.1.2.3 particle table, generational markers |
| `places` | Places with time-bound names in any language and script |
| `name_rendering` | KSZ4 heading, natural display form per output language and Hungarian-collated sort columns of personal names (`person_names_rendered`); particle QA view |
| `wemi_links` | Typed relations between entities; contributions (role fixes the level); agents named in manifestation statements with the printed name form; identifiers with normalization, status, corrections and check-digit QA; `name_attestations` view |
| `catalogue_links` | Identifier schemes for catalogue records (OSZK NEKTÁR and MOKKA-ODR permalinks, LCCN, DNB, Arcanum); `checked_on_success` / `checked_on_error` on identifiers |
| `legacy_mapping` | Correspondence tables for carrying the pre-LRM entries into the four-level model (`legacy_map`, `legacy_person_map`, `legacy_migration_res`); `other_format_of`, the work-to-work relation of print and online serials; the legacy tables stay |
| `citation_names` | `person_names.citation_name`: the name used in labels when it differs from the entry element |
| `lo_bibliography` (reworked) | The LibreOffice view over the four-level model, scoped to the migrated entries (interim project view); labels computed: names (up to four, else "First et al."), year, suffix only within the view, ordered by title with multipart works as blocks |

A second target, `dev` (`libroyal_dev`), is configured for trying changes before they
reach the live database: `sqitch deploy --verify dev`.

The live database was registered with `sqitch deploy --log-only`: the baseline
scripts were recorded as deployed without being run against it.

**Data stays out of the plan.** Migrating or correcting catalogue data is not a
change here: such scripts are kept with the backups (`.backup/seed/`, not tracked)
and run once with `psql -v ON_ERROR_STOP=1 -f <script>` after the structure they
need is deployed.

## Password

Never stored in this repo or in `sqitch.conf`. Sqitch reads it from the
`SQITCH_PASSWORD` environment variable, `tools/snapshot.sh` from `PGPASSWORD`;
set either at the point of use from your secret store, e.g.
`SQITCH_PASSWORD="$(<lookup command>)" sqitch status`.

## Workflow for a change

1. Work on a copy: `createdb -h localhost -U postgres -T libroyal libroyal_dev`
2. `sqitch add <change> --requires <dep> -n "<what and why>"`, then write its
   deploy / revert / verify scripts.
3. Iterate on the copy: `sqitch deploy db:pg://postgres@localhost/libroyal_dev`,
   `sqitch revert … --to @HEAD^`, edit, redeploy. Until a change is deployed to
   the live database its scripts may still be edited freely.
4. Back up the live database (`pg_dump -Fc`), then `sqitch deploy --verify`.
5. `tools/snapshot.sh`, and commit plan, scripts and `schema.sql` together.
6. Drop the copy: `dropdb -h localhost -U postgres libroyal_dev`.

**Views:** once deployed, change `lo_bibliography` with
`sqitch rework lo_bibliography` (done once, after `legacy_mapping`; the revert of a
reworked view must account for tables renamed since the previous version), which keeps the previous version under the
last tag and lets the view's history read as a sequence of `CREATE OR REPLACE`
edits. This requires a tag after the last deployment of the view.

## Catalogue validation

`tools/catalogue/catalogue.py` looks entries up in reference catalogues and writes
a field-by-field comparison report; it never changes the database.

| source | access | format |
|---|---|---|
| `oszk` | OSZK NEKTÁR, Z39.50 `tagetes2.oszk.hu:1616/ANY` | HUNMARC |
| `mokka` | MOKKA, Z39.50 `z3950.mokka.hu:2210` | MARC21 export |
| `loc` | Library of Congress, SRU `lx2.loc.gov:210/LCDB` | MARC21 |
| `dnb` | Deutsche Nationalbibliothek, SRU `services.dnb.de/sru/dnb` (paced; answers 429 when too fast) | MARC21 |
| `doi` | doi.org content negotiation (Crossref, DataCite) | CSL-JSON |
| `arcanum` | Arcanum ADT public search, no account; only with `--arcanum`, one request per entry, 10 s apart | citation line, docId, page |

Requires `yaz` (`zoomsh`) for Z39.50; otherwise only the Python standard library.
Searches go by identifier first (DOI, ISBN); on no hit, by title + author, then title +
year (part records of multi-part works often lack the author). Leading articles are
dropped from title searches, as the catalogues' title indexes ignore them. Journals and
series are looked up as serials for their ISSN. A part record reachable only through
its set record (e.g. OSZK) still has to be found by hand.

```bash
PGPASSWORD=… tools/catalogue/catalogue.py legacy [--id N …]   # reports in validation/
tools/catalogue/catalogue.py lookup --isbn 9789639971677 --source oszk mokka
tools/catalogue/catalogue.py legacy --id 24 --arcanum                # include Arcanum
```

Reports (`validation/<id>.md`, `validation/index.md`) and the raw records
(`validation/raw/`) are evidence for decisions, not data; `validation/` is not
tracked by git.
