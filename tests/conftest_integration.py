"""Integration test fixtures using the Supabase test instance."""
import pytest
import os
from database_adapter import DatabaseAdapter
from config import get_settings


@pytest.fixture(scope="session")
def test_settings():
    """Load test environment settings from .env.test"""
    return get_settings(".env.test")


@pytest.fixture(scope="session")
def test_db(test_settings):
    """Supabase test database adapter."""
    if not test_settings.SUPABASE_URL or not test_settings.SUPABASE_KEY:
        pytest.skip("SUPABASE_URL and SUPABASE_KEY required for integration tests")
    db = DatabaseAdapter(test_settings)
    yield db


@pytest.fixture
def clean_database(test_db):
    """Clean database before each test."""
    test_db.cleanup()
    yield test_db


@pytest.fixture
def test_user(clean_database):
    """Create a test user in the test database."""
    from uuid import uuid4
    user_data = {
        "id": str(uuid4()),
        "github_id": f"test-user-{uuid4()}",
        "username": "testuser",
        "email": "test@example.com",
        "display_name": "Test User",
        "role": "user",
    }
    result = clean_database.table("users").insert(user_data).execute()
    return result.data[0]


@pytest.fixture
def test_admin(clean_database):
    """Create a test admin user in the test database."""
    from uuid import uuid4
    admin_data = {
        "id": str(uuid4()),
        "github_id": f"test-admin-{uuid4()}",
        "username": "testadmin",
        "email": "admin@example.com",
        "display_name": "Test Admin",
        "role": "admin",
    }
    result = clean_database.table("users").insert(admin_data).execute()
    return result.data[0]


@pytest.fixture
def github_oauth_config(clean_database, test_admin):
    """Create GitHub OAuth config (no actual credentials needed for public API)."""
    config_data = {
        "platform": "github",
        "client_id": "test-client-id",
        "client_secret": "test-secret",
        "redirect_uri": "http://localhost:8000/api/scrapers/oauth/github/callback",
    }
    result = clean_database.table("oauth_configs").insert(config_data).execute()
    return result.data[0]


@pytest.fixture
def thingiverse_oauth_config(clean_database, test_admin):
    """
    Create Thingiverse OAuth config with access token.

    Requires THINGIVERSE_ACCESS_TOKEN; skipped if absent.
    """
    access_token = os.getenv("THINGIVERSE_ACCESS_TOKEN")
    if not access_token:
        pytest.skip("THINGIVERSE_ACCESS_TOKEN not set")

    config_data = {
        "platform": "thingiverse",
        "client_id": os.getenv("THINGIVERSE_CLIENT_ID", "test-client-id"),
        "client_secret": "test-secret",
        "redirect_uri": "http://localhost:8000/api/scrapers/oauth/thingiverse/callback",
        "access_token": access_token,
    }
    result = clean_database.table("oauth_configs").insert(config_data).execute()
    return result.data[0]


@pytest.fixture
def ravelry_oauth_config(clean_database, test_admin):
    """
    Create Ravelry OAuth config with access token.

    Requires RAVELRY_ACCESS_TOKEN; skipped if absent.
    """
    access_token = os.getenv("RAVELRY_ACCESS_TOKEN")
    if not access_token:
        pytest.skip("RAVELRY_ACCESS_TOKEN not set")

    config_data = {
        "platform": "ravelry",
        "client_id": os.getenv("RAVELRY_CLIENT_ID", "test-client-id"),
        "client_secret": "test-secret",
        "redirect_uri": "http://localhost:8000/api/scrapers/oauth/ravelry/callback",
        "access_token": access_token,
    }
    result = clean_database.table("oauth_configs").insert(config_data).execute()
    return result.data[0]
