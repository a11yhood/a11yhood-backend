"""
Seed test collections into Supabase.

Creates sample collections for testing:
  1. Public collection with products (admin user)
  2. Private collection (regular user)
  3. Empty public collection (admin user)

Run with: uv run python seed_scripts/seed_test_collections.py
"""

import os
import sys

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

from dotenv import load_dotenv

env_file = os.getenv("ENV_FILE", ".env.test")
load_dotenv(env_file, override=True)

from config import get_settings
from database_adapter import DatabaseAdapter

# Fixed collection IDs for stable test references
TEST_COLLECTIONS = [
    {
        "id": "coll-admin-public-001",
        "slug": "accessible-software-tools",
        "user_id": "49366adb-2d13-412f-9ae5-4c35dbffab10",  # admin_user
        "user_name": "admin_user",
        "name": "Accessible Software Tools",
        "description": "A curated collection of software tools with excellent accessibility features",
        "is_public": True,
    },
    {
        "id": "coll-regular-private-001",
        "slug": "my-personal-collection",
        "user_id": "2a3b7c3e-971b-4b42-9c8c-0f1843486c50",  # regular_user
        "user_name": "regular_user",
        "name": "My Personal Collection",
        "description": "Private collection of products I like",
        "is_public": False,
    },
    {
        "id": "coll-admin-public-002",
        "slug": "empty-collection",
        "user_id": "49366adb-2d13-412f-9ae5-4c35dbffab10",  # admin_user
        "user_name": "admin_user",
        "name": "Empty Collection",
        "description": "A public collection waiting for products",
        "is_public": True,
    },
]

# Products to add to collections: (collection_id, product_slug)
COLLECTION_PRODUCTS = [
    ("coll-admin-public-001", "test-product"),
]


def seed_collections():
    """Upsert test collections and add products to them."""
    settings = get_settings(env_file)
    db = DatabaseAdapter(settings)

    print("Creating test collections...\n")

    for coll in TEST_COLLECTIONS:
        try:
            result = db.table("collections").upsert(coll, on_conflict="slug").execute()
            if result.data:
                print(f"  ✓ Collection '{coll['name']}' (ID: {coll['id']})")
            else:
                print(f"  ? Collection '{coll['name']}': no data returned")
        except Exception as e:
            print(f"  ✗ Collection '{coll['name']}': {e}")

    print("\nAdding products to collections...")
    for collection_id, product_slug in COLLECTION_PRODUCTS:
        try:
            prod_result = db.table("products").select("id").eq("slug", product_slug).execute()
            if not prod_result.data:
                print(f"  ! Product '{product_slug}' not found, skipping")
                continue

            product_id = prod_result.data[0]["id"]
            db.table("collection_products").upsert(
                {"collection_id": collection_id, "product_id": product_id},
                on_conflict="collection_id,product_id",
            ).execute()
            print(f"  ✓ Added '{product_slug}' to collection '{collection_id}'")
        except Exception as e:
            print(f"  ✗ '{product_slug}' -> '{collection_id}': {e}")

    print("\n✓ Test collections seeding complete!")


if __name__ == "__main__":
    seed_collections()
