import math
from abc import ABC, abstractmethod
from datetime import UTC
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

from .contracts import RateLimitPolicy, ScrapeRunContext, SourceScrapedProduct


class BaseSourceScraper(ABC):
    """Lean phase-1 base class for source-specific scraper adapters.

    Existing scrapers are unchanged for now; this class defines the new contract.
    """

    DEFAULT_MIN_RATING = 1.0
    DEFAULT_MAX_RATING = 5.0

    def __init__(
        self,
        supabase_client,
        *,
        rate_limit_policy: RateLimitPolicy | None = None,
    ):
        self.supabase = supabase_client
        self.rate_limit_policy = rate_limit_policy

    @abstractmethod
    def get_source_name(self) -> str:
        pass

    @abstractmethod
    def supports_url(self, url: str) -> bool:
        pass

    @abstractmethod
    async def enumerate_candidates(self, context: ScrapeRunContext) -> list[dict]:
        pass

    @abstractmethod
    async def fetch_one(self, candidate: dict, context: ScrapeRunContext) -> dict | None:
        pass

    @abstractmethod
    def map_to_source_raw(self, raw: dict, context: ScrapeRunContext) -> dict:
        pass

    def generate_tags(self, raw: dict, source_raw: dict) -> list[str]:
        tags = source_raw.get("tags") or raw.get("tags") or []
        return [str(tag).strip() for tag in tags if str(tag).strip()]

    def normalize_rating_exponential(
        self,
        *,
        raw_value: float | int | None,
        expected_max: float | int,
        min_rating: float = DEFAULT_MIN_RATING,
        max_rating: float = DEFAULT_MAX_RATING,
        target_at_max: float = 0.95,
    ) -> float | None:
        if raw_value is None:
            return None

        raw = max(float(raw_value), 0.0)
        expected = max(float(expected_max), 1.0)

        # Make expected_max map close to max_rating while preserving a smooth curve.
        target = min(max(target_at_max, 0.01), 0.99)
        k = -math.log(1.0 - target) / expected
        numerator = 1.0 - math.exp(-k * raw)
        denominator = 1.0 - math.exp(-k * expected)
        scaled = numerator / denominator if denominator > 0 else 0.0
        normalized = min_rating + (max_rating - min_rating) * scaled
        return round(min(max(normalized, min_rating), max_rating), 2)

    def pick_representative_image(
        self,
        image_candidates: list[str] | None,
        fallback: str | None = None,
    ) -> str | None:
        if image_candidates:
            for value in image_candidates:
                candidate = (value or "").strip()
                if candidate.startswith("http://") or candidate.startswith("https://"):
                    return candidate
        return fallback

    def normalize_url(self, url: str | None) -> str | None:
        if not url:
            return url

        parsed = urlparse(url)
        scheme = (parsed.scheme or "https").lower()
        netloc = parsed.netloc.lower()
        path = parsed.path.rstrip("/") or "/"

        # Drop common tracking params but keep meaningful query fields.
        keep = [
            (k, v)
            for k, v in parse_qsl(parsed.query, keep_blank_values=True)
            if not k.lower().startswith("utm_") and k.lower() not in {"ref", "source"}
        ]
        query = urlencode(keep)

        return urlunparse((scheme, netloc, path, "", query, ""))

    def map_to_source_product(self, raw: dict, context: ScrapeRunContext) -> SourceScrapedProduct:
        payload = self.map_to_source_raw(raw, context)
        tags = self.generate_tags(raw, payload)
        fetched_at = context.fetched_at.astimezone(UTC).isoformat()

        return SourceScrapedProduct(
            source=payload["source"],
            external_id=str(payload["external_id"]),
            source_url=self.normalize_url(payload["source_url"]) or payload["source_url"],
            name=payload["name"],
            description=payload.get("description"),
            type=payload.get("type"),
            source_last_updated=payload.get("source_last_updated"),
            matched_search_terms=payload.get("matched_search_terms")
            or context.matched_search_terms,
            tags=tags,
            image_url=payload.get("image_url"),
            image_alt=payload.get("image_alt"),
            source_rating=payload.get("source_rating"),
            source_rating_count=payload.get("source_rating_count"),
            external_data=payload.get("external_data") or {},
            fetched_at=fetched_at,
            scrape_mode=context.mode.value,
        )

