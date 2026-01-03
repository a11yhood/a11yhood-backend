-- Add indexes to collections table for improved query performance

-- Index for filtering collections by user (common query)
CREATE INDEX IF NOT EXISTS idx_collections_user_id ON collections(user_id);

-- Index for filtering public collections
CREATE INDEX IF NOT EXISTS idx_collections_is_public ON collections(is_public);

-- Composite index for user's collections ordered by creation (common pattern)
CREATE INDEX IF NOT EXISTS idx_collections_user_created ON collections(user_id, created_at DESC);

-- Composite index for public collections ordered by creation
CREATE INDEX IF NOT EXISTS idx_collections_public_created ON collections(is_public, created_at DESC) WHERE is_public = true;
