-- Enable Row Level Security on collections and collection_products tables

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public collections are viewable by everyone" ON collections;
DROP POLICY IF EXISTS "Users can view own collections" ON collections;
DROP POLICY IF EXISTS "Users can create own collections" ON collections;
DROP POLICY IF EXISTS "Users can update own collections" ON collections;
DROP POLICY IF EXISTS "Users can delete own collections" ON collections;
DROP POLICY IF EXISTS "Public collection products are viewable by everyone" ON collection_products;
DROP POLICY IF EXISTS "Users can view own collection products" ON collection_products;
DROP POLICY IF EXISTS "Users can add products to own collections" ON collection_products;
DROP POLICY IF EXISTS "Users can remove products from own collections" ON collection_products;

-- Enable RLS on collections table
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;

-- Enable RLS on collection_products junction table
ALTER TABLE collection_products ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view public collections
CREATE POLICY "Public collections are viewable by everyone"
ON collections FOR SELECT
USING (is_public = true);

-- Policy: Users can view their own collections (public or private)
CREATE POLICY "Users can view own collections"
ON collections FOR SELECT
USING (auth.uid()::text = user_id::text);

-- Policy: Users can create their own collections
CREATE POLICY "Users can create own collections"
ON collections FOR INSERT
WITH CHECK (auth.uid()::text = user_id::text);

-- Policy: Users can update their own collections
CREATE POLICY "Users can update own collections"
ON collections FOR UPDATE
USING (auth.uid()::text = user_id::text);

-- Policy: Users can delete their own collections
CREATE POLICY "Users can delete own collections"
ON collections FOR DELETE
USING (auth.uid()::text = user_id::text);

-- Policy: Anyone can view products in public collections
CREATE POLICY "Public collection products are viewable by everyone"
ON collection_products FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM collections
    WHERE collections.id = collection_products.collection_id
    AND collections.is_public = true
  )
);

-- Policy: Users can view products in their own collections
CREATE POLICY "Users can view own collection products"
ON collection_products FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM collections
    WHERE collections.id = collection_products.collection_id
    AND collections.user_id::text = auth.uid()::text
  )
);

-- Policy: Users can add products to their own collections
CREATE POLICY "Users can add products to own collections"
ON collection_products FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM collections
    WHERE collections.id = collection_products.collection_id
    AND collections.user_id::text = auth.uid()::text
  )
);

-- Policy: Users can remove products from their own collections
CREATE POLICY "Users can remove products from own collections"
ON collection_products FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM collections
    WHERE collections.id = collection_products.collection_id
    AND collections.user_id::text = auth.uid()::text
  )
);
