"""
Backend scraper service - handles OAuth and coordinates scraping
"""

import os
from datetime import UTC, datetime
from typing import Any

import httpx

from scrapers.core.contracts import ScrapeMode, ScrapeRunContext
from scrapers.core.thingiverse_adapter import ThingiverseSourceAdapter
from scrapers.github import GitHubScraper
from scrapers.goat import GOATScraper
from scrapers.ravelry import RavelryScraper
from scrapers.thingiverse import ThingiverseScraper


class ScraperOAuth:
    """Handle OAuth flows for different platforms"""

    @staticmethod
    async def get_ravelry_token(
        client_id: str, client_secret: str, code: str, redirect_uri: str
    ) -> dict[str, Any]:
        """Exchange Ravelry OAuth code for access token"""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://www.ravelry.com/oauth2/token",
                auth=(client_id, client_secret),
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": redirect_uri,
                },
            )
            response.raise_for_status()
            return response.json()

    @staticmethod
    async def get_thingiverse_token(
        client_id: str, client_secret: str, code: str, redirect_uri: str
    ) -> dict[str, Any]:
        """Exchange Thingiverse OAuth code for access token"""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://www.thingiverse.com/login/oauth/access_token",
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": redirect_uri,
                    "client_id": client_id,
                    "client_secret": client_secret,
                },
            )
            response.raise_for_status()
            return response.json()

    @staticmethod
    async def refresh_ravelry_token(
        client_id: str, client_secret: str, refresh_token: str
    ) -> dict[str, Any]:
        """Refresh Ravelry access token"""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://www.ravelry.com/oauth2/token",
                auth=(client_id, client_secret),
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                },
            )
            response.raise_for_status()
            return response.json()


