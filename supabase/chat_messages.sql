-- محادثات داخلية بين الأطراف (زبون ↔ تاجر / سائق / دعم ...)
CREATE TABLE IF NOT EXISTS chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_type text NOT NULL CHECK (thread_type IN ('order', 'taxi', 'store', 'support')),
  thread_id text NOT NULL,
  sender_phone text NOT NULL,
  receiver_phone text,
  sender_name text,
  message_type text NOT NULL DEFAULT 'text',
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_thread
  ON chat_messages (thread_type, thread_id, created_at);

CREATE INDEX IF NOT EXISTS idx_chat_messages_sender
  ON chat_messages (sender_phone, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_receiver
  ON chat_messages (receiver_phone, created_at DESC);
