-- Add slug field to collections table for URL-friendly identifiers
-- Allows human-readable collection URLs like /collections/my-favorite-tools
-- Generates slugs from collection names with uniqueness enforcement

-- Add slug column to collections
ALTER TABLE collections ADD COLUMN IF NOT EXISTS slug TEXT;

-- Generate slugs for existing collections (kebab-case from name)
-- This handles existing data by creating slugs from names
UPDATE collections
SET slug = LOWER(REGEXP_REPLACE(REGEXP_REPLACE(name, '[^a-zA-Z0-9]+', '-', 'g'), '(^-|-$)', '', 'g'))
WHERE slug IS NULL;

-- Add uniqueness constraint after populating slugs
-- Handle duplicates by appending row number
WITH numbered_collections AS (
  SELECT id, slug,
    ROW_NUMBER() OVER (PARTITION BY slug ORDER BY created_at) as rn
  FROM collections
)
UPDATE collections c
SET slug = CONCAT(nc.slug, '-', nc.rn)
FROM numbered_collections nc
WHERE c.id = nc.id AND nc.rn > 1;

-- Now add the unique constraint and NOT NULL
-- The UNIQUE constraint automatically creates an index
ALTER TABLE collections ALTER COLUMN slug SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_collections_slug ON collections(slug);
