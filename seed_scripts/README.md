# Seed Scripts

Seed scripts populate the database with initial data for development and testing. All scripts are designed to be idempotent (safe to run multiple times).

## Quick Start

### Development (SQLite with Docker)

If the dev server is running in Docker (started with `./start-dev.sh`), the easiest way to seed is:

```bash
cd /path/to/a11yhood-backend
./scripts/seed.sh
```

This automatically detects the running container and seeds the database inside it.

Alternatively, seed with a flag:
```bash
./scripts/seed.sh --in-docker
```

### Start Dev Server with Seeding

You can also seed automatically when starting the dev server:

```bash
./start-dev.sh --seed
```

This will start the server and then seed all data in one command.

### Development (Direct Python - No Docker)

If you're running Python directly (not in Docker):

```bash
ENV_FILE=.env.test .venv/bin/python seed_scripts/seed_all.py
```

Or use the helper script:
```bash
./scripts/seed.sh --help  # Shows all options
```

## Individual Scripts

### Database Setup Scripts

#### `seed_supported_sources.py`
Adds supported product sources to the `supported_sources` table.

```bash
.venv/bin/python -c "import sys; sys.path.insert(0, '.'); from seed_scripts.seed_supported_sources import seed_supported_sources; seed_supported_sources()"
```

**Adds:**
- ravelry.com
- github.com
- thingiverse.com
- abledata.com
- example.com (for testing)

---

#### `seed_oauth_configs.py`
Populates OAuth configurations for scraper platforms.

```bash
.venv/bin/python -c "import sys; sys.path.insert(0, '.'); from seed_scripts.seed_oauth_configs import seed_oauth_configs; seed_oauth_configs()"
```

**Adds placeholder configurations for:**
- Ravelry
- Thingiverse
- GitHub

In development, these use placeholder credentials. For production, OAuth configs should be set via the admin UI or environment variables.

---

#### `seed_scraper_search_terms.py`
Seeds search terms used by scrapers to find relevant products.

```bash
.venv/bin/python -c "import sys; sys.path.insert(0, '.'); from seed_scripts.seed_scraper_search_terms import main; main()"
```

**Configures search terms for:**
- GitHub (assistive technology keywords)
- Thingiverse (accessibility keywords)
- Ravelry (category-specific keywords)

---

### Test Data Scripts

#### `seed_test_users.py`
Creates test user accounts with different roles.

```bash
.venv/bin/python -c "import sys; sys.path.insert(0, '.'); from seed_scripts.seed_test_users import seed_users; seed_users()"
```

**Creates three test users:**
| Role | Username | Email | GitHub ID |
|------|----------|-------|-----------|
| admin | admin_user | admin@example.com | admin-test-001 |
| moderator | moderator_user | moderator@example.com | mod-test-002 |
| user | regular_user | user@example.com | user-test-003 |

User IDs are fixed so roles remain stable across test resets.

---

#### `seed_test_product.py`
Creates a sample product with tags for testing.

```bash
.venv/bin/python -c "import sys; sys.path.insert(0, '.'); from seed_scripts.seed_test_product import seed_product; seed_product()"
```

**Creates:**
- Product: "Test Product" (slug: `test-product`)
- Tags: "accessibility", "testing"

---

#### `seed_test_collections.py`
Creates sample collections for testing collection features.

```bash
.venv/bin/python -c "import sys; sys.path.insert(0, '.'); from seed_scripts.seed_test_collections import seed_collections; seed_collections()"
```

**Creates:**
1. Public collection by admin user: "Accessible Software Tools"
2. Private collection by regular user: "My Personal Collection"
3. Empty public collection by admin user: "Empty Collection"

---

### Production Scripts

#### `seed_librarything_config.py`
**⚠️ Requires Supabase (production mode only)**

Configures the LibraryThing API key for GOAT (book scraping).

```bash
# Option 1: Pass API key as argument
.venv/bin/python seed_scripts/seed_librarything_config.py --key YOUR_LIBRARYTHING_API_KEY

# Option 2: Use environment variable
export LIBRARYTHING_API_KEY=your-key
.venv/bin/python seed_scripts/seed_librarything_config.py --from-env
```

Get your API key from: https://www.librarything.com/services/keys.php

---

## Environment Configuration

### Development (SQLite - `.env.test`)
```bash
DATABASE_URL=sqlite+aiosqlite:////tmp/a11yhood-test.db
TEST_MODE=true
```

### Docker vs Host Filesystem

**Important:** When running the dev server in Docker, the container has its own isolated filesystem. The SQLite database at `/tmp/a11yhood-test.db` **inside the container** is different from the one on your host machine.

**Solution:** Always seed using `./scripts/seed.sh` or `./start-dev.sh --seed`, which handle the Docker container correctly.

**Don't do this:**
```bash
# ❌ Wrong - seeds host's database, not container's
.venv/bin/python seed_scripts/seed_all.py
curl http://localhost:8000/api/supported-sources  # Still empty!
```

**Do this instead:**
```bash
# ✅ Correct - seeds container's database
./scripts/seed.sh
curl http://localhost:8000/api/supported-sources  # Has data!
```

### Production (Supabase - `.env`)
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key
```

## Troubleshooting

### Import Errors

If you see `ModuleNotFoundError: No module named 'database_adapter'`:
- Ensure you're running from the project root directory
- The scripts add the parent directory to `sys.path` automatically
- Use the provided commands which handle this correctly

### Database Not Found

If you see database file not found errors:
- Ensure `.env.test` exists in the project root
- The test database path is configured in `.env.test`: `DATABASE_URL=sqlite+aiosqlite:////tmp/a11yhood-test.db`
- The `/tmp` directory should be writable on your system

### Supabase Connection Errors

For `seed_librarything_config.py`:
- Ensure you're in production mode (not test mode)
- Set `SUPABASE_URL` and `SUPABASE_KEY` in your environment
- The script won't work with SQLite test database

## Running in Tests

Tests automatically seed the database as needed via fixtures in `tests/conftest.py`. Individual seed scripts can be called directly:

```python
# In test code
from seed_scripts.seed_test_users import seed_users
seed_users()
```

## Best Practices

1. **Idempotency**: All scripts check for existing data before inserting. Safe to run multiple times.
2. **Isolation**: Each script is independent. Run `seed_all.py` for everything or individual scripts as needed.
3. **Order Matters**: Run `seed_supported_sources` before other scripts that reference sources.
4. **Clean Resets**: For test SQLite database, clean and restart:
   ```bash
   rm /tmp/a11yhood-test.db
   .venv/bin/python seed_scripts/seed_all.py
   ```

## Adding New Seed Scripts

1. Create a new file in `seed_scripts/`: `seed_something.py`
2. Implement a `main()` or named function
3. Use `DatabaseAdapter` for database access (works with both SQLite and Supabase)
4. Add to `seed_all.py` if it's a core initialization script
5. Document in this README

Example template:
```python
"""
Seed description.

Run with: uv run python seed_scripts/seed_something.py
"""
from config import get_settings
from database_adapter import DatabaseAdapter

def main():
    settings = get_settings()
    db = DatabaseAdapter(settings)
    db.init()
    
    # Your seeding logic here
    db.table("your_table").insert({"data": "value"}).execute()
    print("✓ Done")

if __name__ == "__main__":
    main()
```

## See Also

- [DATABASE_SETUP.md](../documentation/DOCKER_SETUP.md) - Database initialization
- [ENVIRONMENT_MODES.md](../documentation/ENVIRONMENT_MODES.md) - Development vs production
- [LOCAL_TESTING.md](../documentation/LOCAL_TESTING.md) - Running tests locally
