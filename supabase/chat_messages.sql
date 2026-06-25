-- محادثات داخلية بين الأطراف (زبون ↔ تاجر / سائق / دعم ...)
-- شغّل في Supabase → SQL Editor
-- أو من backend: SUPABASE_DB_PASSWORD=... npm run apply-chat-schema

BEGIN;

CREATE TABLE IF NOT EXISTS public.chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_type text NOT NULL CHECK (thread_type IN ('order', 'taxi', 'store', 'support')),
  thread_id text NOT NULL,
  sender_phone text NOT NULL,
  receiver_phone text,
  sender_name text,
  message_type text NOT NULL DEFAULT 'text',
  content text NOT NULL,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ترقية جدول قديم (إن وُجد بدون بعض الأعمدة)
ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS receiver_phone text;
ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS sender_name text;
ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS message_type text;
ALTER TABLE public.chat_messages ADD COLUMN IF NOT EXISTS read_at timestamptz;

UPDATE public.chat_messages
SET message_type = 'text'
WHERE message_type IS NULL;

ALTER TABLE public.chat_messages
  ALTER COLUMN message_type SET DEFAULT 'text';

CREATE INDEX IF NOT EXISTS idx_chat_messages_thread
  ON public.chat_messages (thread_type, thread_id, created_at);

CREATE INDEX IF NOT EXISTS idx_chat_messages_sender
  ON public.chat_messages (sender_phone, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_receiver
  ON public.chat_messages (receiver_phone, created_at DESC);

-- Realtime لتحديث المحادثة فوراً داخل الشاشة
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
  END IF;
END $$;

COMMIT;
