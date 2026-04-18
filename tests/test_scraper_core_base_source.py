from scrapers.core import BaseSourceScraper, ScrapeMode, ScrapeRunContext


class _DummySourceScraper(BaseSourceScraper):
    def get_source_name(self) -> str:
        return "dummy"

    def supports_url(self, url: str) -> bool:
        return "example.com" in url

    async def enumerate_candidates(self, context: ScrapeRunContext) -> list[dict]:
        return []

    async def fetch_one(self, candidate: dict, context: ScrapeRunContext) -> dict | None:
        return None

    def map_to_source_raw(self, raw: dict, context: ScrapeRunContext) -> dict:
        return {
            "source": self.get_source_name(),
            "external_id": raw.get("id", "x"),
            "source_url": raw.get("url", "https://example.com/item/x"),
            "name": raw.get("name", "Example Item"),
            "description": raw.get("description"),
            "type": raw.get("type"),
            "source_last_updated": raw.get("source_last_updated"),
            "matched_search_terms": raw.get("matched_search_terms", []),
            "tags": raw.get("tags", []),
            "image_url": raw.get("image_url"),
            "image_alt": raw.get("image_alt"),
            "source_rating": raw.get("source_rating"),
            "source_rating_count": raw.get("source_rating_count"),
            "external_data": raw.get("external_data", {}),
        }


def test_normalize_rating_exponential_bounds():
    scraper = _DummySourceScraper(supabase_client=None)

    assert scraper.normalize_rating_exponential(raw_value=0, expected_max=100) == 1.0
    assert scraper.normalize_rating_exponential(raw_value=100, expected_max=100) <= 5.0
    assert scraper.normalize_rating_exponential(raw_value=500, expected_max=100) == 5.0


def test_pick_representative_image_uses_first_valid_url():
    scraper = _DummySourceScraper(supabase_client=None)

    result = scraper.pick_representative_image(["", "not-a-url", "https://example.com/img.png"])

    assert result == "https://example.com/img.png"


def test_map_to_source_product_applies_defaults_from_context():
    scraper = _DummySourceScraper(supabase_client=None)
    context = ScrapeRunContext(mode=ScrapeMode.SINGLE_PRODUCT, matched_search_terms=["assistive"])

    result = scraper.map_to_source_product(
        {
            "id": "123",
            "url": "https://example.com/item/123?utm_source=test",
            "name": "Widget",
            "external_data": {"raw": True},
        },
        context,
    )

    assert result.external_id == "123"
    assert result.source_url == "https://example.com/item/123"
    assert result.matched_search_terms == ["assistive"]
    assert result.scrape_mode == "single_product"
