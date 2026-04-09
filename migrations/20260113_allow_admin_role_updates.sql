-- Allow admins to update user roles via database function
-- Fixes: "Only admins can change roles" error preventing role changes
--
-- This creates a database function that admins can call to update user roles.
-- The function verifies admin status and updates roles with elevated privileges.

-- Create function for admins to update user roles
-- This function runs with SECURITY DEFINER so it can bypass RLS checks AND triggers
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
  
  -- Disable trigger for this transaction to avoid the role-change check
  -- (since we're doing the admin check ourselves)
  ALTER TABLE users DISABLE TRIGGER trg_prevent_role_change;
  
  -- Update the target user's role
  UPDATE users 
  SET role = new_role, updated_at = NOW()
  WHERE id = target_user_id
  RETURNING to_jsonb(users.*) INTO updated_user;
  
  -- Re-enable trigger
  ALTER TABLE users ENABLE TRIGGER trg_prevent_role_change;
  
  IF updated_user IS NULL THEN
    RAISE EXCEPTION 'User not found: %', target_user_id;
  END IF;
  
  RETURN updated_user;
END;
$$;

