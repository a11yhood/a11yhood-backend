-- Add 'goat' platform to oauth_configs platform check constraint
-- This allows saving OAuth credentials for LibraryThing (GOAT) scraper

-- Drop the old constraint
ALTER TABLE oauth_configs DROP CONSTRAINT IF EXISTS oauth_configs_platform_check;

-- Add the new constraint with 'goat' included
ALTER TABLE oauth_configs ADD CONSTRAINT oauth_configs_platform_check 
  CHECK (platform IN ('thingiverse', 'ravelry', 'github', 'goat'));
