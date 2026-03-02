"""Tests for /api/tags and /api/products/tags/featured endpoints."""
import pytest
import uuid


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _insert_tag(db, name: str, featured: bool = False) -> dict:
    tag_id = str(uuid.uuid4())
    result = db.table("tags").insert({"id": tag_id, "name": name, "featured": featured}).execute()
    return result.data[0]


# ===========================================================================
# GET /api/products/tags/featured
# ===========================================================================

def test_get_featured_tags_empty(client, clean_database):
    """Returns empty list when no tags are featured."""
    resp = client.get("/api/products/tags/featured")
    assert resp.status_code == 200
    assert resp.json() == {"tags": []}


def test_get_featured_tags_returns_only_featured(client, clean_database):
    """Only tags with featured=True are returned."""
    _insert_tag(clean_database, "featured-tag", featured=True)
    _insert_tag(clean_database, "regular-tag", featured=False)

    resp = client.get("/api/products/tags/featured")
    assert resp.status_code == 200
    data = resp.json()
    assert data["tags"] == ["featured-tag"]


def test_get_featured_tags_sorted_alphabetically(client, clean_database):
    """Featured tags are returned in alphabetical order."""
    for name in ["zebra", "apple", "mango"]:
        _insert_tag(clean_database, name, featured=True)

    resp = client.get("/api/products/tags/featured")
    assert resp.status_code == 200
    assert resp.json()["tags"] == ["apple", "mango", "zebra"]


# ===========================================================================
# GET /api/tags
# ===========================================================================

def test_list_tags_empty(client, clean_database):
    """Returns empty list when no tags exist."""
    resp = client.get("/api/tags")
    assert resp.status_code == 200
    assert resp.json() == []


def test_list_tags_returns_all(client, clean_database):
    """Returns all tags with id, name and featured fields."""
    tag = _insert_tag(clean_database, "accessibility", featured=False)

    resp = client.get("/api/tags")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["id"] == tag["id"]
    assert data[0]["name"] == "accessibility"
    assert data[0]["featured"] is False


def test_list_tags_filter_featured(client, clean_database):
    """The featured query parameter filters results."""
    _insert_tag(clean_database, "featured-one", featured=True)
    _insert_tag(clean_database, "non-featured", featured=False)

    resp_featured = client.get("/api/tags?featured=true")
    assert resp_featured.status_code == 200
    names = [t["name"] for t in resp_featured.json()]
    assert "featured-one" in names
    assert "non-featured" not in names

    resp_not_featured = client.get("/api/tags?featured=false")
    assert resp_not_featured.status_code == 200
    names = [t["name"] for t in resp_not_featured.json()]
    assert "non-featured" in names
    assert "featured-one" not in names


def test_list_tags_sorted_alphabetically(client, clean_database):
    """Tags are sorted alphabetically by name."""
    for name in ["zebra", "apple"]:
        _insert_tag(clean_database, name)

    resp = client.get("/api/tags")
    assert resp.status_code == 200
    names = [t["name"] for t in resp.json()]
    assert names == sorted(names)


# ===========================================================================
# GET /api/tags/{tag_id}
# ===========================================================================

def test_get_tag_by_id(client, clean_database):
    """Returns a single tag by ID."""
    tag = _insert_tag(clean_database, "braille", featured=True)

    resp = client.get(f"/api/tags/{tag['id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == tag["id"]
    assert data["name"] == "braille"
    assert data["featured"] is True


def test_get_tag_not_found(client, clean_database):
    """Returns 404 for unknown tag ID."""
    resp = client.get(f"/api/tags/{uuid.uuid4()}")
    assert resp.status_code == 404


# ===========================================================================
# PATCH /api/tags/{tag_id}
# ===========================================================================

def test_patch_tag_set_featured_requires_admin(client, auth_client, clean_database):
    """Regular users cannot update tags."""
    tag = _insert_tag(clean_database, "audio-description")

    resp = auth_client.patch(f"/api/tags/{tag['id']}", json={"featured": True})
    assert resp.status_code == 403


def test_patch_tag_set_featured_unauthenticated(client, clean_database):
    """Unauthenticated requests cannot update tags."""
    tag = _insert_tag(clean_database, "audio-description")

    resp = client.patch(f"/api/tags/{tag['id']}", json={"featured": True})
    assert resp.status_code == 401


def test_patch_tag_set_featured_admin(admin_client, clean_database):
    """Admin can set featured=True on a tag."""
    tag = _insert_tag(clean_database, "screen-reader", featured=False)

    resp = admin_client.patch(f"/api/tags/{tag['id']}", json={"featured": True})
    assert resp.status_code == 200
    data = resp.json()
    assert data["featured"] is True
    assert data["name"] == "screen-reader"


def test_patch_tag_unset_featured_admin(admin_client, clean_database):
    """Admin can set featured=False on a featured tag."""
    tag = _insert_tag(clean_database, "magnification", featured=True)

    resp = admin_client.patch(f"/api/tags/{tag['id']}", json={"featured": False})
    assert resp.status_code == 200
    assert resp.json()["featured"] is False


def test_patch_tag_not_found(admin_client, clean_database):
    """Returns 404 when tag does not exist."""
    resp = admin_client.patch(f"/api/tags/{uuid.uuid4()}", json={"featured": True})
    assert resp.status_code == 404


def test_patch_tag_no_body_returns_existing(admin_client, clean_database):
    """PATCH with no updateable fields returns the existing tag unchanged."""
    tag = _insert_tag(clean_database, "captioning", featured=False)

    resp = admin_client.patch(f"/api/tags/{tag['id']}", json={})
    assert resp.status_code == 200
    assert resp.json()["featured"] is False
