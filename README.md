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

A second target, `dev` (`libroyal_dev`), is configured for trying changes before they
reach the live database: `sqitch deploy --verify dev`.

The live database was registered with `sqitch deploy --log-only`: the baseline
scripts were recorded as deployed without being run against it.

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
`sqitch rework lo_bibliography`, which keeps the previous version under the
last tag and lets the view's history read as a sequence of `CREATE OR REPLACE`
edits. This requires a tag after the last deployment of the view.
