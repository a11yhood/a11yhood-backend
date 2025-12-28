-- Indexes to speed product filtering and search operations
CREATE INDEX IF NOT EXISTS idx_products_type ON products(type);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_banned_all ON products(banned);
CREATE INDEX IF NOT EXISTS idx_products_source_rating ON products(source_rating);
CREATE INDEX IF NOT EXISTS idx_product_tags_product ON product_tags(product_id);
CREATE INDEX IF NOT EXISTS idx_product_tags_tag ON product_tags(tag_id);

-- Enable trigram search for text columns (safe no-op if already present)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- GIN trigram indexes for name/description to support ILIKE search without overlong rows
CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON products USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_description_trgm ON products USING gin (description gin_trgm_ops);
