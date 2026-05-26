from unittest.mock import MagicMock

import pytest

from scrapers.base_scraper import BaseScraper


class _Response:
    def __init__(self, data):
        self.data = data


class DummyScraper(BaseScraper):
    async def scrape(self, test_mode: bool = False, test_limit: int = 5):
        return {}

    def get_source_name(self) -> str:
        return "github"

    def _create_product_dict(self, raw_data):
        return {
            "name": "Scraped Name",
            "description": "Scraped Description",
            "type": "Software",
            "tags": ["a11y", "oss"],
            "source": "github",
            "source_url": "https://github.com/example/repo",
            "external_id": "123",
            "scraped_at": "2026-01-01T00:00:00",
            "source_rating": 4.5,
            "source_rating_count": 88,
            "external_data": {"language": "Python"},
        }


def _build_supabase(existing_product: dict, has_tags: bool):
    supabase = MagicMock()

    products_table = MagicMock()
    products_select = MagicMock()
    products_update = MagicMock()

    products_table.select.return_value = products_select
    products_select.eq.return_value = products_select
    products_select.limit.return_value = products_select
    products_select.execute.return_value = _Response([existing_product])

    products_table.update.return_value = products_update
    products_update.eq.return_value = products_update
    products_update.execute.return_value = _Response([{"id": existing_product["id"]}])

    product_tags_table = MagicMock()
    product_tags_select = MagicMock()
    product_tags_table.select.return_value = product_tags_select
    product_tags_select.eq.return_value = product_tags_select
    product_tags_select.limit.return_value = product_tags_select
    product_tags_select.execute.return_value = _Response(
        [{"product_id": existing_product["id"]}] if has_tags else []
    )

    def table_side_effect(name):
        if name == "products":
            return products_table
        if name == "product_tags":
            return product_tags_table
        return MagicMock()

    supabase.table.side_effect = table_side_effect
    return supabase, products_table


@pytest.mark.asyncio
async def test_update_product_preserves_populated_human_edited_fields_and_tags():
    existing = {
        "id": "p1",
        "name": "User Curated Name",
        "description": "User Curated Description",
        "type": "Learning",
        "last_edited_at": "2026-01-01T00:00:00",
        "last_edited_by": "user-1",
    }
    supabase, products_table = _build_supabase(existing_product=existing, has_tags=True)
    scraper = DummyScraper(supabase)

    ok = await scraper._update_product("p1", {"name": "raw"})

    assert ok is True
    update_payload = products_table.update.call_args.args[0]

    assert "name" not in update_payload
    assert "description" not in update_payload
    assert "type" not in update_payload
    assert "source" not in update_payload
    assert "source_url" not in update_payload
    assert "external_id" not in update_payload
    assert "scraped_at" not in update_payload
    assert "source_rating" in update_payload
    assert "source_rating_count" in update_payload
    assert "updated_at" in update_payload


@pytest.mark.asyncio
async def test_update_product_backfills_missing_fields_and_tags(monkeypatch):
    existing = {
        "id": "p2",
        "name": "",
        "description": None,
        "type": None,
    }
    supabase, products_table = _build_supabase(existing_product=existing, has_tags=False)
    scraper = DummyScraper(supabase)

    captured = {"called": False, "tags": None}

    def fake_set_product_tags(_db, _product_id, tags):
        captured["called"] = True
        captured["tags"] = tags

    monkeypatch.setattr("routers.products.set_product_tags", fake_set_product_tags)

    ok = await scraper._update_product("p2", {"name": "raw"})

    assert ok is True
    update_payload = products_table.update.call_args.args[0]

    assert update_payload["name"] == "Scraped Name"
    assert update_payload["description"] == "Scraped Description"
    assert update_payload["type"] == "Software"
    assert captured["called"] is True
    assert captured["tags"] == ["a11y", "oss"]


@pytest.mark.asyncio
async def test_update_product_refreshes_populated_fields_when_not_human_edited(monkeypatch):
    existing = {
        "id": "p3",
        "name": "Old Name",
        "description": "Old Description",
        "type": "Hardware",
        "last_edited_at": None,
        "last_edited_by": None,
    }
    supabase, products_table = _build_supabase(existing_product=existing, has_tags=False)
    scraper = DummyScraper(supabase)

    captured = {"called": False, "tags": None}

    def fake_set_product_tags(_db, _product_id, tags):
        captured["called"] = True
        captured["tags"] = tags

    monkeypatch.setattr("routers.products.set_product_tags", fake_set_product_tags)

    ok = await scraper._update_product("p3", {"name": "raw"})

    assert ok is True
    update_payload = products_table.update.call_args.args[0]

    assert update_payload["name"] == "Scraped Name"
    assert update_payload["description"] == "Scraped Description"
    assert update_payload["type"] == "Software"
    assert captured["called"] is True
    assert captured["tags"] == ["a11y", "oss"]
