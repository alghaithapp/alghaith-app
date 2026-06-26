-- Durable notification outbox for async FCM delivery.

CREATE TABLE IF NOT EXISTS public.notification_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_key text NOT NULL DEFAULT '',
  audience_role text NOT NULL DEFAULT 'customer',
  target_phone text,
  fcm_tokens text[] NOT NULL DEFAULT '{}',
  title text NOT NULL,
  body text NOT NULL,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'pending',
  attempts integer NOT NULL DEFAULT 0,
  scheduled_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notification_outbox_status_scheduled
  ON public.notification_outbox (status, scheduled_at);

DROP TRIGGER IF EXISTS trg_notification_outbox_updated_at ON public.notification_outbox;
CREATE TRIGGER trg_notification_outbox_updated_at
BEFORE UPDATE ON public.notification_outbox
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
