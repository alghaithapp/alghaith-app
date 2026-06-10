-- Device tokens for Firebase Cloud Messaging (FCM) push notifications.
-- Safe to run even if app_users is missing (no foreign key required).

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL,
  token text NOT NULL,
  platform text NOT NULL DEFAULT 'unknown',
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (phone, token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_phone ON public.device_tokens(phone);
CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON public.device_tokens(token);

-- Optional: link to app_users when that table exists in this project.
DO $$
BEGIN
  IF to_regclass('public.app_users') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'fk_device_tokens_phone_app_users'
    ) THEN
      ALTER TABLE public.device_tokens
        ADD CONSTRAINT fk_device_tokens_phone_app_users
        FOREIGN KEY (phone) REFERENCES public.app_users(phone) ON DELETE CASCADE;
    END IF;
  END IF;
END
$$;
