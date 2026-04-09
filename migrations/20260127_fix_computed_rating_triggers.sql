-- Fix the triggers that are referencing NEW.product_id when they should reference NEW.id
-- This fixes the error: record "new" has no field "product_id"

-- Fix update_own_computed_rating function (used by products table trigger)
CREATE OR REPLACE FUNCTION public.update_own_computed_rating()
  RETURNS trigger LANGUAGE plpgsql
  SET search_path = public
  AS $$
  BEGIN
    NEW.computed_rating := compute_product_rating(NEW.id);
    RETURN NEW;
  END;
  $$;

-- Fix update_product_computed_rating function (used by ratings table trigger)  
CREATE OR REPLACE FUNCTION public.update_product_computed_rating()
  RETURNS trigger LANGUAGE plpgsql
  SET search_path = public
  AS $$
  BEGIN
    UPDATE products SET computed_rating = compute_product_rating(NEW.product_id)
    WHERE id = NEW.product_id;
    RETURN NEW;
  END;
  $$;

COMMENT ON FUNCTION update_own_computed_rating IS 'Fixed to use NEW.id instead of NEW.product_id for products table';
COMMENT ON FUNCTION update_product_computed_rating IS 'Uses NEW.product_id for ratings table updates';
