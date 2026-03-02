-- Add featured column to tags table
-- This allows tags to be marked as "featured" to highlight high-quality product sets
-- (e.g., for display on the home page)

ALTER TABLE public.tags
  ADD COLUMN IF NOT EXISTS featured BOOLEAN NOT NULL DEFAULT FALSE;

-- Index for efficient querying of featured tags
CREATE INDEX IF NOT EXISTS idx_tags_featured ON public.tags (featured) WHERE featured = TRUE;

-- Tags: readable by all; admins can manage featured status
DROP POLICY IF EXISTS tags_select_all ON public.tags;
CREATE POLICY tags_select_all
  ON public.tags FOR SELECT
  TO authenticated, anon
  USING (true);

DROP POLICY IF EXISTS tags_admin_write ON public.tags;
CREATE POLICY tags_admin_write
  ON public.tags FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
