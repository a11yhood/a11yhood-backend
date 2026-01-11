-- Migration: Optimize RLS policies to reduce auth function re-evaluation
-- Issue: Multiple RLS policies were re-evaluating auth.uid() and auth.role() 
-- for each row, producing suboptimal query performance at scale.
-- Solution: Replace auth.<function>() with (select auth.<function>()) to evaluate once per query.
-- Reference: https://supabase.com/docs/guides/auth/row-level-security

-- ============================================================================
-- Users table: Consolidate multiple SELECT and UPDATE policies
-- ============================================================================
-- Issue: Multiple permissive policies for authenticated role on SELECT and UPDATE actions
-- Solution: Consolidate into single optimized policies

DROP POLICY IF EXISTS users_select_self_or_admin ON public.users;
DROP POLICY IF EXISTS "Users are viewable by everyone" ON public.users;

CREATE POLICY users_select_self_or_admin
  ON public.users FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = id OR public.is_admin());

DROP POLICY IF EXISTS users_update_self_or_admin ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;

CREATE POLICY users_update_self_or_admin
  ON public.users FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = id OR public.is_admin())
  WITH CHECK ((select auth.uid()) = id OR public.is_admin());

DROP POLICY IF EXISTS users_insert_authenticated ON public.users;

CREATE POLICY users_insert_authenticated
  ON public.users FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = id);

-- ============================================================================
-- Products table: Optimize "Authenticated users can create products" policy
-- ============================================================================
DROP POLICY IF EXISTS "Authenticated users can create products" ON public.products;

CREATE POLICY "Authenticated users can create products" 
  ON public.products FOR INSERT 
  WITH CHECK ((select auth.role()) = 'authenticated');

DROP POLICY IF EXISTS "Admins can delete products" ON public.products;

CREATE POLICY "Admins can delete products" 
  ON public.products FOR DELETE 
  USING (EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role = 'admin'));

-- ============================================================================
-- Ratings table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Authenticated users can create ratings" ON public.ratings;

CREATE POLICY "Authenticated users can create ratings" 
  ON public.ratings FOR INSERT 
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own ratings" ON public.ratings;

CREATE POLICY "Users can update own ratings" 
  ON public.ratings FOR UPDATE 
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete own ratings" ON public.ratings;

CREATE POLICY "Users can delete own ratings" 
  ON public.ratings FOR DELETE 
  USING ((select auth.uid()) = user_id);

-- ============================================================================
-- Discussions table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Authenticated users can create discussions" ON public.discussions;

CREATE POLICY "Authenticated users can create discussions" 
  ON public.discussions FOR INSERT 
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own discussions or admins/mods can moderate" ON public.discussions;

CREATE POLICY "Users can update own discussions or admins/mods can moderate" 
  ON public.discussions FOR UPDATE 
  USING (
    (select auth.uid()) = user_id OR 
    EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator'))
  );

DROP POLICY IF EXISTS "Users can delete own discussions or admins/mods can delete any" ON public.discussions;

CREATE POLICY "Users can delete own discussions or admins/mods can delete any" 
  ON public.discussions FOR DELETE 
  USING (
    (select auth.uid()) = user_id OR 
    EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator'))
  );

-- ============================================================================
-- Blog Posts table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Admins can create blog posts" ON public.blog_posts;

CREATE POLICY "Admins can create blog posts" 
  ON public.blog_posts FOR INSERT 
  WITH CHECK (EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator')));

DROP POLICY IF EXISTS "Authors and admins can update blog posts" ON public.blog_posts;

CREATE POLICY "Authors and admins can update blog posts" 
  ON public.blog_posts FOR UPDATE 
  USING (
    (select auth.uid()) = author_id OR 
    (select auth.uid()) = ANY(author_ids) OR
    EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role = 'admin')
  );

DROP POLICY IF EXISTS "Admins can delete blog posts" ON public.blog_posts;

CREATE POLICY "Admins can delete blog posts" 
  ON public.blog_posts FOR DELETE 
  USING (EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role = 'admin'));

-- ============================================================================
-- Collections table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Authenticated users can create collections" ON public.collections;

CREATE POLICY "Authenticated users can create collections" 
  ON public.collections FOR INSERT 
  WITH CHECK ((select auth.uid()) = user_id);

