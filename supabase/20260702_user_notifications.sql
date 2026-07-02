-- In-app notification inbox for end users (admin broadcasts, etc.)

CREATE TABLE IF NOT EXISTS public.user_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text NOT NULL,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  audience text NOT NULL DEFAULT 'customer',
  category text NOT NULL DEFAULT 'admin',
  event_key text,
  broadcast_id uuid,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_notifications_phone_created
  ON public.user_notifications (phone, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_notifications_phone_unread
  ON public.user_notifications (phone, is_read, created_at DESC)
  WHERE is_read = false;

CREATE INDEX IF NOT EXISTS idx_user_notifications_broadcast
  ON public.user_notifications (broadcast_id)
  WHERE broadcast_id IS NOT NULL;

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_notifications FROM anon, authenticated;
