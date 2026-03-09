#!/bin/bash
# Apply SQL migrations to the configured Postgres/Supabase database.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATIONS_DIR="${ROOT_DIR}/migrations"
ENV_FILE="${ENV_FILE:-.env.test}"

if [ ! -d "$MIGRATIONS_DIR" ]; then
  echo "Error: migrations directory not found at $MIGRATIONS_DIR"
  exit 1
fi

# Load env values when available (without overriding already-exported vars).
if [ -f "$ROOT_DIR/$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ROOT_DIR/$ENV_FILE"
  set +a
fi

DB_URL="${SUPABASE_DB_URL:-${DATABASE_URL:-}}"
if [ -z "${DB_URL}" ]; then
  echo "Error: SUPABASE_DB_URL or DATABASE_URL must be set"
  echo "Tip: set ENV_FILE=.env (or .env.test) before running this script"
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "Error: psql is required but was not found in PATH"
  exit 1
fi

echo "Applying SQL migrations from: $MIGRATIONS_DIR"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  id BIGSERIAL PRIMARY KEY,
  filename TEXT NOT NULL UNIQUE,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SQL

applied_count=0
skipped_count=0

for migration_file in "$MIGRATIONS_DIR"/*.sql; do
  [ -e "$migration_file" ] || continue

  filename="$(basename "$migration_file")"
  already_applied="$(psql "$DB_URL" -Atqc "SELECT 1 FROM public.schema_migrations WHERE filename='${filename}' LIMIT 1;")"

  if [ "$already_applied" = "1" ]; then
    skipped_count=$((skipped_count + 1))
    echo "Skipping already applied migration: $filename"
    continue
  fi

  echo "Applying migration: $filename"
  psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$migration_file"
  psql "$DB_URL" -v ON_ERROR_STOP=1 -c "INSERT INTO public.schema_migrations (filename) VALUES ('${filename}');"
  applied_count=$((applied_count + 1))
done

echo "Migration complete. Applied: ${applied_count}, Skipped: ${skipped_count}"
