#!/bin/bash
# Regenerate schema.sql: a readable, diffable snapshot of the deployed structure.
# Run after every `sqitch deploy`, and commit it together with the change.
# Connection: libpq environment (PGHOST, PGUSER, PGPASSWORD, …); defaults below.
# The `sqitch` registry schema and the per-run \restrict tokens / version
# headers of pg_dump are excluded, so the file only changes when the schema does.
set -euo pipefail
cd "$(dirname "$0")/.."
pg_dump -h "${PGHOST:-localhost}" -U "${PGUSER:-postgres}" \
        --schema-only --no-owner --no-privileges --exclude-schema=sqitch \
        "${PGDATABASE:-libroyal}" \
  | grep -v -E '^\\(un)?restrict |^-- Dumped (from|by) ' > schema.sql
echo "schema.sql: $(grep -c '^CREATE' schema.sql) CREATE statements"