class ScraperService:
    """Coordinate scraping operations"""

    def __init__(self, supabase_client):
        self.supabase = supabase_client

    @staticmethod
    def _truthy_env(name: str, default: bool) -> bool:
        value = os.getenv(name)
        if value is None:
            return default
        return value.strip().lower() in {"1", "true", "yes", "on"}

    def _load_platform_terms(self, platform: str) -> list[str] | None:
        """Load persisted search terms for a platform from either schema variant."""
        try:
            response = (
                self.supabase.table("scraper_search_terms")
                .select("search_terms")
                .eq("platform", platform)
                .limit(1)
                .execute()
            )
            terms = (response.data or [{}])[0].get("search_terms") if response.data else None
            if not (isinstance(terms, list) and terms):
                normalized = (
                    self.supabase.table("scraper_search_terms")
                    .select("search_term")
                    .eq("platform", platform)
                    .execute()
                )
                terms = [
                    row.get("search_term")
                    for row in (normalized.data or [])
                    if row.get("search_term")
                ]

            return terms if isinstance(terms, list) and terms else None
        except Exception:
            return None

    async def _scrape_thingiverse_legacy(
        self, access_token: str | None, test_mode: bool = False, test_limit: int = 5
    ) -> dict[str, Any]:
        """Legacy Thingiverse implementation kept as a safe fallback."""
        scraper = ThingiverseScraper(self.supabase, access_token)
        terms = self._load_platform_terms("thingiverse")
        if terms:
            scraper.SEARCH_TERMS = terms

        try:
            result = await scraper.scrape(test_mode=test_mode, test_limit=test_limit)
            result["harness"] = "legacy"
            return result
        finally:
            await scraper.close()

    async def _scrape_thingiverse_core(
        self, access_token: str | None, test_mode: bool = False, test_limit: int = 5
    ) -> dict[str, Any]:
        """Run Thingiverse via core adapter enumeration/fetch with legacy persistence layer."""
        if not access_token:
            raise ValueError("Thingiverse access token is required")

        adapter = ThingiverseSourceAdapter(self.supabase, access_token=access_token)
        persistence = ThingiverseScraper(self.supabase, access_token)

        terms = self._load_platform_terms("thingiverse")
        if terms:
            adapter.SEARCH_TERMS = terms
            persistence.SEARCH_TERMS = terms

        mode = ScrapeMode.FULL_SOURCE_TEST_N if test_mode else ScrapeMode.FULL_SOURCE
        context = ScrapeRunContext(mode=mode, max_products=test_limit if test_mode else None)

        start_time = datetime.now(UTC)
        products_found = 0
        products_added = 0
        products_updated = 0

        try:
            candidates = await adapter.enumerate_candidates(context)

            for candidate in candidates:
                raw = await adapter.fetch_one(candidate, context)
                if not raw:
                    continue

                products_found += 1

                thing_id = raw.get("id")
                url = raw.get("public_url") or (
                    f"https://www.thingiverse.com/thing:{thing_id}" if thing_id is not None else None
                )
                if not url:
                    continue

                existing = await persistence._product_exists(
                    url,
                    external_id=str(thing_id) if thing_id is not None else None,
                    source=persistence.get_source_name(),
                )

                if existing:
                    result = await persistence._update_product(existing["id"], raw)
                    if result:
                        products_updated += 1
                else:
                    result = await persistence._create_product(raw)
                    if result:
                        products_added += 1

            duration = (datetime.now(UTC) - start_time).total_seconds()
            return {
                "source": "Thingiverse",
                "products_found": products_found,
                "products_added": products_added,
                "products_updated": products_updated,
                "duration_seconds": duration,
                "status": "success",
                "harness": "core",
            }
        except Exception as e:
            duration = (datetime.now(UTC) - start_time).total_seconds()
            return {
                "source": "Thingiverse",
                "products_found": products_found,
                "products_added": products_added,
                "products_updated": products_updated,
                "duration_seconds": duration,
                "status": "error",
                "error_message": str(e),
                "harness": "core",
            }
        finally:
            await adapter.close()
            await persistence.close()

    async def scrape_thingiverse(
        self, access_token: str | None, test_mode: bool = False, test_limit: int = 5
    ) -> dict[str, Any]:
        """Scrape Thingiverse for accessibility products."""
        use_core_harness = self._truthy_env("THINGIVERSE_USE_CORE_HARNESS", True)
        if use_core_harness:
            return await self._scrape_thingiverse_core(
                access_token=access_token,
                test_mode=test_mode,
                test_limit=test_limit,
            )

        return await self._scrape_thingiverse_legacy(
            access_token=access_token,
            test_mode=test_mode,
            test_limit=test_limit,
        )

    async def scrape_ravelry(
        self, access_token: str, test_mode: bool = False, test_limit: int = 5
    ) -> dict[str, Any]:
        """Scrape Ravelry for accessibility patterns"""
        scraper = RavelryScraper(self.supabase, access_token)
        # Load persisted PA categories, supporting both array and normalized schemas
        try:
            response = (
                self.supabase.table("scraper_search_terms")
                .select("search_terms")
                .eq("platform", "ravelry_pa_categories")
                .limit(1)
                .execute()
            )
            cats = (response.data or [{}])[0].get("search_terms") if response.data else None
            if not (isinstance(cats, list) and cats):
                resp2 = (
                    self.supabase.table("scraper_search_terms")
                    .select("search_term")
                    .eq("platform", "ravelry_pa_categories")
                    .execute()
                )
                cats = [r.get("search_term") for r in (resp2.data or []) if r.get("search_term")]
            if isinstance(cats, list) and cats:
                scraper.PA_CATEGORIES = cats
        except Exception:
            pass
        try:
            result = await scraper.scrape(test_mode=test_mode, test_limit=test_limit)
            return result
        finally:
            await scraper.close()

    async def scrape_github(self, test_mode: bool = False, test_limit: int = 5) -> dict[str, Any]:
        """Scrape GitHub for assistive technology repositories"""
        token: str | None = None
        # Prefer stored token (set via admin UI), fall back to env for local/dev.
        try:
            config_response = (
                self.supabase.table("oauth_configs")
                .select("access_token")
                .eq("platform", "github")
                .execute()
            )
            token = (
                (config_response.data or [{}])[0].get("access_token")
                if config_response.data
                else None
            )
        except Exception:
            token = None

        if not token:
            token = os.getenv("GITHUB_TOKEN") or os.getenv("GITHUB_ACCESS_TOKEN")

        scraper = GitHubScraper(self.supabase, access_token=token)
        # Load persisted search terms, supporting both array and normalized schemas
        try:
            response = (
                self.supabase.table("scraper_search_terms")
                .select("search_terms")
                .eq("platform", "github")
                .limit(1)
                .execute()
            )
            terms = (response.data or [{}])[0].get("search_terms") if response.data else None
            if not (isinstance(terms, list) and terms):
                resp2 = (
                    self.supabase.table("scraper_search_terms")
                    .select("search_term")
                    .eq("platform", "github")
                    .execute()
                )
                terms = [r.get("search_term") for r in (resp2.data or []) if r.get("search_term")]
            if isinstance(terms, list) and terms:
                scraper.SEARCH_TERMS = terms
        except Exception:
            # If DB read fails, continue with default in-memory terms
            pass
        try:
            result = await scraper.scrape(test_mode=test_mode, test_limit=test_limit)
            return result
        finally:
            await scraper.close()

    async def scrape_goat(
        self, access_token: str | None = None, test_mode: bool = False, test_limit: int = 5
    ) -> dict[str, Any]:
        """Scrape LibraryThing for books with accessibility information"""
        scraper = GOATScraper(self.supabase, access_token=access_token)
        # Note: GOAT scraper is primarily for URL-based scraping
        # Search terms are not currently supported for bulk scraping
        try:
            result = await scraper.scrape(test_mode=test_mode, test_limit=test_limit)
            return result
        finally:
            await scraper.close()
