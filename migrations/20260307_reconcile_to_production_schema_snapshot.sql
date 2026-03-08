-- Migration: Reconcile schema, policies, triggers, and indexes to production snapshot
-- Date: 2026-03-07
-- Source of truth: "Supabase Snippet Users & Products Schema with RLS and Admin Role Enforcement*.csv"

-- ============================================================================
-- Products / Ratings schema alignment
-- ============================================================================
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS source_url text;

UPDATE public.products
SET source_url = url
WHERE source_url IS NULL AND url IS NOT NULL;

ALTER TABLE public.products ALTER COLUMN description DROP NOT NULL;
ALTER TABLE public.products ALTER COLUMN description SET DEFAULT ''::text;

ALTER TABLE public.ratings DROP COLUMN IF EXISTS owned;

-- ============================================================================
-- Index alignment
-- ============================================================================
ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_url_key;
CREATE UNIQUE INDEX IF NOT EXISTS products_url_key ON public.products USING btree (source_url);

CREATE INDEX IF NOT EXISTS products_url_idx ON public.products USING btree (url);
CREATE INDEX IF NOT EXISTS products_url_idx1 ON public.products USING btree (url);
CREATE INDEX IF NOT EXISTS products_matched_search_terms_idx ON public.products USING gin (matched_search_terms);
CREATE INDEX IF NOT EXISTS idx_collections_slug_lookup ON public.collections USING btree (slug);

ALTER TABLE public.collections DROP CONSTRAINT IF EXISTS collections_slug_key;
DROP INDEX IF EXISTS idx_product_urls_creator;
DROP INDEX IF EXISTS idx_product_urls_product;

-- ============================================================================
-- Trigger alignment
-- ============================================================================
DROP TRIGGER IF EXISTS update_product_urls_updated_at ON public.product_urls;
DROP TRIGGER IF EXISTS update_scraper_search_terms_updated_at ON public.scraper_search_terms;

-- ============================================================================
-- Collections policies (match production names/logic)
-- ============================================================================
DROP POLICY IF EXISTS "Collections viewable by public or owner" ON public.collections;
DROP POLICY IF EXISTS "Public collections are viewable by everyone" ON public.collections;
DROP POLICY IF EXISTS "Users can view own collections" ON public.collections;
DROP POLICY IF EXISTS "Authenticated users can create collections" ON public.collections;
DROP POLICY IF EXISTS "Users can create own collections" ON public.collections;
DROP POLICY IF EXISTS "Users can update own collections" ON public.collections;
DROP POLICY IF EXISTS "Users can delete own collections" ON public.collections;

CREATE POLICY "Public collections are viewable by everyone"
  ON public.collections FOR SELECT
  USING (is_public = true);

CREATE POLICY "Users can view own collections"
  ON public.collections FOR SELECT
  USING ((auth.uid())::text = (user_id)::text);

CREATE POLICY "Authenticated users can create collections"
  ON public.collections FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can create own collections"
  ON public.collections FOR INSERT
  WITH CHECK ((auth.uid())::text = (user_id)::text);

CREATE POLICY "Users can update own collections"
  ON public.collections FOR UPDATE
  USING ((auth.uid())::text = (user_id)::text);

CREATE POLICY "Users can delete own collections"
  ON public.collections FOR DELETE
  USING ((auth.uid())::text = (user_id)::text);

-- ============================================================================
-- Collection products policies (match production names/logic)
-- ============================================================================
DROP POLICY IF EXISTS "Collection products viewable by everyone or own collection users" ON public.collection_products;
DROP POLICY IF EXISTS "Public collection products are viewable by everyone" ON public.collection_products;
DROP POLICY IF EXISTS "Users can view own collection products" ON public.collection_products;
DROP POLICY IF EXISTS "Users can add products to own collections" ON public.collection_products;
DROP POLICY IF EXISTS "Users can remove products from own collections" ON public.collection_products;

CREATE POLICY "Public collection products are viewable by everyone"
  ON public.collection_products FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM collections
      WHERE collections.id = collection_products.collection_id
        AND collections.is_public = true
    )
  );

CREATE POLICY "Users can view own collection products"
  ON public.collection_products FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM collections
      WHERE collections.id = collection_products.collection_id
        AND (collections.user_id)::text = (auth.uid())::text
    )
  );

CREATE POLICY "Users can add products to own collections"
  ON public.collection_products FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM collections
      WHERE collections.id = collection_products.collection_id
        AND (collections.user_id)::text = (auth.uid())::text
    )
  );

