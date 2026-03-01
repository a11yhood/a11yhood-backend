-- Performance optimizations for a11yhood backend
-- Adds missing indexes and SQL functions for aggregations

-- ============================================================================
-- INDEXES FOR BETTER QUERY PERFORMANCE
-- ============================================================================

-- Index on products.type for faster type filtering
CREATE INDEX IF NOT EXISTS idx_products_type ON products(type);

-- Index on products.source_last_updated for date filtering
CREATE INDEX IF NOT EXISTS idx_products_source_last_updated ON products(source_last_updated DESC);

-- Index on products.computed_rating for rating sorting
CREATE INDEX IF NOT EXISTS idx_products_computed_rating ON products(computed_rating DESC NULLS LAST);

-- Index on discussions.created_at for sorting
CREATE INDEX IF NOT EXISTS idx_discussions_created_at ON discussions(created_at DESC);

-- Index on blog_posts.created_at for sorting  
CREATE INDEX IF NOT EXISTS idx_blog_posts_created_at ON blog_posts(created_at DESC);

-- Composite index for products filtering (source + type + banned)
CREATE INDEX IF NOT EXISTS idx_products_filter_composite ON products(source, type, banned);

-- Index on products.name for faster text search (trigram index for ILIKE)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON products USING gin(name gin_trgm_ops);

-- Index on tags.name for faster tag search
CREATE INDEX IF NOT EXISTS idx_tags_name_trgm ON tags USING gin(name gin_trgm_ops);

-- ============================================================================
-- OPTIMIZE RLS POLICIES FOR ANONYMOUS ACCESS
-- ============================================================================

-- Allow anonymous users to read products without RLS overhead
DROP POLICY IF EXISTS "Products are viewable by everyone" ON public.products;
CREATE POLICY "Products are viewable by everyone" 
  ON products FOR SELECT 
  TO authenticated, anon
  USING (true);

-- Allow anonymous users to read discussions without RLS overhead
DROP POLICY IF EXISTS "Discussions are viewable by everyone" ON public.discussions;
CREATE POLICY "Discussions are viewable by everyone" 
  ON discussions FOR SELECT 
  TO authenticated, anon
  USING (true);

-- Optimize blog posts policy for anonymous users
DROP POLICY IF EXISTS "Published blog posts are viewable by everyone" ON public.blog_posts;
CREATE POLICY "Published blog posts viewable by anon" 
  ON blog_posts FOR SELECT
  TO anon
  USING (published = true);

CREATE POLICY "Published blog posts viewable by authenticated"
  ON blog_posts FOR SELECT
  TO authenticated
  USING (published = true OR (select auth.uid()) = author_id OR (select auth.uid()) = ANY(author_ids));

-- Allow anonymous users to read ratings
DROP POLICY IF EXISTS "Ratings are viewable by everyone" ON public.ratings;
CREATE POLICY "Ratings are viewable by everyone" 
  ON ratings FOR SELECT 
  TO authenticated, anon
  USING (true);

-- ============================================================================
-- SQL FUNCTIONS FOR AGGREGATION QUERIES
-- ============================================================================

-- Function to get product source counts (replaces pagination loop)
CREATE OR REPLACE FUNCTION get_product_source_counts()
RETURNS TABLE(source TEXT, count BIGINT)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT source, COUNT(*) as count
  FROM products
  WHERE source IS NOT NULL
  GROUP BY source
  ORDER BY source;
$$;

-- Function to get distinct product types (replaces pagination loop)
CREATE OR REPLACE FUNCTION get_product_types()
RETURNS TABLE(type TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT DISTINCT type
  FROM products
  WHERE type IS NOT NULL
  ORDER BY type;
$$;

-- Function to get filtered product tags (replaces multi-step fetch)
CREATE OR REPLACE FUNCTION get_product_tags_filtered(
  p_sources TEXT[] DEFAULT NULL,
  p_types TEXT[] DEFAULT NULL,
  p_name_search TEXT DEFAULT NULL,
  p_tag_search TEXT DEFAULT NULL,
  p_created_by UUID DEFAULT NULL,
  p_updated_since TIMESTAMPTZ DEFAULT NULL,
  p_include_banned BOOLEAN DEFAULT FALSE,
  p_limit INT DEFAULT NULL
)
RETURNS TABLE(tag_name TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  WITH matching_products AS (
    SELECT p.id
    FROM products p
    WHERE (p_sources IS NULL OR p.source = ANY(p_sources))
      AND (p_types IS NULL OR p.type = ANY(p_types))
      AND (p_name_search IS NULL OR p.name ILIKE '%' || p_name_search || '%')
      AND (p_created_by IS NULL OR p.created_by = p_created_by)
      AND (p_updated_since IS NULL OR p.source_last_updated >= p_updated_since)
      AND (p_include_banned = TRUE OR p.banned = FALSE)
  ),
  matching_tag_ids AS (
    SELECT DISTINCT pt.tag_id
    FROM product_tags pt
    INNER JOIN matching_products mp ON pt.product_id = mp.id
  )
  SELECT t.name as tag_name
  FROM tags t
  INNER JOIN matching_tag_ids mti ON t.id = mti.tag_id
  WHERE (p_tag_search IS NULL OR t.name ILIKE '%' || p_tag_search || '%')
  ORDER BY t.name
  LIMIT COALESCE(p_limit, 1000000);
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_product_source_counts() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_product_types() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_product_tags_filtered(TEXT[], TEXT[], TEXT, TEXT, UUID, TIMESTAMPTZ, BOOLEAN, INT) TO authenticated, anon;
