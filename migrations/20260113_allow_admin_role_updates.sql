-- Allow admins to update user roles via RLS policy and trigger
-- Fixes: "Only admins can change roles" error preventing role changes
--
-- The actual block was in a trigger function, not just RLS policy.
-- This migration ensures the is_admin() function works correctly.

-- First, verify/recreate the is_admin() helper function
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND u.role = 'admin'
  );
$$;

-- Ensure the trigger function properly checks is_admin()
CREATE OR REPLACE FUNCTION public.prevent_non_admin_role_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    IF NOT public.is_admin() THEN
      RAISE EXCEPTION 'Only admins can change roles';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS trg_prevent_role_change ON public.users;
CREATE TRIGGER trg_prevent_role_change
BEFORE UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.prevent_non_admin_role_change();

-- Update RLS policy to allow admins
DROP POLICY IF EXISTS "Only admins can change roles" ON users;
DROP POLICY IF EXISTS "Admins can update user roles" ON users;

CREATE POLICY "Admins can update user roles"
ON users
FOR UPDATE
USING (
  public.is_admin()
)
WITH CHECK (
  public.is_admin()
);

-- To verify your admin user, run this query:
-- SELECT id, username, role FROM users WHERE id = auth.uid();
-- 
-- If your role is not 'admin', you need to set it manually first:
-- Using the Supabase Dashboard SQL editor with service role access, run:
-- UPDATE users SET role = 'admin' WHERE username = 'your-username';

