#!/usr/bin/env python3
"""
Test the AbleData scraper with the example URL
"""
import asyncio
import os
import sys
import pytest
from dotenv import load_dotenv
from services.database import get_db
from scrapers.abledata import AbleDataScraper

# Load environment variables
env_file = os.getenv('ENV_FILE', '.env.test')
load_dotenv(env_file)


@pytest.mark.skip(reason="AbleData scraper test temporarily disabled")
async def test_abledata_scraper():
    """Test scraping the example AbleData URL"""
    print("Testing AbleData scraper...")
    print("=" * 60)
    
    # Get database client
    db = get_db()
    
    # Create scraper
    scraper = AbleDataScraper(db)
    
    # Test scraping the specific URL
    test_url = 'http://www.abledata.com/abledata.cfm?pageid=114277&ksectionid=19326'
    
    print(f"\n1. Testing single URL scrape: {test_url}")
    print("-" * 60)
    
    try:
        product_data = await scraper.scrape_url(test_url)
        if product_data:
            print(f"✓ Successfully scraped product:")
            print(f"  Name: {product_data.get('name')}")
            print(f"  Description: {product_data.get('description', '')[:200]}...")
            print(f"  Source: {product_data.get('source')}")
            print(f"  Type: {product_data.get('type')}")
        else:
            print("✗ No product data returned")
    except Exception as e:
        print(f"✗ Error scraping URL: {e}")
        import traceback
        traceback.print_exc()
    
    print(f"\n2. Testing full scraper (test mode, 5 products)")
    print("-" * 60)
    
    try:
        result = await scraper.scrape(test_mode=True, test_limit=5)
        print(f"✓ Scraping completed:")
        print(f"  Source: {result.get('source')}")
        print(f"  Status: {result.get('status')}")
        print(f"  Products found: {result.get('products_found')}")
        print(f"  Products added: {result.get('products_added')}")
        print(f"  Products updated: {result.get('products_updated')}")
        print(f"  Duration: {result.get('duration_seconds'):.2f}s")
        if result.get('error_message'):
            print(f"  Error: {result.get('error_message')}")
    except Exception as e:
        print(f"✗ Error running scraper: {e}")
        import traceback
        traceback.print_exc()
    
    print("\n" + "=" * 60)
    print("Test completed!")
    
    # Close scraper
    await scraper.close()


if __name__ == "__main__":
    asyncio.run(test_abledata_scraper())
