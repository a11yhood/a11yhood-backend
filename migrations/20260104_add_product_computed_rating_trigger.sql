-- Add trigger to automatically set computed_rating when products are created or source_rating changes

-- Function to update computed_rating for the current product row
CREATE OR REPLACE FUNCTION update_own_computed_rating()
RETURNS TRIGGER AS $$
BEGIN
  -- Compute and set the rating directly on the NEW row
  NEW.computed_rating := compute_product_rating(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update computed_rating when products are inserted or source_rating is updated
DROP TRIGGER IF EXISTS trg_product_set_computed_rating ON products;
CREATE TRIGGER trg_product_set_computed_rating
BEFORE INSERT OR UPDATE OF source_rating ON products
FOR EACH ROW
EXECUTE FUNCTION update_own_computed_rating();

COMMENT ON TRIGGER trg_product_set_computed_rating ON products IS 'Automatically sets computed_rating when products are created or source_rating changes';
