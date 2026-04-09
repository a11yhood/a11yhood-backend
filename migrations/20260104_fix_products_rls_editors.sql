-- Fix products update RLS to honor product_editors (slug-safe editing)
-- Allows update when user is creator, listed in product_editors, or an admin/moderator.

DROP POLICY IF EXISTS "Users can update own products or admins can update all" ON public.products;

CREATE POLICY "Users can update own products or admins can update all"
ON public.products FOR UPDATE
TO authenticated
USING (
  auth.uid() = created_by OR
  EXISTS (
    SELECT 1 FROM public.product_editors pe
    WHERE pe.product_id = products.id AND pe.user_id = auth.uid()
  ) OR
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND u.role IN ('admin', 'moderator')
  )
)
WITH CHECK (
  auth.uid() = created_by OR
  EXISTS (
    SELECT 1 FROM public.product_editors pe
    WHERE pe.product_id = products.id AND pe.user_id = auth.uid()
  ) OR
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND u.role IN ('admin', 'moderator')
  )
);
