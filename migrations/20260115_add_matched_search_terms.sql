-- Add matched_search_terms to products table
-- Date: 2026-01-15
-- Description: Track which search terms/categories matched when scraping a product
-- This helps identify why a product was scraped and allows filtering of irrelevant results

-- Add matched_search_terms column as a JSONB array
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS matched_search_terms JSONB DEFAULT '[]'::jsonb;

-- Add index for querying products by search terms
CREATE INDEX IF NOT EXISTS products_matched_search_terms_idx 
ON products USING gin(matched_search_terms);

-- Add comment for documentation
COMMENT ON COLUMN products.matched_search_terms IS 
'Array of search terms or categories that matched when this product was scraped. For Ravelry: PA categories like ["mobility-aid-accessory"]. For text searches: the actual search terms used.';
