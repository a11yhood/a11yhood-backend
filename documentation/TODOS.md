# TODOs

- Add scraper enhancement: when multiple images are available, pick one that has alt text; store both image URL and alt text if present.
- Track last editor for products: persist last edited user and timestamp in products, and populate during edits.
- add new scrapers

## Testing strategy cleanup (PR #131)

See also: `documentation/TESTING.md` (to be written as part of this work).

### Performance
- ~~Batch seed inserts in `_seed_test_data()` — replace per-row loops with single bulk `insert([...])`/`upsert([...])` calls~~ ✅ done
- ~~Add `truncate_test_tables` RPC to `migrations/test_only/` — single server-side TRUNCATE replaces 18 sequential DELETEs~~ ✅ done
- ~~Use RPC in `DatabaseAdapter.cleanup()` with fallback to per-table DELETE if RPC not yet deployed~~ ✅ done
- **Apply** `migrations/test_only/20260414_add_truncate_test_tables_rpc.sql` to the test Supabase instance to activate the fast path

### Test layer visibility
- Write test-style guide at `documentation/TESTING.md` — define unit vs integration vs live, when to use real DB, `monkeypatch` vs `MagicMock` rules
- Add `pytestmark = pytest.mark.integration` to all DB-backed test files (`test_products.py`, `test_users.py`, `test_collections.py`, `test_discussions.py`, `test_security.py`, `test_ratings.py`, `test_user_requests.py`, `test_user_workflows.py`, `test_supported_sources_flow.py`, `test_discussion_blocking.py`, `test_discussion_cascade.py`, `test_product_urls.py`, `test_scrapers.py`, `test_main.py`, `test_dev_endpoints.py`, `test_goat_scraper.py`, `test_ravelry_scraper.py`)
- Add module-level `pytestmark` to `test_scrapers_integration.py` and `test_scrapers_live_api.py` (they have per-test markers but not a module-level one)

### Conftest cleanup
- Retire or scope `tests/conftest_integration.py` — it duplicates `conftest.py` with non-seeded random-UUID users; either delete it or restrict it to `test_scrapers_integration.py` only

### Auth fixture correctness
- Verify `auth_client`/`admin_client` in `conftest.py` always resolve to the fixed-ID seeded users and not on-demand role tokens; add a guard test asserting `GET /api/users/me` returns the exact seeded user identity

### Mocking consistency
- Rewrite `tests/test_startup_security.py` to use `monkeypatch.setenv` instead of `patch.dict(os.environ, ...)` blocks

### New unit tests (no DB or app required)
- `tests/test_unit_dev_auth.py` — `parse_dev_token()` in `services/auth.py`
- `tests/test_unit_normalization.py` — `normalize_to_snake_case()` and friends in `services/id_generator.py`
- `tests/test_unit_scraper_classification.py` — scraper classification/filtering pure logic
- `tests/test_unit_startup_security.py` — `has_production_indicators()` and `validate_security_configuration()` called directly, without module reloading
- `tests/test_unit_row_limit.py` — `_RowLimitedTableBuilder` with a stubbed Supabase client

### Dev endpoint coverage
- Expand `tests/test_dev_endpoints.py`: 404 outside TEST_MODE, 403 for non-admin on `/reset` and `/check-limits`, and reset/limit behavior; fix fragile `patch("routers.dev.load_settings_from_env")` gating pattern
