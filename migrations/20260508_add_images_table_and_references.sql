-- Migration: Add canonical images table and reference columns for products/blog_posts
-- Date: 2026-05-08
--
-- Goals:
--  1. Keep existing API fields (products.image, blog_posts.header_image) as URL strings.
--  2. Add normalized image references via images.id for dedupe/reuse/metadata.
--  3. Backfill existing product/blog image URLs into images and set FK columns.

CREATE TABLE IF NOT EXISTS public.images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_url TEXT NOT NULL UNIQUE,
    source_kind TEXT NOT NULL DEFAULT 'external' CHECK (source_kind IN ('external', 'uploaded')),
    mime_type TEXT,
    byte_size INTEGER,
    width INTEGER,
    height INTEGER,
    default_alt TEXT,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

  ALTER TABLE IF EXISTS public.images ENABLE ROW LEVEL SECURITY;

  DROP POLICY IF EXISTS images_select_all ON public.images;
  CREATE POLICY images_select_all
  ON public.images FOR SELECT
  TO authenticated, anon
  USING (true);

  DROP POLICY IF EXISTS images_admin_write ON public.images;
  CREATE POLICY images_admin_write
  ON public.images FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE INDEX IF NOT EXISTS idx_images_source_kind ON public.images(source_kind);

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS image_id UUID REFERENCES public.images(id) ON DELETE SET NULL;

ALTER TABLE public.blog_posts
    ADD COLUMN IF NOT EXISTS header_image_id UUID REFERENCES public.images(id) ON DELETE SET NULL;

-- Backfill product image references.
INSERT INTO public.images (id, canonical_url, source_kind)
SELECT
    gen_random_uuid(),
    p.image,
    CASE
        WHEN p.image ILIKE 'data:%' THEN 'uploaded'
        ELSE 'external'
    END
FROM public.products p
WHERE p.image IS NOT NULL
  AND btrim(p.image) <> ''
ON CONFLICT (canonical_url) DO NOTHING;

UPDATE public.products p
SET image_id = i.id
FROM public.images i
WHERE p.image_id IS NULL
  AND p.image IS NOT NULL
  AND btrim(p.image) <> ''
  AND i.canonical_url = p.image;

-- Backfill blog post header image references.
INSERT INTO public.images (id, canonical_url, source_kind)
SELECT
    gen_random_uuid(),
    b.header_image,
    CASE
        WHEN b.header_image ILIKE 'data:%' THEN 'uploaded'
        ELSE 'external'
    END
FROM public.blog_posts b
WHERE b.header_image IS NOT NULL
  AND btrim(b.header_image) <> ''
ON CONFLICT (canonical_url) DO NOTHING;

UPDATE public.blog_posts b
SET header_image_id = i.id
FROM public.images i
WHERE b.header_image_id IS NULL
  AND b.header_image IS NOT NULL
  AND btrim(b.header_image) <> ''
  AND i.canonical_url = b.header_image;

CREATE INDEX IF NOT EXISTS idx_products_image_id ON public.products(image_id);
CREATE INDEX IF NOT EXISTS idx_blog_posts_header_image_id ON public.blog_posts(header_image_id);
