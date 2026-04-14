#!/usr/bin/env bash
set -euo pipefail

DB_CONTAINER="a11yhood-export-verify-pg"
PUBLIC_DB_NAME="a11yhood_restore_public"
PRIVATE_DB_NAME="a11yhood_restore_private"

SCHEMA_FILE="supabase-schema.sql"
PUBLIC_EXPORT="supabase/public-products.sql"
PRIVATE_EXPORT="supabase/full-database.sql"

cleanup() {
  docker rm -f "$DB_CONTAINER" >/dev/null 2>&1 || true
}

run_psql() {
  local db_name="$1"
  shift
  docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d "$db_name" "$@"
}

trap cleanup EXIT

if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "Missing schema file: $SCHEMA_FILE"
  exit 1
fi

if [[ ! -f "$PUBLIC_EXPORT" ]]; then
  echo "Missing export file: $PUBLIC_EXPORT"
  exit 1
fi

if [[ ! -f "$PRIVATE_EXPORT" ]]; then
  echo "Missing export file: $PRIVATE_EXPORT"
  exit 1
fi

echo "Starting local Postgres container..."
cleanup
docker run --name "$DB_CONTAINER" \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=postgres \
  -d postgres:16 >/dev/null

for _ in {1..30}; do
  if docker exec "$DB_CONTAINER" pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "Creating verification databases..."
docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d postgres <<SQL >/dev/null
DROP DATABASE IF EXISTS ${PUBLIC_DB_NAME};
DROP DATABASE IF EXISTS ${PRIVATE_DB_NAME};
CREATE DATABASE ${PUBLIC_DB_NAME};
CREATE DATABASE ${PRIVATE_DB_NAME};
SQL

echo "Loading baseline Supabase compatibility objects..."
for db_name in "$PUBLIC_DB_NAME" "$PRIVATE_DB_NAME"; do
  run_psql "$db_name" <<'SQL' >/dev/null
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role;
  END IF;
END
$$;

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS storage;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULL::uuid;
$$;

CREATE OR REPLACE FUNCTION auth.role()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT 'service_role'::text;
$$;

CREATE TABLE IF NOT EXISTS storage.buckets (
  id text PRIMARY KEY,
  name text,
  public boolean DEFAULT false
);

