-- Create junction table for collection-product many-to-many relationship
-- Replaces the product_ids array in collections table

-- Create the junction table
CREATE TABLE IF NOT EXISTS collection_products (
    collection_id UUID NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    position INTEGER DEFAULT 0,
    PRIMARY KEY (collection_id, product_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_collection_products_collection_id ON collection_products(collection_id);
CREATE INDEX IF NOT EXISTS idx_collection_products_product_id ON collection_products(product_id);
CREATE INDEX IF NOT EXISTS idx_collection_products_position ON collection_products(collection_id, position);

-- Migrate existing data from product_ids array to junction table
INSERT INTO collection_products (collection_id, product_id, position)
SELECT 
    c.id as collection_id,
    unnest(c.product_ids)::uuid as product_id,
    generate_series(1, array_length(c.product_ids, 1)) as position
FROM collections c
WHERE c.product_ids IS NOT NULL 
  AND array_length(c.product_ids, 1) > 0
ON CONFLICT (collection_id, product_id) DO NOTHING;

-- Remove the product_ids column from collections table
ALTER TABLE collections DROP COLUMN IF EXISTS product_ids;

-- Add comment for documentation
COMMENT ON TABLE collection_products IS 'Junction table for many-to-many relationship between collections and products';