-- ============================================================================
-- User Activities table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Users can view own activities" ON public.user_activities;

CREATE POLICY "Users can view own activities" 
  ON public.user_activities FOR SELECT 
  USING (
    (select auth.uid()) = user_id OR 
    EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator'))
  );

-- ============================================================================
-- Scraping Logs table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Admins can view scraping logs" ON public.scraping_logs;

CREATE POLICY "Admins can view scraping logs" 
  ON public.scraping_logs FOR SELECT 
  USING (EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator')));

-- ============================================================================
-- Product Tags table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Authenticated users can create product tags" ON public.product_tags;

CREATE POLICY "Authenticated users can create product tags" 
  ON public.product_tags FOR INSERT 
  WITH CHECK ((select auth.role()) = 'authenticated');

-- ============================================================================
-- User Requests table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Users can view own requests and admins can view all" ON public.user_requests;

CREATE POLICY "Users can view own requests and admins can view all" 
  ON public.user_requests FOR SELECT 
  USING (
    (select auth.uid()) = user_id OR 
    EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator'))
  );

DROP POLICY IF EXISTS "Authenticated users can create requests" ON public.user_requests;

CREATE POLICY "Authenticated users can create requests" 
  ON public.user_requests FOR INSERT 
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Admins can update user requests" ON public.user_requests;

CREATE POLICY "Admins can update user requests" 
  ON public.user_requests FOR UPDATE 
  USING (EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator')));

-- ============================================================================
-- Product Editors table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Admins can manage product managers" ON public.product_editors;

CREATE POLICY "Admins can manage product managers" 
  ON public.product_editors FOR ALL 
  USING (EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator')))
  WITH CHECK (EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator')));

-- ============================================================================
-- OAuth Configs table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Admins can view oauth configs" ON public.oauth_configs;

CREATE POLICY "Admins can view oauth configs" 
  ON public.oauth_configs FOR SELECT 
  USING (EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator')));

-- ============================================================================
-- Product Tags table: Optimize "Admins can delete product tags" policy
-- ============================================================================
DROP POLICY IF EXISTS "Admins can delete product tags" ON public.product_tags;

CREATE POLICY "Admins can delete product tags" 
  ON public.product_tags FOR DELETE 
  USING (EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role = 'admin'));

-- ============================================================================
-- Scraper Search Terms table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS scraper_terms_select_authenticated ON public.scraper_search_terms;
DROP POLICY IF EXISTS "Authenticated users can view scraper search terms" ON public.scraper_search_terms;

CREATE POLICY "Authenticated users can view scraper search terms" 
  ON public.scraper_search_terms FOR SELECT 
  USING ((select auth.role()) = 'authenticated' OR (select auth.role()) = 'service_role');

DROP POLICY IF EXISTS scraper_terms_write_service_role ON public.scraper_search_terms;
DROP POLICY IF EXISTS "Admins can manage scraper search terms" ON public.scraper_search_terms;

CREATE POLICY "Admins can manage scraper search terms" 
  ON public.scraper_search_terms FOR ALL 
  USING ((select auth.role()) = 'service_role')
  WITH CHECK ((select auth.role()) = 'service_role');

-- ============================================================================
-- Collections table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Users can view own collections" ON public.collections;

CREATE POLICY "Users can view own collections" 
  ON public.collections FOR SELECT 
  USING ((select auth.uid())::text = user_id::text);

DROP POLICY IF EXISTS "Users can create own collections" ON public.collections;

CREATE POLICY "Users can create own collections" 
  ON public.collections FOR INSERT 
  WITH CHECK ((select auth.uid())::text = user_id::text);

DROP POLICY IF EXISTS "Users can update own collections" ON public.collections;

CREATE POLICY "Users can update own collections" 
  ON public.collections FOR UPDATE 
  USING ((select auth.uid())::text = user_id::text);

DROP POLICY IF EXISTS "Users can delete own collections" ON public.collections;

CREATE POLICY "Users can delete own collections" 
  ON public.collections FOR DELETE 
  USING ((select auth.uid())::text = user_id::text);

-- ============================================================================
-- Collections table: Consolidate multiple SELECT policies
-- ============================================================================
-- Issue: Multiple permissive SELECT policies on collections were causing
-- each policy to be executed for every query. Combining them improves performance.
DROP POLICY IF EXISTS "Public collections are viewable by everyone" ON public.collections;
DROP POLICY IF EXISTS "Users can view own collections" ON public.collections;

CREATE POLICY "Collections viewable by public or owner" 
  ON public.collections FOR SELECT 
  USING (is_public = true OR (select auth.uid())::text = user_id::text);

-- ============================================================================
-- Collections table: Consolidate multiple INSERT policies
-- ============================================================================
DROP POLICY IF EXISTS "Authenticated users can create collections" ON public.collections;
DROP POLICY IF EXISTS "Users can create own collections" ON public.collections;

CREATE POLICY "Authenticated users can create collections" 
  ON public.collections FOR INSERT 
  WITH CHECK ((select auth.uid())::text = user_id::text);

-- ============================================================================
-- Product Editors table: Optimize SELECT policy and update ALL policy
-- ============================================================================
-- Note: "Product managers are viewable by everyone" uses USING (true) which is already optimal
-- Only updating the ALL policy to use optimized auth function evaluation
DROP POLICY IF EXISTS "Admins can manage product managers" ON public.product_editors;

CREATE POLICY "Admins can manage product managers" 
  ON public.product_editors FOR ALL 
  USING (EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator')))
  WITH CHECK (EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator')));

-- ============================================================================
-- Collection Products table: Optimize RLS policies
-- ============================================================================
DROP POLICY IF EXISTS "Users can view own collection products" ON public.collection_products;

CREATE POLICY "Users can view own collection products" 
  ON public.collection_products FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM collections
      WHERE collections.id = collection_products.collection_id
      AND collections.user_id::text = (select auth.uid())::text
    )
  );

DROP POLICY IF EXISTS "Users can add products to own collections" ON public.collection_products;

CREATE POLICY "Users can add products to own collections" 
  ON public.collection_products FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM collections
      WHERE collections.id = collection_products.collection_id
      AND collections.user_id::text = (select auth.uid())::text
    )
  );

DROP POLICY IF EXISTS "Users can remove products from own collections" ON public.collection_products;

CREATE POLICY "Users can remove products from own collections" 
  ON public.collection_products FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM collections
      WHERE collections.id = collection_products.collection_id
      AND collections.user_id::text = (select auth.uid())::text
    )
  );

