# Dev Mode Features & API

## Overview

Dev mode enables safe local development with:
- **Role-based test user creation** via X-Dev-Role header
- **Database row limits** (20 rows max per table by default)
- **Disabled scheduled scrapers** (test scrapers limited to 5 products)
- **Database reset endpoint** for cleanup
- **Dev statistics/monitoring** endpoints

Enabled when `TEST_MODE=true` in `.env.test`.

---

## Authentication: X-Dev-Role Header

### Quick Start

Instead of hardcoding user UUIDs, the frontend sends an `X-Dev-Role` header to test different roles:

```bash
# Test as admin
curl -H "X-Dev-Role: admin" http://localhost:8002/api/users/me

# Test as moderator
curl -H "X-Dev-Role: moderator" http://localhost:8002/api/products

# Test as regular user
curl -H "X-Dev-Role: user" http://localhost:8002/api/products
```

### Backend Behavior

When dev mode receives `X-Dev-Role`:
1. **Validates** the role (must be: `admin`, `moderator`, `manager`, or `user`)
2. **Checks** if test user exists with that role (username: `dev_<role>`)
3. **Creates** test user on-demand if not found
4. **Returns** user with that role for rest of request

### Frontend Implementation Example

```javascript
// JavaScript - pass X-Dev-Role header instead of hardcoding user ID
async function callApi(role = "user") {
  const response = await fetch("http://localhost:8002/api/products", {
    headers: {
      "X-Dev-Role": role,  // Let backend create/fetch test user for this role
    },
  });
  return response.json();
}

// Test different roles easily
await callApi("admin");      // Admin features
await callApi("moderator");  // Moderator features
await callApi("user");       // Regular user features
```

### Valid Roles

| Role | Use Case |
|------|----------|
| `admin` | Full access, can create scrapers, approve ratings, manage users |
| `moderator` | Can flag content, resolve disputes |
| `manager` | Can manage collections/categories |
| `user` | Regular user, can rate/review products |

---

## Database Row Limits

**Automatic enforcement** of 20 rows per table in dev mode prevents accidental mass-inserts from filling your test database.

### Configuration

```python
# config.py
DEV_MODE_MAX_ROWS_PER_TABLE: int = 20
```

### Limits Apply To

- `products` (main table)
- `users`
- `ratings`
- `discussions`
- `collections`
- `scraping_logs`
- `oauth_configs`

### When You Hit the Limit

1. Remove old test data manually
2. Use the reset endpoint (see below)
3. Query to verify counts: `GET /api/dev/stats`

---

## Disabled Scrapers

### Production Behavior
- GitHub: Daily at 2:00 AM UTC
- Thingiverse: Daily at 2:30 AM UTC
- Ravelry: Daily at 3:00 AM UTC

### Dev Behavior
- **All scheduled scrapers disabled**
- Test scrapers limited to 5 products per run
- Can still trigger scraper manually via API:
  ```bash
  POST /api/scrapers/github/search \
    -H "Authorization: Bearer $DEV_TOKEN" \
    -d '{"term": "accessible"}'
  ```

### Configuration

```python
# config.py
DEV_MODE_DISABLE_SCHEDULED_SCRAPERS: bool = True  # Disable night-time jobs
TEST_SCRAPER_LIMIT: int = 5                        # Max products per manual run
```

---

## Dev-Only API Endpoints

### GET `/api/dev/stats` (Admin Only)

View current dev configuration and table row counts.

```bash
curl -H "X-Dev-Role: admin" http://localhost:8002/api/dev/stats
```

Response:
```json
{
  "mode": "dev",
  "max_rows_per_table": 20,
  "scrapers_disabled": true,
  "test_scraper_limit": 5,
  "tables": {
    "products": {"rows": 15, "at_limit": false},
    "users": {"rows": 4, "at_limit": false},
    "ratings": {"rows": 8, "at_limit": false},
    ...
  }
}
```

### POST `/api/dev/reset` (Admin Only)

⚠️ **Dangerous**: Clears ALL data from user tables.

```bash
curl -X POST -H "X-Dev-Role: admin" http://localhost:8002/api/dev/reset
```

Response:
```json
{
  "status": "reset",
  "cleared_tables": {
    "products": 15,
    "users": 4,
    "ratings": 8,
    ...
  },
  "total_rows_deleted": 125
}
```

After reset:
1. Database is empty
2. Reseed with test data if needed: `pixi run dev-seed`

### GET `/api/dev/check-limits` (Admin Only)

Check if any table exceeds row limit.

```bash
curl -H "X-Dev-Role: admin" http://localhost:8002/api/dev/check-limits
```

Returns **200** if all within limits, **400** if any table exceeds:
```json
{
  "detail": "Dev row limits exceeded (max 20):\n  - products: 45/20\n  - ratings: 32/20"
}
```

### GET `/api/dev/health-dev` (No Auth Required)

Confirm dev endpoints are available.

```bash
curl http://localhost:8002/api/dev/health-dev
```

Response:
```json
{
  "status": "healthy",
  "mode": "dev",
  "message": "Dev mode active - endpoints available"
}
```

---

## Security

### Production
- X-Dev-Role header **ignored**
- Dev endpoints **not mounted** (404)
- All schedulers **enabled**
- Row limits **inactive**

### Dev Mode
- X-Dev-Role header **creates test users on demand**
- Dev endpoints **require admin role**
- Schedulers **disabled** (reduce API load)
- Row limits **enforced** (prevent test data bloat)

**Security:** Dev test users (username: `dev_*`) are only created in TEST_MODE.  
In production, they're treated as regular users with standard permissions.

---

## Workflow Example

### 1. Test All Roles

```bash
# Start backend in dev mode
pixi run dev-start

# Test admin features
curl -H "X-Dev-Role: admin" ... 

# Test moderator features
curl -H "X-Dev-Role: moderator" ...

# Test user features (no header needed, defaults to 'user')
curl http://localhost:8002/api/products
```

### 2. Check Your Test Data

```bash
curl -H "X-Dev-Role: admin" http://localhost:8002/api/dev/stats
```

### 3. Clean Up When Full

```bash
# View stats
curl -H "X-Dev-Role: admin" http://localhost:8002/api/dev/stats

# If you hit limits:
curl -X POST -H "X-Dev-Role: admin" http://localhost:8002/api/dev/reset

# Reseed
pixi run dev-seed
```

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| "Dev tokens only in TEST_MODE" | Running with `.env` (production) | Use `.env.test` or set `TEST_MODE=true` |
| "Invalid dev role 'foo'" | Wrong role name | Use: `admin`, `moderator`, `manager`, or `user` |
| "Dev row limits exceeded" | Too much test data | `POST /api/dev/reset` then `pixi run dev-seed` |
| Dev endpoints return 404 | Not in dev mode | Confirm `TEST_MODE=true` in `.env.test` |
| Scrapers still running nightly | Schedulers enabled | Verify `DEV_MODE_DISABLE_SCHEDULED_SCRAPERS=true` in config |

