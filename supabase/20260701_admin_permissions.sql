-- Admin Permissions: add JSONB permissions column to admin_roles
-- Each admin gets a set of granular permissions instead of just a role.

ALTER TABLE IF EXISTS public.admin_roles
  ADD COLUMN IF NOT EXISTS permissions jsonb;

-- Grant all permissions to existing admins for backward compatibility
UPDATE public.admin_roles
  SET permissions = '{"canRegister": true, "canApprove": true, "canDelete": true, "canSuspend": true, "canManageAdmins": false}'::jsonb
  WHERE permissions IS NULL;
