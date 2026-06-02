-- Add collection_editors relationship table so collections can have multiple editors.
-- Also updates collections + collection_products RLS policies to authorize listed editors.

CREATE TABLE IF NOT EXISTS public.collection_editors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  collection_id UUID NOT NULL REFERENCES public.collections(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (collection_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_collection_editors_collection_user
  ON public.collection_editors(collection_id, user_id);

ALTER TABLE public.collection_editors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Collection editors are viewable by everyone" ON public.collection_editors;
CREATE POLICY "Collection editors are viewable by everyone"
  ON public.collection_editors FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Owners and admins can manage collection editors" ON public.collection_editors;
CREATE POLICY "Owners and admins can manage collection editors"
  ON public.collection_editors FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM public.collections c
      WHERE c.id = collection_editors.collection_id
        AND c.user_id = (SELECT auth.uid() AS uid)
    )
    OR EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.id = (SELECT auth.uid() AS uid)
        AND u.role = ANY (ARRAY['admin'::text, 'moderator'::text])
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.collections c
      WHERE c.id = collection_editors.collection_id
        AND c.user_id = (SELECT auth.uid() AS uid)
    )
    OR EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.id = (SELECT auth.uid() AS uid)
        AND u.role = ANY (ARRAY['admin'::text, 'moderator'::text])
    )
  );

DROP POLICY IF EXISTS "Public collections are viewable by everyone" ON public.collections;
CREATE POLICY "Public collections are viewable by everyone"
  ON public.collections FOR SELECT
  USING (
    is_public = true
    OR (SELECT auth.uid() AS uid) = user_id
    OR EXISTS (
      SELECT 1
      FROM public.collection_editors ce
      WHERE ce.collection_id = collections.id
        AND ce.user_id = (SELECT auth.uid() AS uid)
    )
  );

DROP POLICY IF EXISTS "Users can update own collections" ON public.collections;
CREATE POLICY "Users can update own collections"
  ON public.collections FOR UPDATE
  USING (
    (SELECT auth.uid() AS uid) = user_id
    OR EXISTS (
      SELECT 1
      FROM public.collection_editors ce
      WHERE ce.collection_id = collections.id
        AND ce.user_id = (SELECT auth.uid() AS uid)
    )
  );

DROP POLICY IF EXISTS "Users can delete own collections" ON public.collections;
CREATE POLICY "Users can delete own collections"
  ON public.collections FOR DELETE
  USING (
    (SELECT auth.uid() AS uid) = user_id
    OR EXISTS (
      SELECT 1
      FROM public.collection_editors ce
      WHERE ce.collection_id = collections.id
        AND ce.user_id = (SELECT auth.uid() AS uid)
    )
  );

DROP POLICY IF EXISTS "Users can view own collection products" ON public.collection_products;
CREATE POLICY "Users can view own collection products"
  ON public.collection_products FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.collections c
      WHERE c.id = collection_products.collection_id
        AND (
          c.user_id = (SELECT auth.uid() AS uid)
          OR EXISTS (
            SELECT 1
            FROM public.collection_editors ce
            WHERE ce.collection_id = c.id
              AND ce.user_id = (SELECT auth.uid() AS uid)
          )
        )
    )
  );

DROP POLICY IF EXISTS "Users can add products to own collections" ON public.collection_products;
CREATE POLICY "Users can add products to own collections"
  ON public.collection_products FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.collections c
      WHERE c.id = collection_products.collection_id
        AND (
          c.user_id = (SELECT auth.uid() AS uid)
          OR EXISTS (
            SELECT 1
            FROM public.collection_editors ce
            WHERE ce.collection_id = c.id
              AND ce.user_id = (SELECT auth.uid() AS uid)
          )
        )
    )
  );

DROP POLICY IF EXISTS "Users can remove products from own collections" ON public.collection_products;
CREATE POLICY "Users can remove products from own collections"
  ON public.collection_products FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM public.collections c
      WHERE c.id = collection_products.collection_id
        AND (
          c.user_id = (SELECT auth.uid() AS uid)
          OR EXISTS (
            SELECT 1
            FROM public.collection_editors ce
            WHERE ce.collection_id = c.id
              AND ce.user_id = (SELECT auth.uid() AS uid)
          )
        )
    )
  );
