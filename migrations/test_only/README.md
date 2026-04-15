# Test-Only Manual SQL Overrides

These SQL files are **manual prerequisites** for test environments.

They are intentionally **not** part of the normal migration chain and are **not** auto-applied by scripts.

## When to run

Run these in Supabase SQL Editor after creating/resetting a test database if Data API access fails with errors like:

- `permission denied for schema public` (code `42501`)

## How to run

1. Open Supabase dashboard for the test project.
2. Go to SQL Editor.
3. Copy and run SQL from the file(s) in this folder, in filename order.

Current files:

- `20260308_service_role_public_schema_grants.sql`
- `20260414_add_truncate_test_tables_rpc.sql` — creates the `truncate_test_tables()` RPC used by `DatabaseAdapter.cleanup()` for fast single-round-trip test teardown

## Notes

- These are test-only operational fixes, not production schema migrations.
- Keep SQL idempotent (`GRANT` statements are safe to rerun).
