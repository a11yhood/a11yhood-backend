#!/usr/bin/env python3
"""
Run migration: Create collection_products junction table
"""
import os
import sys
from supabase import create_client

def run_migration():
    # Get Supabase credentials from environment
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_KEY")
    
    if not supabase_url or not supabase_key:
        print("Error: SUPABASE_URL and SUPABASE_KEY must be set")
        sys.exit(1)
    
    # Create Supabase client
    supabase = create_client(supabase_url, supabase_key)
    
    # Read migration SQL
    with open("migrations/20260103_create_collection_products_junction.sql", "r") as f:
        sql = f.read()
    
    # Execute migration via RPC
    # Note: Supabase postgrest doesn't support DDL directly, so we need to use the SQL editor
    print("Migration SQL:")
    print("=" * 80)
    print(sql)
    print("=" * 80)
    print("\nTo run this migration:")
    print("1. Go to https://supabase.com/dashboard/project/ztnxqktwvwlbepflxvzp/sql/new")
    print("2. Copy and paste the SQL above")
    print("3. Click 'Run' to execute the migration")
    print("\nAlternatively, install psql and run:")
    print('  cat migrations/20260103_create_collection_products_junction.sql | \\')
    print(f'    PGPASSWORD="$SUPABASE_KEY" psql \\')
    print('    -h db.ztnxqktwvwlbepflxvzp.supabase.co \\')
    print('    -U postgres -d postgres')

if __name__ == "__main__":
    # Load .env file
    from dotenv import load_dotenv
    load_dotenv()
    
    run_migration()
