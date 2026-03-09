-- Backfill GitHub source_rating using logarithmic mapping from source_rating_count.
--
-- Mapping formula (same as scraper logic):
--   source_rating = round(clamp(log10(star_count), 1.0, 5.0), 2)
--   star_count = 0 -> source_rating = NULL
--
-- This migration is idempotent and only updates rows whose source_rating changes.

WITH recalculated AS (
  SELECT
    id,
    CASE
      WHEN source_rating_count > 0 THEN ROUND(
        LEAST(
          GREATEST(LOG(10, source_rating_count::numeric), 1.0),
          5.0
        ),
        2
      )
      ELSE NULL
    END AS new_source_rating
  FROM products
  WHERE source = 'GitHub'
    AND source_rating_count IS NOT NULL
),
updated_rows AS (
  UPDATE products p
  SET source_rating = r.new_source_rating
  FROM recalculated r
  WHERE p.id = r.id
    AND p.source_rating IS DISTINCT FROM r.new_source_rating
  RETURNING p.id
)
UPDATE products p
SET computed_rating = compute_product_rating(p.id)
WHERE p.id IN (SELECT id FROM updated_rows);
