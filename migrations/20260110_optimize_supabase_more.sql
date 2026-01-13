--- Fixing slow queries 
CREATE INDEX ON public.products USING btree (url);

-- ============================================================================
-- Users table: Consolidate multiple SELECT and UPDATE policies
-- ============================================================================
-- Issue: Table public.users has multiple permissive policies for authenticated role
-- on SELECT and UPDATE actions, causing performance overhead.
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

-- ============================================================================
-- Function Security: Fix mutable search_path
-- ============================================================================
-- Issue: Function public.update_updated_at_column has a role mutable search_path
-- Solution: Add SET search_path = public to make it deterministic and secure
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path = public
  AS $$
  BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
  END;
  $$;

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

-- ============================================================================
-- Product URLs table: Add missing RLS policies
-- ============================================================================
-- Issue: Table public.product_urls has RLS enabled, but no policies exist
-- Solution: Add appropriate policies for SELECT, INSERT, UPDATE, and DELETE
CREATE POLICY "Product URLs are viewable by everyone"
  ON public.product_urls FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create product URLs"
  ON public.product_urls FOR INSERT
  WITH CHECK ((select auth.role()) = 'authenticated');

CREATE POLICY "Creators can update their product URLs"
  ON public.product_urls FOR UPDATE
  USING ((select auth.uid()) = created_by)
  WITH CHECK ((select auth.uid()) = created_by);

CREATE POLICY "Creators can delete their product URLs"
  ON public.product_urls FOR DELETE
  USING ((select auth.uid()) = created_by);

-- ============================================================================
-- Supported Sources table: Optimize RLS policies with auth function optimization
-- ============================================================================
-- Issue: Table public.supported_sources has RLS enabled but policies use direct
-- auth.uid() calls which can be inefficient at scale
-- Solution: Replace with optimized subquery pattern and ensure proper admin restriction

DROP POLICY IF EXISTS supported_sources_select_all ON public.supported_sources;

CREATE POLICY supported_sources_select_all
  ON public.supported_sources FOR SELECT
  USING (true);

DROP POLICY IF EXISTS supported_sources_admin_write ON public.supported_sources;

CREATE POLICY supported_sources_admin_write
  ON public.supported_sources FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
-- ============================================================================
-- Tags table: Add missing RLS policies
-- ============================================================================
-- Issue: Table public.tags has RLS enabled, but no policies exist
-- Solution: Add policies for SELECT (public read), and admin-only management

CREATE POLICY tags_select_all
  ON public.tags FOR SELECT
  USING (true);

CREATE POLICY tags_admin_write
  ON public.tags FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Issue: Product owners cannot delete tags from their own products
-- Solution: Allow creators and editors to insert and delete tags for their products

DROP POLICY IF EXISTS "Authenticated users can create product tags" ON public.product_tags;
DROP POLICY IF EXISTS "Admins can delete product tags" ON public.product_tags;

CREATE POLICY product_tags_insert_owner_or_mod
  ON public.product_tags FOR INSERT
  WITH CHECK ((select auth.role()) = 'authenticated' AND EXISTS (
    SELECT 1 FROM public.products p, public.users u
    WHERE p.id = product_id AND u.id = (select auth.uid()) AND (
      p.created_by = (select auth.uid())
      OR (select auth.uid()) = ANY(p.editor_ids)
      OR EXISTS (SELECT 1 FROM public.product_editors pe WHERE pe.product_id = p.id AND pe.user_id = (select auth.uid()))
      OR u.role IN ('admin', 'moderator')
    )
  ));

CREATE POLICY product_tags_delete_owner_mod_or_admin
  ON public.product_tags FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM public.products p, public.users u
    WHERE p.id = product_id AND u.id = (select auth.uid()) AND (
      (select auth.uid()) = p.created_by
      OR (select auth.uid()) = ANY(p.editor_ids)
      OR EXISTS (SELECT 1 FROM public.product_editors pe WHERE pe.product_id = p.id AND pe.user_id = (select auth.uid()))
      OR u.role IN ('admin', 'moderator')
    )
  ));

