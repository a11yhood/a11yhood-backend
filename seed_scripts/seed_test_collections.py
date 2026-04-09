"""
Seed test collections for local development

Creates sample collections for testing and development:
1. Public collection with products (admin user)
2. Private collection (regular user)
3. Empty public collection (admin user)

Uses junction table (collection_products) for many-to-many relationship.

Run with: uv run python seed_test_collections.py
"""

import os
import sys
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from database_adapter import Base
from datetime import datetime, UTC

# Load environment variables - prefer ENV_FILE if set, otherwise use .env.test
env_file = os.getenv('ENV_FILE', '.env.test')
if not os.path.exists(env_file):
    print(f"Warning: {env_file} not found, using defaults")
else:
    load_dotenv(env_file)

DATABASE_URL = os.getenv('DATABASE_URL')
if not DATABASE_URL:
    print("Error: DATABASE_URL not set")
    sys.exit(1)

# Create database engine and session
engine = create_engine(DATABASE_URL.replace('sqlite+aiosqlite', 'sqlite'), echo=False)
SessionLocal = sessionmaker(bind=engine)

# Create tables if they don't exist
Base.metadata.create_all(bind=engine)

# Test collections data
test_collections = [
    {
        "id": "coll-admin-public-001",
        "slug": "accessible-software-tools",
        "user_id": "49366adb-2d13-412f-9ae5-4c35dbffab10",  # admin_user
        "user_name": "admin_user",
        "name": "Accessible Software Tools",
        "description": "A curated collection of software tools with excellent accessibility features",
        "is_public": True,
        "created_at": datetime.now(UTC).replace(tzinfo=None),
        "updated_at": datetime.now(UTC).replace(tzinfo=None),
    },
    {
        "id": "coll-regular-private-001",
        "slug": "my-personal-collection",
        "user_id": "2a3b7c3e-971b-4b42-9c8c-0f1843486c50",  # regular_user
        "user_name": "regular_user",
        "name": "My Personal Collection",
        "description": "Private collection of products I like",
        "is_public": False,
        "created_at": datetime.now(UTC).replace(tzinfo=None),
        "updated_at": datetime.now(UTC).replace(tzinfo=None),
    },
    {
        "id": "coll-admin-public-002",
        "slug": "empty-collection",
        "user_id": "49366adb-2d13-412f-9ae5-4c35dbffab10",  # admin_user
        "user_name": "admin_user",
        "name": "Empty Collection",
        "description": "A public collection waiting for products",
        "is_public": True,
        "created_at": datetime.now(UTC).replace(tzinfo=None),
        "updated_at": datetime.now(UTC).replace(tzinfo=None),
    },
]

# Products to add to collections via junction table
# Format: (collection_id, product_slug, position)
collection_products = [
    ("coll-admin-public-001", "test-product", 0),  # Test product from seed_test_product
]

def seed_collections():
    """Create test collections in the database"""
    print("Creating test collections...\n")
    
    session = SessionLocal()
    
    try:
        for coll_data in test_collections:
            # Check if collection already exists
            result = session.execute(
                text("SELECT * FROM collections WHERE id = :id"),
                {"id": coll_data["id"]}
            ).fetchone()
            
            if result:
                # Update existing collection
                session.execute(
                    text("""
                        UPDATE collections 
                        SET slug = :slug, user_id = :user_id, user_name = :user_name,
                            name = :name, description = :description, is_public = :is_public,
                            updated_at = :updated_at
                        WHERE id = :id
                    """),
                    coll_data
                )
                print(f"  ✓ Updated collection '{coll_data['name']}' (ID: {coll_data['id']})")
            else:
                # Create new collection
                session.execute(
                    text("""
                        INSERT INTO collections (id, slug, user_id, user_name, name, description, 
                                                is_public, created_at, updated_at)
                        VALUES (:id, :slug, :user_id, :user_name, :name, :description,
                               :is_public, :created_at, :updated_at)
                    """),
                    coll_data
                )
                print(f"  ✓ Created collection '{coll_data['name']}' (ID: {coll_data['id']})")
        
        session.commit()
        
        # Add products to collections via junction table
        print("\nAdding products to collections...")
        for collection_id, product_slug, position in collection_products:
            # Get product ID from slug
            product_result = session.execute(
                text("SELECT id FROM products WHERE slug = :slug"),
                {"slug": product_slug}
            ).fetchone()
            
            if product_result:
                product_id = product_result[0]
                
                # Check if junction entry already exists
                existing = session.execute(
                    text("SELECT * FROM collection_products WHERE collection_id = :cid AND product_id = :pid"),
                    {"cid": collection_id, "pid": product_id}
                ).fetchone()
                
                if not existing:
                    # Create junction entry
                    session.execute(
                        text("""
                            INSERT INTO collection_products (collection_id, product_id, position)
                            VALUES (:collection_id, :product_id, :position)
                        """),
                        {
                            "collection_id": collection_id,
                            "product_id": product_id,
                            "position": position
                        }
                    )
                    session.commit()
                    print(f"  ✓ Added product '{product_slug}' to collection '{collection_id}'")
                else:
                    print(f"  - Product '{product_slug}' already in collection '{collection_id}'")
            else:
                print(f"  ! Product '{product_slug}' not found, skipping")
        
        print("\n✓ Test collections setup complete!")
        
    except Exception as e:
        session.rollback()
        print(f"Error seeding collections: {e}")
        sys.exit(1)
    finally:
        session.close()

if __name__ == "__main__":
    seed_collections()

    seed_collections()
