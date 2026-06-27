-- =============================================================================
-- Al-Ghaith Supabase Integrity Verification
-- شغّل الملف كاملاً — النتيجة جدول واحد (section / item / status)
-- =============================================================================

WITH required_tables AS (
  SELECT unnest(ARRAY[
    'app_users', 'merchant_profiles', 'merchant_products', 'customer_profiles',
    'customer_addresses', 'customer_favorites', 'customer_orders', 'app_state',
    'otp_requests', 'device_tokens', 'merchant_reviews', 'taxi_requests',
    'taxi_driver_status', 'push_inbox_state', 'chat_messages', 'voice_call_logs',
    'merchant_offers', 'admin_roles', 'driver_profiles', 'courier_profiles',
    'notification_outbox', 'media_assets'
  ]) AS table_name
),
existing_tables AS (
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public'
),
table_checks AS (
  SELECT
    'TABLES'::text AS section,
    r.table_name AS item,
    CASE
      WHEN e.table_name IS NOT NULL THEN 'exists'
      ELSE 'MISSING!'
    END AS status
  FROM required_tables r
  LEFT JOIN existing_tables e ON e.table_name = r.table_name
),
function_checks AS (
  SELECT
    'FUNCTIONS'::text AS section,
    'merge_app_state'::text AS item,
    CASE WHEN COUNT(*) > 0 THEN 'exists' ELSE 'MISSING!' END AS status
  FROM pg_proc
  WHERE proname = 'merge_app_state'
),
rls_checks AS (
  SELECT
    'RLS'::text AS section,
    tablename::text AS item,
    CASE WHEN rowsecurity THEN 'enabled' ELSE 'DISABLED!' END AS status
  FROM pg_tables
  WHERE schemaname = 'public'
    AND tablename IN (
      SELECT table_name FROM required_tables
    )
),
realtime_checks AS (
  SELECT
    'REALTIME'::text AS section,
    t.table_name AS item,
    CASE
      WHEN p.tablename IS NOT NULL THEN 'published'
      ELSE 'not in publication'
    END AS status
  FROM (
    SELECT unnest(ARRAY['chat_messages', 'taxi_requests', 'voice_call_logs']) AS table_name
  ) t
  LEFT JOIN pg_publication_tables p
    ON p.pubname = 'supabase_realtime'
   AND p.schemaname = 'public'
   AND p.tablename = t.table_name
),
constraint_checks AS (
  SELECT
    'CONSTRAINTS'::text AS section,
    'customer_orders.order_payload'::text AS item,
    CASE
      WHEN COUNT(*) > 0 THEN 'has CHECK constraint'
      ELSE 'NO CHECK CONSTRAINT!'
    END AS status
  FROM information_schema.check_constraints cc
  JOIN information_schema.constraint_column_usage ccu
    ON cc.constraint_name = ccu.constraint_name
  WHERE ccu.table_name = 'customer_orders'
    AND ccu.column_name = 'order_payload'
),
json_checks AS (
  SELECT
    'JSON VALIDATION'::text AS section,
    'order_payload'::text AS item,
    CASE
      WHEN COUNT(*) > 0 THEN COUNT(*)::text || ' rows INVALID'
      ELSE 'ALL VALID'
    END AS status
  FROM customer_orders
  WHERE jsonb_typeof(order_payload) IS DISTINCT FROM 'object'
),
fk_expected AS (
  SELECT unnest(ARRAY[
    'merchant_reviews_merchant_phone_fkey',
    'merchant_reviews_customer_phone_fkey',
    'taxi_driver_status_phone_fkey'
  ]) AS constraint_name
),
fk_checks AS (
  SELECT
    'FOREIGN KEYS'::text AS section,
    e.constraint_name AS item,
    CASE
      WHEN c.conname IS NOT NULL THEN 'exists'
      ELSE 'MISSING! (optional on some schemas)'
    END AS status
  FROM fk_expected e
  LEFT JOIN pg_constraint c ON c.conname = e.constraint_name
),
orphan_checks AS (
  SELECT 'ORPHANS'::text AS section, 'merchant_profiles'::text AS item,
    COUNT(*)::text || ' without app_users parent' AS status
  FROM merchant_profiles mp
  WHERE mp.phone IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM app_users u WHERE u.phone = mp.phone)
  UNION ALL
  SELECT 'ORPHANS', 'customer_orders',
    COUNT(*)::text || ' without app_users parent'
  FROM customer_orders co
  WHERE co.phone IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM app_users u WHERE u.phone = co.phone)
  UNION ALL
  SELECT 'ORPHANS', 'taxi_requests',
    COUNT(*)::text || ' without app_users parent'
  FROM taxi_requests tr
  WHERE tr.phone IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM app_users u WHERE u.phone = tr.phone)
),
combined AS (
  SELECT section, item, status FROM table_checks
  UNION ALL SELECT section, item, status FROM function_checks
  UNION ALL SELECT section, item, status FROM rls_checks
  UNION ALL SELECT section, item, status FROM realtime_checks
  UNION ALL SELECT section, item, status FROM constraint_checks
  UNION ALL SELECT section, item, status FROM json_checks
  UNION ALL SELECT section, item, status FROM fk_checks
  UNION ALL SELECT section, item, status FROM orphan_checks
)
SELECT section, item, status
FROM combined
ORDER BY
  CASE section
    WHEN 'TABLES' THEN 1
    WHEN 'FUNCTIONS' THEN 2
    WHEN 'RLS' THEN 3
    WHEN 'REALTIME' THEN 4
    WHEN 'CONSTRAINTS' THEN 5
    WHEN 'JSON VALIDATION' THEN 6
    WHEN 'FOREIGN KEYS' THEN 7
    WHEN 'ORPHANS' THEN 8
    ELSE 9
  END,
  item;

-- =============================================================================
-- اختياري: عدد الصفوف (شغّل منفصلاً إذا أردت — قد يفشل إن جدول ناقص)
-- =============================================================================
-- SELECT 'ROW COUNTS' AS section, 'app_users' AS item, COUNT(*)::text AS status FROM app_users
-- UNION ALL SELECT 'ROW COUNTS', 'merchant_profiles', COUNT(*)::text FROM merchant_profiles
-- UNION ALL SELECT 'ROW COUNTS', 'merchant_products', COUNT(*)::text FROM merchant_products
-- UNION ALL SELECT 'ROW COUNTS', 'customer_orders', COUNT(*)::text FROM customer_orders
-- UNION ALL SELECT 'ROW COUNTS', 'chat_messages', COUNT(*)::text FROM chat_messages
-- UNION ALL SELECT 'ROW COUNTS', 'voice_call_logs', COUNT(*)::text FROM voice_call_logs
-- UNION ALL SELECT 'ROW COUNTS', 'device_tokens', COUNT(*)::text FROM device_tokens
-- ORDER BY item;
