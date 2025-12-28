"""
Seed initial scraper search terms for development.

Populates the scraper_search_terms table (one row per term) for all platforms.
Works with both SQLite and Supabase.
"""
from config import get_settings
from database_adapter import DatabaseAdapter


def main():
    settings = get_settings()
    db = DatabaseAdapter(settings)
    db.init()

    seeds = [
        {
            "platform": "github",
            "terms": [
                "assistive technology",
                "screen reader",
                "eye tracking",
                "speech recognition",
                "switch access",
                "alternative input",
                "text-to-speech",
                "voice control",
                "accessibility aid",
                "mobility aid software",
            ],
        },
        {
            "platform": "thingiverse",
            "terms": [
                "accessibility",
                "assistive device",
                "arthritis grip",
                "adaptive tool",
                "mobility aid",
                "tremor stabilizer",
                "adaptive utensil",
            ],
        },
        {
            "platform": "ravelry",
            "terms": [
                "medical-device-access",
                "medical-device-accessory",
                "mobility-aid-accessor",
                "other-accessibility",
                "therapy-aid",
            ],
        },
    ]

    for seed in seeds:
        platform = seed["platform"]
        terms = seed["terms"]
        
        try:
            # Check if any terms exist for this platform
            existing = db.table("scraper_search_terms").select("search_term").eq("platform", platform).limit(1).execute()
            
            if not existing.data:
                # Insert one row per search term
                rows = [{"platform": platform, "search_term": term} for term in terms]
                db.table("scraper_search_terms").insert(rows).execute()
                print(f"Seeded {len(terms)} search terms for platform={platform}")
            else:
                print(f"scraper_search_terms already seeded for platform={platform} ({len(existing.data)} terms)")
        except Exception as e:
            print(f"Failed to seed scraper_search_terms for platform={platform}: {e}")


if __name__ == "__main__":
    main()