CREATE POLICY "Users can remove products from own collections"
  ON public.collection_products FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM collections
      WHERE collections.id = collection_products.collection_id
        AND (collections.user_id)::text = (auth.uid())::text
    )
  );

-- ============================================================================
-- Product tags policies (match production owner/mod/admin behavior)
-- ============================================================================
DROP POLICY IF EXISTS "Authenticated users can create product tags" ON public.product_tags;
DROP POLICY IF EXISTS "Admins can delete product tags" ON public.product_tags;
DROP POLICY IF EXISTS product_tags_insert_owner_or_mod ON public.product_tags;
DROP POLICY IF EXISTS product_tags_delete_owner_mod_or_admin ON public.product_tags;
DROP POLICY IF EXISTS "Product tags are viewable by everyone" ON public.product_tags;

CREATE POLICY "Product tags are viewable by everyone"
  ON public.product_tags FOR SELECT
  USING (true);

CREATE POLICY product_tags_insert_owner_or_mod
  ON public.product_tags FOR INSERT
  WITH CHECK (
    ((SELECT auth.role() AS role) = 'authenticated'::text)
    AND EXISTS (
      SELECT 1
      FROM public.products p, public.users u
      WHERE p.id = product_tags.product_id
        AND u.id = (SELECT auth.uid() AS uid)
        AND (
          p.created_by = (SELECT auth.uid() AS uid)
          OR (SELECT auth.uid() AS uid) = ANY (p.editor_ids)
          OR EXISTS (
            SELECT 1
            FROM public.product_editors pe
            WHERE pe.product_id = p.id
              AND pe.user_id = (SELECT auth.uid() AS uid)
          )
          OR u.role = ANY (ARRAY['admin'::text, 'moderator'::text])
        )
    )
  );

CREATE POLICY product_tags_delete_owner_mod_or_admin
  ON public.product_tags FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM public.products p, public.users u
      WHERE p.id = product_tags.product_id
        AND u.id = (SELECT auth.uid() AS uid)
        AND (
          (SELECT auth.uid() AS uid) = p.created_by
          OR (SELECT auth.uid() AS uid) = ANY (p.editor_ids)
          OR EXISTS (
            SELECT 1
            FROM public.product_editors pe
            WHERE pe.product_id = p.id
              AND pe.user_id = (SELECT auth.uid() AS uid)
          )
          OR u.role = ANY (ARRAY['admin'::text, 'moderator'::text])
        )
    )
  );

-- ============================================================================
-- Scraper search terms policies (keep legacy policy names used in production)
-- ============================================================================
DROP POLICY IF EXISTS "Admins can manage scraper search terms" ON public.scraper_search_terms;
DROP POLICY IF EXISTS "Authenticated users can view scraper search terms" ON public.scraper_search_terms;
DROP POLICY IF EXISTS scraper_terms_select_authenticated ON public.scraper_search_terms;
DROP POLICY IF EXISTS scraper_terms_write_service_role ON public.scraper_search_terms;

CREATE POLICY scraper_terms_select_authenticated
  ON public.scraper_search_terms
  FOR SELECT
  USING ((auth.role() = 'authenticated'::text) OR (auth.role() = 'service_role'::text));

CREATE POLICY scraper_terms_write_service_role
  ON public.scraper_search_terms
  FOR ALL
  USING (auth.role() = 'service_role'::text)
  WITH CHECK (auth.role() = 'service_role'::text);

-- ============================================================================
-- Misc policy alignment from production snapshot
-- ============================================================================
DROP POLICY IF EXISTS "Admins can update user roles" ON public.users;
CREATE POLICY "Admins can update user roles"
  ON public.users FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS supported_sources_select_all ON public.supported_sources;
CREATE POLICY supported_sources_select_all
  ON public.supported_sources FOR SELECT
  USING (true);

DROP POLICY IF EXISTS tags_select_all ON public.tags;
DROP POLICY IF EXISTS tags_admin_write ON public.tags;

CREATE POLICY tags_select_all
  ON public.tags FOR SELECT
  USING (true);

CREATE POLICY tags_admin_write
  ON public.tags FOR ALL
  TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

DROP POLICY IF EXISTS "System can create scraping logs" ON public.scraping_logs;
CREATE POLICY "System can create scraping logs"
  ON public.scraping_logs FOR INSERT
  WITH CHECK ((SELECT auth.role() AS role) = 'service_role'::text);

DROP POLICY IF EXISTS "System can create user activities" ON public.user_activities;
CREATE POLICY "System can create user activities"
  ON public.user_activities FOR INSERT
  WITH CHECK ((SELECT auth.role() AS role) = 'service_role'::text);
