"""
Seed OAuth configs for scraper platforms (dev mode).

This script populates the oauth_configs table with platform configurations.
In test mode, this uses placeholder values; in production, OAuth configs must
be managed via admin UI or environment variables.

Run with: uv run python seed_oauth_configs.py
"""

import os
import sys
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database_adapter import Base
import uuid


def _env(name: str, default: str | None = None) -> str | None:
    """Read env var and trim accidental leading/trailing whitespace."""
    value = os.getenv(name)
    if value is None:
        return default
    value = value.strip()
    return value if value else default


def _first_env(names: list[str], default: str | None = None) -> str | None:
    """Return first non-empty env var from a list of candidate names."""
    for name in names:
        value = _env(name)
        if value is not None:
            return value
    return default

# Load environment variables
env_file = os.getenv('ENV_FILE', '.env.test')
if not os.path.exists(env_file):
    print(f"Warning: {env_file} not found, using defaults")
else:
    # override=True ensures values from env_file win over stale shell exports
    load_dotenv(env_file, override=True)

DATABASE_URL = os.getenv('DATABASE_URL')
if not DATABASE_URL:
    print("Error: DATABASE_URL not set")
    sys.exit(1)

# Create database engine and session
engine = create_engine(DATABASE_URL.replace('sqlite+aiosqlite', 'sqlite'), echo=False)
SessionLocal = sessionmaker(bind=engine)

# Create tables if they don't exist
Base.metadata.create_all(bind=engine)

# OAuth configs for dev/test mode
# These are pre-seeded with minimal placeholder values.
# The frontend OAuth flow will update access_token/refresh_token when authorization completes.
# In production, these should be configured via the admin UI.
OAUTH_CONFIGS = [
    {
        "platform": "ravelry",
        "client_id": _env("RAVELRY_APP_KEY", "PLACEHOLDER_CLIENT_ID"),
        "client_secret": _env("RAVELRY_APP_SECRET", "PLACEHOLDER_CLIENT_SECRET"),
        "redirect_uri": _env("RAVELRY_REDIRECT_URI", "http://localhost:8000/api/scrapers/oauth/ravelry/callback"),
        "access_token": _first_env([
            "RAVELRY_ACCESS_TOKEN",
            "RAVELRY_OAUTH_ACCESS_TOKEN",
            "RAVELRY_OAUTH_TOKEN",
            "RAVELRY_TOKEN",
            "RAVELRY_ACCESS",
            "ACCESS_TOKEN_RAVELRY",
            "RAVELRY_TOKEN_VALUE",
            "RAVELRY_AUTH_TOKEN",
            "ACCESS_TOKEN",
        ]),
        "refresh_token": _first_env([
            "RAVELRY_REFRESH_TOKEN",
            "RAVELRY_OAUTH_REFRESH_TOKEN",
            "RAVELRY_TOKEN_REFRESH",
            "RAVELRY_REFRESH",
            "REFRESH_TOKEN_RAVELRY",
            "RAVELRY_TOKEN_REFRESH_VALUE",
            "RAVELRY_AUTH_REFRESH_TOKEN",
            "REFRESH_TOKEN",
        ]),
    },
    {
        "platform": "thingiverse",
        "client_id": _env("THINGIVERSE_CLIENT_ID", "PLACEHOLDER_CLIENT_ID"),
        "client_secret": _env("THINGIVERSE_CLIENT_SECRET", "PLACEHOLDER_CLIENT_SECRET"),
        "redirect_uri": _env("THINGIVERSE_REDIRECT_URI", "http://localhost:8000/api/scrapers/oauth/thingiverse/callback"),
        "access_token": _env("THINGIVERSE_ACCESS_TOKEN"),
        "refresh_token": _env("THINGIVERSE_REFRESH_TOKEN"),
    },
    {
        "platform": "github",
        "client_id": _env("GITHUB_CLIENT_ID", "PLACEHOLDER_CLIENT_ID"),
        "client_secret": _env("GITHUB_CLIENT_SECRET", "PLACEHOLDER_CLIENT_SECRET"),
        "redirect_uri": _env("GITHUB_REDIRECT_URI", "http://localhost:8000/api/auth/callback"),
        "access_token": _env("GITHUB_ACCESS_TOKEN"),
        "refresh_token": _env("GITHUB_REFRESH_TOKEN"),
    },
]


def seed_oauth_configs():
    """Seed the oauth_configs table with platform configurations."""
    from database_adapter import OAuthConfig
    
    db = SessionLocal()
    try:
        print("Seeding oauth_configs table...")

        existing = {cfg.platform: cfg for cfg in db.query(OAuthConfig).all()}
        added = 0
        updated = 0

        for config_data in OAUTH_CONFIGS:
            platform = config_data["platform"]
            existing_config = existing.get(platform)

            if existing_config:
                # Update existing config
                existing_config.client_id = config_data["client_id"]
                existing_config.client_secret = config_data["client_secret"]
                existing_config.redirect_uri = config_data["redirect_uri"]
                if config_data.get("access_token"):
                    existing_config.access_token = config_data["access_token"]
                if config_data.get("refresh_token"):
                    existing_config.refresh_token = config_data["refresh_token"]
                updated += 1
            else:
                # Create new config
                config = OAuthConfig(
                    id=str(uuid.uuid4()),
                    platform=platform,
                    client_id=config_data["client_id"],
                    client_secret=config_data["client_secret"],
                    redirect_uri=config_data["redirect_uri"],
                    access_token=config_data.get("access_token"),
                    refresh_token=config_data.get("refresh_token"),
                )
                db.add(config)
                added += 1
                print(f"  Added: {platform}")

        db.commit()

        total = len(existing) + added
        print(f"✓ OAuth configs present: {total} (added {added}, updated {updated})")
    except Exception as e:
        db.rollback()
        print(f"✗ Error seeding oauth_configs: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_oauth_configs()
