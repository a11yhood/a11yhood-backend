-- Backfill source_rating for GitHub products based on source_rating_count
-- Using the same normalization logic as the GitHub scraper:
-- 100,000+ stars = 5, 10,000+ = 4, 1,000+ = 3, 100+ = 2, 10+ = 1, ≤10 = NULL

UPDATE products
SET source_rating = CASE
  WHEN source_rating_count > 100000 THEN 5.0
  WHEN source_rating_count > 10000 THEN 4.0
  WHEN source_rating_count > 1000 THEN 3.0
  WHEN source_rating_count > 100 THEN 2.0
  WHEN source_rating_count > 10 THEN 1.0
  ELSE NULL
END
WHERE source = 'GitHub'
  AND source_rating IS NULL
  AND source_rating_count IS NOT NULL;

-- Now recompute computed_rating for all products that were updated
UPDATE products
SET computed_rating = compute_product_rating(id)
WHERE source = 'GitHub'
  AND source_rating IS NOT NULL;

COMMENT ON COLUMN products.source_rating IS 'Normalized rating from source (1-5 scale for GitHub based on star count)';
