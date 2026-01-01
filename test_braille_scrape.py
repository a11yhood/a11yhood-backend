#!/usr/bin/env python3
"""Test braille scraping with enhanced logging"""
import asyncio
from scrapers.github import GitHubScraper
from database_adapter import DatabaseAdapter
from config import settings

async def main():
    db = DatabaseAdapter(settings)
    scraper = GitHubScraper(db.supabase)
    
    # Override to test only braille
    original_terms = scraper.SEARCH_TERMS
    scraper.SEARCH_TERMS = ["braille"]
    
    print("\n=== Testing Braille Scrape ===\n")
    result = await scraper.scrape(test_mode=False)
    
    print(f"\n=== Result ===")
    print(f"Products found: {result.get('products_found', 0)}")
    print(f"Products added: {result.get('products_added', 0)}")
    print(f"Products updated: {result.get('products_updated', 0)}")

if __name__ == "__main__":
    asyncio.run(main())
