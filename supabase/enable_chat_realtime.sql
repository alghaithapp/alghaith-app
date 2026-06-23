-- تفعيل Realtime لجدول المحادثات (تحديث فوري داخل شاشة المحادثة)
-- شغّل في Supabase → SQL Editor

ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;

-- تحقق:
-- SELECT schemaname, tablename
-- FROM pg_publication_tables
-- WHERE pubname = 'supabase_realtime' AND tablename = 'chat_messages';
