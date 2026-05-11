-- Migration: Drop legacy URL image columns after FK rollout
-- Date: 2026-05-09
--
-- Keeps per-record alt text columns on products/blog_posts and removes only
-- URL payload columns now replaced by image_id/header_image_id.

-- Safety backfill: ensure products.image_id is populated from legacy products.image if still missing.
UPDATE public.products p
SET image_id = i.id
FROM public.images i
WHERE p.image_id IS NULL
  AND p.image IS NOT NULL
  AND btrim(p.image) <> ''
  AND i.canonical_key = CASE
      WHEN p.image ILIKE 'data:%' THEN
          'uploaded:' || md5(COALESCE(NULLIF(split_part(p.image, ',', 2), ''), p.image))
      ELSE
          'external:' || md5(p.image)
  END;

-- Safety backfill: ensure blog_posts.header_image_id is populated from legacy blog_posts.header_image.
UPDATE public.blog_posts b
SET header_image_id = i.id
FROM public.images i
WHERE b.header_image_id IS NULL
  AND b.header_image IS NOT NULL
  AND btrim(b.header_image) <> ''
  AND i.canonical_key = CASE
      WHEN b.header_image ILIKE 'data:%' THEN
          'uploaded:' || md5(COALESCE(NULLIF(split_part(b.header_image, ',', 2), ''), b.header_image))
      ELSE
          'external:' || md5(b.header_image)
  END;

ALTER TABLE public.products
  DROP COLUMN IF EXISTS image;

ALTER TABLE public.blog_posts
  DROP COLUMN IF EXISTS header_image;
