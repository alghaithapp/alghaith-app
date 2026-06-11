-- Tracks unread push notifications per user for 2-hour reminder nudges.

CREATE TABLE IF NOT EXISTS public.push_inbox_state (
  phone text PRIMARY KEY,
  unread_count integer NOT NULL DEFAULT 0,
  last_push_at timestamptz,
  last_opened_at timestamptz,
  last_reminder_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_push_inbox_state_last_push
  ON public.push_inbox_state (last_push_at);
