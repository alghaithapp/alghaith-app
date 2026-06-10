-- Device tokens for Firebase Cloud Messaging (FCM) push notifications.
-- Run in Supabase SQL editor after app_users exists.

CREATE TABLE IF NOT EXISTS device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL REFERENCES app_users(phone) ON DELETE CASCADE,
  token text NOT NULL,
  platform text NOT NULL DEFAULT 'unknown',
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (phone, token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_phone ON device_tokens(phone);
CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON device_tokens(token);
