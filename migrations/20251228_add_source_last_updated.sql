-- Migration: Add source_last_updated field to products table
-- Date: 2025-12-28
-- Description: Adds a timestamp field to track when products were last updated at their source platform

-- Add source_last_updated column to products table
alter table public.products
  add column if not exists source_last_updated timestamptz;

-- Add comment to document the field
comment on column public.products.source_last_updated is 
  'Timestamp when the product was last updated at the source platform (GitHub, Ravelry, Thingiverse, etc.)';