-- ============================================================================
-- Products table: Optimize "Users can update own products or admins can update all" policy
-- ============================================================================
DROP POLICY IF EXISTS "Users can update own products or admins can update all" ON public.products;

CREATE POLICY "Users can update own products or admins can update all" 
  ON public.products FOR UPDATE 
  USING (
    (select auth.uid()) = created_by OR 
    (select auth.uid()) = ANY(editor_ids) OR
    EXISTS (SELECT 1 FROM users WHERE id = (select auth.uid()) AND role IN ('admin', 'moderator'))
  );

- ============================================================================
-- Collection Products table: Combine multiple SELECT policies into single optimized policy
-- ============================================================================
-- Issue: Multiple permissive SELECT policies on collection_products were causing
-- each policy to be executed for every query. Combining them improves performance.
DROP POLICY IF EXISTS "Public collection products are viewable by everyone" ON public.collection_products;
DROP POLICY IF EXISTS "Users can view own collection products" ON public.collection_products;

CREATE POLICY "Collection products viewable by everyone or own collection users" 
  ON public.collection_products FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM collections
      WHERE collections.id = collection_products.collection_id
      AND (
        collections.is_public = true OR
        collections.user_id::text = (select auth.uid())::text
      )
    )
  );

-- ============================================================================
-- Index Cleanup: Remove duplicate identical indexes
-- ============================================================================
-- Issue: Table public.collections has identical indexes idx_collections_user and idx_collections_user_id
-- both indexing the same column (user_id). Keep idx_collections_user, drop idx_collections_user_id.
DROP INDEX IF EXISTS idx_collections_user_id;

-- Issue: Table public.ratings has identical indexes idx_ratings_product and idx_ratings_product_id
-- both indexing the same column (product_id). Keep idx_ratings_product, drop idx_ratings_product_id.
DROP INDEX IF EXISTS idx_ratings_product_id;

