-- Run BEFORE 20260625+ migrations on production if columns/functions are missing.
-- Safe to re-run (idempotent).

-- merchant_profiles approval columns (required by atomic_* merchant procedures)
ALTER TABLE IF EXISTS public.merchant_profiles
  ADD COLUMN IF NOT EXISTS is_approved boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS rejection_reason_key text,
  ADD COLUMN IF NOT EXISTS rejection_message_ar text,
  ADD COLUMN IF NOT EXISTS rejected_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_merchant_profiles_approval_status
  ON public.merchant_profiles (approval_status);

-- updated_at helper (used by profile triggers)
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;
