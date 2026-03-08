"""
Database adapter for Supabase.

Always uses Supabase for both production and testing.
Configure SUPABASE_URL/SUPABASE_KEY in .env (production) or .env.test (test instance).
"""
import logging
from typing import Optional
from contextvars import ContextVar

logger = logging.getLogger(__name__)

# Per-request Supabase JWT for RLS-aware queries
_supabase_auth_token: ContextVar[Optional[str]] = ContextVar("supabase_auth_token", default=None)


def set_supabase_auth_token(token: Optional[str]):
    """Store the active Supabase JWT in a context variable for this request."""
    _supabase_auth_token.set(token)


def get_supabase_auth_token() -> Optional[str]:
    """Retrieve the Supabase JWT for the current request, if set."""
    return _supabase_auth_token.get()


class DatabaseAdapter:
    """
    Database adapter for Supabase.

    Configured via SUPABASE_URL and SUPABASE_KEY.
    Use .env for production, .env.test for the test Supabase instance.
    """

    # Tables to clean during test teardown, ordered so dependents come first.
    _TEST_TABLES_ORDER = [
        # Junction / child tables (no standalone id or CASCADE targets)
        "collection_products",
        "product_tags",
        "product_editors",
        "product_urls",
        "ratings",
        "discussions",
        "user_activities",
        "user_requests",
        "scraping_logs",
        # Parent tables
        "tags",
        "blog_posts",
        "collections",
        "products",
        "users",
        "oauth_configs",
        "supported_sources",
        "scraper_search_terms",
    ]

    def __init__(self, settings=None):
        from config import get_settings
        self.settings = settings or get_settings()
        self._request_auth_token = None
        self.backend = "supabase"  # Always Supabase

        if not self.settings.SUPABASE_URL:
            raise ValueError(
                "SUPABASE_URL must be configured. "
                "Set it in .env (production) or .env.test (test instance)."
            )

        from supabase import create_client
        self.supabase = create_client(
            self.settings.SUPABASE_URL,
            self.settings.SUPABASE_KEY,
        )

    def init(self):
        """No-op: schema is managed via Supabase SQL migrations."""
        pass

    def cleanup(self):
        """Delete all rows from every table (for test isolation).

        Uses the service-role key, which bypasses RLS.
        Deletes in dependency order so foreign-key constraints are satisfied.
        """
        # collection_products has a composite PK (collection_id, product_id)
        # with no single "id" column, so filter on collection_id.
        try:
            self.supabase.table("collection_products").delete().gte(
                "collection_id", "00000000-0000-0000-0000-000000000000"
            ).execute()
        except Exception as exc:
            logger.warning("Failed to cleanup table 'collection_products': %s", exc)

        # All remaining tables use a UUID "id" column.
        uuid_tables = [t for t in self._TEST_TABLES_ORDER if t != "collection_products"]
        for table in uuid_tables:
            try:
                self.supabase.table(table).delete().gte(
                    "id", "00000000-0000-0000-0000-000000000000"
                ).execute()
            except Exception as exc:
                logger.warning("Failed to cleanup table '%s': %s", table, exc)

    def table(self, table_name: str):
        """Return the Supabase table query builder for *table_name*."""
        return self.supabase.table(table_name)

    def rpc(self, function_name: str, params: dict = None):
        """Call a Supabase database function (RPC)."""
        return self.supabase.rpc(function_name, params)

    def set_request_auth_token(self, token: str):
        """Store the user JWT for this request (used by some route handlers)."""
        self._request_auth_token = token
