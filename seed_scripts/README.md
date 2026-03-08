# Seed Scripts

Seed scripts populate the Supabase database with initial data for development and testing.
All scripts are idempotent (safe to run multiple times) and use the `DatabaseAdapter` API.

## Environment

Set `ENV_FILE` to choose which Supabase project to seed:

- `ENV_FILE=.env.test` (default) → `a11yhood-test` database in the `make4all-test` org
- `ENV_FILE=.env`                → production Supabase project

## Quick Start

```bash
# Seed everything (uses .env.test by default)
uv run python seed_scripts/seed_all.py

# Seed against a specific env
ENV_FILE=.env uv run python seed_scripts/seed_all.py
```

Or run the helper script (handles Docker if needed):
```bash
./scripts/seed.sh
```

## Individual Scripts

### `seed_supported_sources.py`
Adds supported product sources to the `supported_sources` table.

```bash
uv run python seed_scripts/seed_supported_sources.py
```

Adds: ravelry.com, github.com, thingiverse.com, example.com

---

### `seed_oauth_configs.py`
Populates OAuth configurations for scraper platforms.

```bash
uv run python seed_scripts/seed_oauth_configs.py
```

Reads credentials from env vars (e.g. `RAVELRY_APP_KEY`), falls back to placeholders.

---

### `seed_scraper_search_terms.py`
Seeds search terms used by scrapers.

```bash
uv run python seed_scripts/seed_scraper_search_terms.py
```

Configures: GitHub, Thingiverse, Ravelry category keywords.

---

### `seed_test_users.py`
Creates three test users with fixed IDs (matches `DEV_USER_IDS` in `services/auth.py`).

```bash
uv run python seed_scripts/seed_test_users.py
```

| Role | Username | Email | ID |
|------|----------|-------|----|
| admin | admin_user | admin@example.com | 49366adb-... |
| moderator | moderator_user | moderator@example.com | 94e116f7-... |
| user | regular_user | user@example.com | 2a3b7c3e-... |

---

### `seed_test_product.py`
Creates a sample product with tags.

```bash
uv run python seed_scripts/seed_test_product.py
```

Creates: "Test Product" (slug: `test-product`) with tags "accessibility" and "testing".

---

### `seed_test_collections.py`
Creates sample collections for testing.

```bash
uv run python seed_scripts/seed_test_collections.py
```

Creates: two public collections and one private collection.

---

## Adding New Seed Scripts

Use this template:

```python
"""
Seed description.

Run with: uv run python seed_scripts/seed_something.py
"""
import os
import sys

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

from dotenv import load_dotenv
env_file = os.getenv("ENV_FILE", ".env.test")
load_dotenv(env_file, override=True)

from config import get_settings
from database_adapter import DatabaseAdapter

def main():
    settings = get_settings(env_file)
    db = DatabaseAdapter(settings)
    db.table("your_table").upsert({"data": "value"}, on_conflict="unique_col").execute()
    print("✓ Done")

if __name__ == "__main__":
    main()
```

1. Add the new script to `seed_all.py`.
2. Document it here.

## See Also

- [LOCAL_TESTING.md](../documentation/LOCAL_TESTING.md) - Running tests locally
- [ENVIRONMENT_MODES.md](../documentation/ENVIRONMENT_MODES.md) - Dev vs production configuration
