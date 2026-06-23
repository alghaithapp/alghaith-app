-- Realtime للتكسي فقط (التطبيق يستخدم polling لطلبات المتاجر)
-- شغّل في Supabase → SQL Editor

-- 1) إزالة طلبات المتاجر من Realtime (إن كانت مفعّلة)
ALTER PUBLICATION supabase_realtime DROP TABLE customer_orders;

-- 2) تفعيل التكسي
ALTER PUBLICATION supabase_realtime ADD TABLE taxi_requests;

-- 3) تحقق — يجب أن يظهر taxi_requests فقط:
-- SELECT schemaname, tablename
-- FROM pg_publication_tables
-- WHERE pubname = 'supabase_realtime';
