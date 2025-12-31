#!/usr/bin/env python3
"""
Manual test script for GOAT scraper
Helps debug issues with scraping
"""
import asyncio
import os
from services.database import get_db
from scrapers.goat import GOATScraper

async def test_goat():
    """Test GOAT scraper with a known work ID"""
    print("=" * 60)
    print("Testing GOAT Scraper")
    print("=" * 60)
    
    db = get_db()
    
    # Get API key from environment or database
    api_key = None
    try:
        config_response = db.table("oauth_configs").select("access_token").eq("platform", "goat").execute()
        if config_response.data:
            api_key = config_response.data[0].get("access_token")
    except Exception as e:
        print(f"Error getting API key from database: {e}")
    
    if not api_key:
        api_key = os.getenv("LIBRARYTHING_API_KEY")
    
    if not api_key:
        print("✗ No API key found! Set LIBRARYTHING_API_KEY env var or configure in oauth_configs table")
        return
    
    print(f"✓ API key found: {api_key[:10]}...")
    
    scraper = GOATScraper(db, access_token=api_key)
    
    # Test 1: Fetch a known work
    print("\n" + "=" * 60)
    print("Test 1: Fetch a single work by ID")
    print("=" * 60)
    test_work_id = "35356138"  # "The Curious Garden"
    print(f"Fetching work ID: {test_work_id}")
    
    work_data = await scraper._fetch_work_details(test_work_id)
    if work_data:
        print(f"✓ Work fetched successfully!")
        print(f"  Title: {work_data.get('title')}")
        print(f"  Author: {work_data.get('author')}")
        print(f"  Image: {work_data.get('image_url')}")
        print(f"  Tags: {work_data.get('tags')}")
    else:
        print(f"✗ Failed to fetch work")
        await scraper.close()
        return
    
    # Test 2: Create product dict
    print("\n" + "=" * 60)
    print("Test 2: Create product dict")
    print("=" * 60)
    
    product_dict = scraper._create_product_dict(work_data, f"https://www.librarything.com/work/{test_work_id}")
    print(f"Product dict fields:")
    for key, value in product_dict.items():
        if isinstance(value, str) and len(value) > 50:
            print(f"  {key}: {value[:50]}...")
        else:
            print(f"  {key}: {value}")
    
    # Test 3: Try to create product in database
    print("\n" + "=" * 60)
    print("Test 3: Create product in database")
    print("=" * 60)
    
    # First check if it exists
    product_url = f"https://www.librarything.com/work/{test_work_id}"
    existing = await scraper._product_exists(product_url)
    
    if existing:
        print(f"Product already exists with ID: {existing.get('id')}")
        print(f"Attempting to update...")
        success = await scraper._update_product(existing['id'], work_data)
        if success:
            print(f"✓ Product updated successfully!")
        else:
            print(f"✗ Failed to update product")
    else:
        print("Product does not exist, creating new...")
        success = await scraper._create_product(work_data)
        if success:
            print(f"✓ Product created successfully!")
        else:
            print(f"✗ Failed to create product")
    
    # Test 4: Check scraper_search_terms
    print("\n" + "=" * 60)
    print("Test 4: Check scraper_search_terms")
    print("=" * 60)
    
    try:
        response = db.table('scraper_search_terms').select('*').eq('platform', 'goat').execute()
        if response.data:
            print(f"Found {len(response.data)} work IDs in scraper_search_terms:")
            for item in response.data:
                print(f"  - {item.get('search_term')}")
        else:
            print("No work IDs found in scraper_search_terms table")
            print("To add work IDs, insert into scraper_search_terms with platform='goat'")
    except Exception as e:
        print(f"Error checking scraper_search_terms: {e}")
    
    await scraper.close()
    print("\n" + "=" * 60)
    print("Test complete!")
    print("=" * 60)

if __name__ == "__main__":
    asyncio.run(test_goat())
