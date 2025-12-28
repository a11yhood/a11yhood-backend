-- Migration: Normalize scraper_search_terms to one row per search term
-- Date: 2025-12-28
-- Description: Convert from JSONB array per platform to one row per search term
-- This eliminates upsert complexity and the duplicate key error

-- Drop old RLS policies
drop policy if exists scraper_terms_select_authenticated on public.scraper_search_terms;
drop policy if exists scraper_terms_write_service_role on public.scraper_search_terms;

-- Drop old trigger
drop trigger if exists set_scraper_search_terms_updated_at on public.scraper_search_terms;

-- Drop the old search_terms column
alter table public.scraper_search_terms drop column if exists search_terms;

-- Add the new search_term column (string, not array)
alter table public.scraper_search_terms 
add column if not exists search_term text not null default '';

-- Remove the old unique constraint on platform alone
alter table public.scraper_search_terms 
drop constraint if exists scraper_search_terms_platform_key;

-- Add unique constraint on (platform, search_term) to prevent duplicates
alter table public.scraper_search_terms 
add constraint scraper_search_terms_platform_term_key unique(platform, search_term);

-- Create new RLS policies for the normalized structure
create policy scraper_terms_select_authenticated
  on public.scraper_search_terms
  for select
  using (auth.role() = 'authenticated' or auth.role() = 'service_role');

create policy scraper_terms_write_service_role
  on public.scraper_search_terms
  for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Recreate trigger to auto-update updated_at on change
create trigger set_scraper_search_terms_updated_at
  before update on public.scraper_search_terms
  for each row
  execute function public.set_updated_at();