CREATE TABLE IF NOT EXISTS storage.objects (
  id uuid,
  bucket_id text,
  name text,
  owner uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
SQL

  echo "Applying schema to ${db_name}..."
  docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d "$db_name" < "$SCHEMA_FILE" >/dev/null
done

echo "Applying public export..."
docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d "$PUBLIC_DB_NAME" < "$PUBLIC_EXPORT" >/dev/null

echo "Checking public restore integrity..."
run_psql "$PUBLIC_DB_NAME" <<'SQL'
DO $$
DECLARE
  leaked_rows integer;
BEGIN
  SELECT COUNT(*) INTO leaked_rows FROM users;
  IF leaked_rows <> 0 THEN
    RAISE EXCEPTION 'public restore leaked users rows: %', leaked_rows;
  END IF;

  SELECT COUNT(*) INTO leaked_rows FROM product_editors;
  IF leaked_rows <> 0 THEN
    RAISE EXCEPTION 'public restore leaked product_editors rows: %', leaked_rows;
  END IF;

  SELECT COUNT(*) INTO leaked_rows FROM blog_posts;
  IF leaked_rows <> 0 THEN
    RAISE EXCEPTION 'public restore leaked blog_posts rows: %', leaked_rows;
  END IF;

  SELECT COUNT(*) INTO leaked_rows FROM user_activities;
  IF leaked_rows <> 0 THEN
    RAISE EXCEPTION 'public restore leaked user_activities rows: %', leaked_rows;
  END IF;

  SELECT COUNT(*) INTO leaked_rows FROM user_requests;
  IF leaked_rows <> 0 THEN
    RAISE EXCEPTION 'public restore leaked user_requests rows: %', leaked_rows;
  END IF;

  SELECT COUNT(*) INTO leaked_rows FROM collections;
  IF leaked_rows <> 0 THEN
    RAISE EXCEPTION 'public restore leaked collections rows: %', leaked_rows;
  END IF;

  SELECT COUNT(*) INTO leaked_rows FROM discussions;
  IF leaked_rows <> 0 THEN
    RAISE EXCEPTION 'public restore leaked discussions rows: %', leaked_rows;
  END IF;

  SELECT COUNT(*) INTO leaked_rows FROM oauth_configs;
  IF leaked_rows <> 0 THEN
    RAISE EXCEPTION 'public restore leaked oauth_configs rows: %', leaked_rows;
  END IF;

  SELECT COUNT(*) INTO leaked_rows FROM scraping_logs;
  IF leaked_rows <> 0 THEN
    RAISE EXCEPTION 'public restore leaked scraping_logs rows: %', leaked_rows;
  END IF;
END
$$;

SELECT
  (SELECT COUNT(*) FROM valid_categories) AS valid_categories,
  (SELECT COUNT(*) FROM supported_sources) AS supported_sources,
  (SELECT COUNT(*) FROM tags) AS tags,
  (SELECT COUNT(*) FROM products) AS products,
  (SELECT COUNT(*) FROM product_urls) AS product_urls,
  (SELECT COUNT(*) FROM product_tags) AS product_tags;
SQL

echo "Extracting valid scraping_logs sources from export..."
VALID_SOURCES=$(grep "INSERT INTO scraping_logs" "$PRIVATE_EXPORT" | cut -d"'" -f6 | sort -u | sed "s/^/'/;s/$/'/" | paste -sd, -)

if [[ -n "$VALID_SOURCES" ]]; then
  echo "Updating scraping_logs source constraint with live values: $VALID_SOURCES"
  run_psql "$PRIVATE_DB_NAME" <<SQL >/dev/null
ALTER TABLE scraping_logs DROP CONSTRAINT IF EXISTS scraping_logs_source_check;
ALTER TABLE scraping_logs ADD CONSTRAINT scraping_logs_source_check 
  CHECK (source IN ($VALID_SOURCES));
SQL
fi

echo "Applying private export..."
docker exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U postgres -d "$PRIVATE_DB_NAME" < "$PRIVATE_EXPORT" >/dev/null

echo "Checking private restore integrity..."
run_psql "$PRIVATE_DB_NAME" <<'SQL'
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM product_editors pe
    LEFT JOIN products p ON p.id = pe.product_id
    WHERE p.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned product_editors.product_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM product_editors pe
    LEFT JOIN users u ON u.id = pe.user_id
    WHERE u.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned product_editors.user_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM product_urls pu
    LEFT JOIN products p ON p.id = pu.product_id
    WHERE p.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned product_urls.product_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM product_urls pu
    LEFT JOIN users u ON u.id = pu.created_by
    WHERE u.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned product_urls.created_by rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM product_tags pt
    LEFT JOIN products p ON p.id = pt.product_id
    WHERE p.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned product_tags.product_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM product_tags pt
    LEFT JOIN tags t ON t.id = pt.tag_id
    WHERE t.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned product_tags.tag_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM ratings r
    LEFT JOIN products p ON p.id = r.product_id
    WHERE p.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned ratings.product_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM ratings r
    LEFT JOIN users u ON u.id = r.user_id
    WHERE u.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned ratings.user_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM discussions d
    LEFT JOIN products p ON p.id = d.product_id
    WHERE p.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned discussions.product_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM discussions d
    LEFT JOIN users u ON u.id = d.user_id
    WHERE u.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned discussions.user_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM discussions d
    LEFT JOIN users u ON u.id = d.blocked_by
    WHERE d.blocked_by IS NOT NULL AND u.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned discussions.blocked_by rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM blog_posts bp
    LEFT JOIN users u ON u.id = bp.author_id
    WHERE u.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned blog_posts.author_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM collections c
    LEFT JOIN users u ON u.id = c.user_id
    WHERE u.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned collections.user_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM user_activities ua
    LEFT JOIN users u ON u.id = ua.user_id
    WHERE u.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned user_activities.user_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM user_activities ua
    LEFT JOIN products p ON p.id = ua.product_id
    WHERE ua.product_id IS NOT NULL AND p.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned user_activities.product_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM user_requests ur
    LEFT JOIN users u ON u.id = ur.user_id
    WHERE u.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned user_requests.user_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM user_requests ur
    LEFT JOIN products p ON p.id = ur.product_id
    WHERE ur.product_id IS NOT NULL AND p.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned user_requests.product_id rows found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM user_requests ur
    LEFT JOIN users u ON u.id = ur.reviewed_by
    WHERE ur.reviewed_by IS NOT NULL AND u.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned user_requests.reviewed_by rows found';
  END IF;

  IF to_regclass('public.collection_products') IS NOT NULL AND EXISTS (
    SELECT 1 FROM collection_products cp
    LEFT JOIN collections c ON c.id = cp.collection_id
    WHERE c.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned collection_products.collection_id rows found';
  END IF;

  IF to_regclass('public.collection_products') IS NOT NULL AND EXISTS (
    SELECT 1 FROM collection_products cp
    LEFT JOIN products p ON p.id = cp.product_id
    WHERE p.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned collection_products.product_id rows found';
  END IF;
END
$$;

SELECT
  (SELECT COUNT(*) FROM users) AS users,
  (SELECT COUNT(*) FROM products) AS products,
  (SELECT COUNT(*) FROM product_tags) AS product_tags,
  (SELECT COUNT(*) FROM ratings) AS ratings,
  (SELECT COUNT(*) FROM collections) AS collections,
  (SELECT COUNT(*) FROM user_activities) AS user_activities,
  (SELECT COUNT(*) FROM user_requests) AS user_requests,
  (SELECT COUNT(*) FROM scraping_logs) AS scraping_logs;
SQL

echo "Restore verification completed successfully."