-- Issue: Table public.users has identical indexes users_username_idx and users_username_key
-- both indexing the same column (username). The UNIQUE constraint creates users_username_key implicitly,
-- so drop the explicit users_username_idx to avoid redundancy.
DROP INDEX IF EXISTS users_username_idx;

-- ============================================================================
-- Function Security: Fix mutable search_path
-- ============================================================================
-- Issue: Function public.is_admin has a role mutable search_path
-- Solution: Add SET search_path = public to make it deterministic and secure
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
  LANGUAGE sql STABLE
  SET search_path = public
  AS $$
    SELECT EXISTS(
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    );
  $$;

-- Fix prevent_non_admin_role_change function
CREATE OR REPLACE FUNCTION public.prevent_non_admin_role_change()
  RETURNS trigger LANGUAGE plpgsql
  SET search_path = public
  AS $$
  BEGIN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can change roles';
      END IF;
    END IF;
    RETURN NEW;
  END;
  $$;

-- Fix set_updated_at function
CREATE OR REPLACE FUNCTION public.set_updated_at()
  RETURNS trigger LANGUAGE plpgsql
  SET search_path = public
  AS $$
  BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
  END;
  $$;

-- Fix compute_product_rating function
CREATE OR REPLACE FUNCTION public.compute_product_rating(product_id_param UUID)
  RETURNS NUMERIC(3,2) LANGUAGE plpgsql
  SET search_path = public
  AS $$
  DECLARE
    user_avg NUMERIC(3,2);
    source_rating_val NUMERIC(3,2);
    display_rating NUMERIC(3,2);
  BEGIN
    SELECT AVG(rating)::NUMERIC(3,2) INTO user_avg
    FROM ratings
    WHERE product_id = product_id_param;
    
    SELECT source_rating INTO source_rating_val
    FROM products
    WHERE id = product_id_param;
    
    IF user_avg IS NOT NULL THEN
      display_rating := user_avg;
    ELSIF source_rating_val IS NOT NULL THEN
      display_rating := source_rating_val;
    ELSE
      display_rating := NULL;
    END IF;
    
    RETURN display_rating;
  END;
  $$;

-- Fix update_product_computed_rating function
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

-- Fix update_own_computed_rating function
CREATE OR REPLACE FUNCTION public.update_own_computed_rating()
  RETURNS trigger LANGUAGE plpgsql
  SET search_path = public
  AS $$
  BEGIN
    UPDATE products SET computed_rating = compute_product_rating(NEW.product_id)
    WHERE id = NEW.product_id;
    RETURN NEW;
  END;
  $$;

-- ============================================================================
-- Extension Management: Move pg_trgm to extensions schema
-- ============================================================================
-- Issue: Extension pg_trgm is installed in the public schema
-- Solution: Move it to a dedicated extensions schema to keep public schema clean
-- Create extensions schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS extensions;

-- Drop pg_trgm from public schema and recreate in extensions schema
DROP EXTENSION IF EXISTS pg_trgm CASCADE;

-- Recreate pg_trgm in extensions schema
CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA extensions;

-- ============================================================================
-- Scraping Logs table: Fix RLS policy that bypasses security
-- ============================================================================
-- Issue: "System can create scraping logs" policy has WITH CHECK (true) which allows
-- unrestricted INSERT access, effectively bypassing row-level security.
-- Solution: Restrict INSERT to service_role only
DROP POLICY IF EXISTS "System can create scraping logs" ON public.scraping_logs;

CREATE POLICY "System can create scraping logs" 
  ON public.scraping_logs FOR INSERT 
  WITH CHECK ((select auth.role()) = 'service_role');

-- ============================================================================
-- User Activities table: Fix RLS policy that bypasses security
-- ============================================================================
-- Issue: "System can create user activities" policy has WITH CHECK (true) which allows
-- unrestricted INSERT access, effectively bypassing row-level security.
-- Solution: Restrict INSERT to service_role only
DROP POLICY IF EXISTS "System can create user activities" ON public.user_activities;

CREATE POLICY "System can create user activities" 
  ON public.user_activities FOR INSERT 
  WITH CHECK ((select auth.role()) = 'service_role');

