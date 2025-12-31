-- Add support for GOAT platform in oauth_configs
-- Updates the CHECK constraint to allow 'goat' as a valid platform

-- Drop the existing constraint
ALTER TABLE oauth_configs DROP CONSTRAINT IF EXISTS oauth_configs_platform_check;

-- Add updated constraint including goat
ALTER TABLE oauth_configs ADD CONSTRAINT oauth_configs_platform_check 
  CHECK (platform IN ('thingiverse', 'ravelry', 'github', 'goat'));
