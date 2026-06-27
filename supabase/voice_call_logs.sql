-- سجل المكالمات الصوتية الداخلية (ZEGOCLOUD)
-- شغّل في Supabase → SQL Editor إذا لم يكن الجدول موجوداً.

BEGIN;

CREATE TABLE IF NOT EXISTS public.voice_call_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_type text NOT NULL CHECK (thread_type IN ('order', 'taxi', 'store', 'support')),
  thread_id text NOT NULL,
  caller_phone text NOT NULL,
  receiver_phone text NOT NULL,
  caller_name text,
  channel_name text,
  direction text NOT NULL DEFAULT 'outgoing' CHECK (direction IN ('outgoing', 'incoming')),
  status text NOT NULL DEFAULT 'initiated' CHECK (
    status IN ('initiated', 'ringing', 'connected', 'ended', 'missed', 'failed', 'no_answer')
  ),
  duration_seconds integer NOT NULL DEFAULT 0,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_voice_call_logs_thread
  ON public.voice_call_logs (thread_type, thread_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_voice_call_logs_caller
  ON public.voice_call_logs (caller_phone, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_voice_call_logs_receiver
  ON public.voice_call_logs (receiver_phone, started_at DESC);

-- Realtime لاكتشاف المكالمات الواردة داخل شاشة المحادثة
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'voice_call_logs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.voice_call_logs;
  END IF;
END $$;

COMMIT;
