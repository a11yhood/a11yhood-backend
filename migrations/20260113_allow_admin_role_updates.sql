-- Allow admins to update user roles via database function
-- Fixes: "Only admins can change roles" error preventing role changes
--
-- This creates a database function that admins can call to update user roles.
-- The function verifies admin status and updates roles with elevated privileges.

-- First, verify/recreate the is_admin() helper function
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid() AND u.role = 'admin'
  );
$$;

-- Create function for admins to update user roles
-- This function runs with SECURITY DEFINER so it can bypass RLS checks
CREATE OR REPLACE FUNCTION public.admin_update_user_role(
  admin_user_id UUID,
  target_user_id UUID,
  new_role TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  updated_user JSONB;
BEGIN
  -- Verify the caller is an admin
  IF NOT EXISTS(SELECT 1 FROM users WHERE id = admin_user_id AND role = 'admin') THEN
    RAISE EXCEPTION 'Only admins can change roles';
  END IF;
  
  -- Verify the new role is valid
  IF new_role NOT IN ('user', 'moderator', 'admin') THEN
    RAISE EXCEPTION 'Invalid role: %', new_role;
  END IF;
  
  -- Update the target user's role
  UPDATE users 
  SET role = new_role, updated_at = NOW()
  WHERE id = target_user_id
  RETURNING to_jsonb(users.*) INTO updated_user;
  
  IF updated_user IS NULL THEN
    RAISE EXCEPTION 'User not found: %', target_user_id;
  END IF;
  
  RETURN updated_user;
END;
$$;

-- Keep the trigger function for defense in depth
-- (prevents accidental role changes through other means)
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

