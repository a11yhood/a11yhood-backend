-- Add computed rating column to products for efficient sorting
-- This stores the display_rating (combination of user ratings and source ratings)
-- Updated via trigger whenever ratings change

-- Add the column
ALTER TABLE products 
  ADD COLUMN IF NOT EXISTS computed_rating NUMERIC(3,2);

-- Create index for efficient sorting
CREATE INDEX IF NOT EXISTS idx_products_computed_rating ON products(computed_rating DESC NULLS LAST);

-- Function to compute display rating for a product
CREATE OR REPLACE FUNCTION compute_product_rating(product_id_param UUID)
RETURNS NUMERIC(3,2) AS $$
DECLARE
  user_avg NUMERIC(3,2);
  source_rating_val NUMERIC(3,2);
  display_rating NUMERIC(3,2);
BEGIN
  -- Get average user rating
  SELECT AVG(rating)::NUMERIC(3,2) INTO user_avg
  FROM ratings
  WHERE product_id = product_id_param;
  
  -- Get source rating
  SELECT source_rating INTO source_rating_val
  FROM products
  WHERE id = product_id_param;
  
  -- Compute display rating (prefer user rating, fall back to source rating)
  IF user_avg IS NOT NULL THEN
    display_rating := user_avg;
  ELSE
    display_rating := source_rating_val;
  END IF;
  
  RETURN display_rating;
END;
$$ LANGUAGE plpgsql;

-- Function to update computed_rating when ratings change
CREATE OR REPLACE FUNCTION update_product_computed_rating()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the product's computed rating
  UPDATE products
  SET computed_rating = compute_product_rating(
    CASE 
      WHEN TG_OP = 'DELETE' THEN OLD.product_id
      ELSE NEW.product_id
    END
  )
  WHERE id = CASE 
    WHEN TG_OP = 'DELETE' THEN OLD.product_id
    ELSE NEW.product_id
  END;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update computed_rating when ratings are inserted, updated, or deleted
DROP TRIGGER IF EXISTS trg_rating_update_computed_rating ON ratings;
CREATE TRIGGER trg_rating_update_computed_rating
AFTER INSERT OR UPDATE OR DELETE ON ratings
FOR EACH ROW
EXECUTE FUNCTION update_product_computed_rating();

-- Initialize computed_rating for all existing products
UPDATE products
SET computed_rating = compute_product_rating(id);

COMMENT ON COLUMN products.computed_rating IS 'Computed display rating (user average or source rating) for efficient sorting';
