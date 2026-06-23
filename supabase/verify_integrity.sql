-- =============================================================================
-- Al-Ghaith Supabase Integrity Verification (SELECT output)
-- =============================================================================

-- 1. الجداول
SELECT 'TABLES' as section, table_name as result, 'exists' as status
FROM information_schema.tables WHERE table_schema = 'public'
  AND table_name IN (
    'app_users', 'merchant_profiles', 'merchant_products', 'customer_profiles',
    'customer_addresses', 'customer_favorites', 'customer_orders', 'app_state',
    'otp_requests', 'device_tokens', 'merchant_reviews', 'taxi_requests',
    'taxi_driver_status', 'push_inbox_state'
  )
UNION ALL
SELECT 'TABLES', t, 'MISSING!'
FROM (VALUES
  ('app_users'), ('merchant_profiles'), ('merchant_products'), ('customer_profiles'),
  ('customer_addresses'), ('customer_favorites'), ('customer_orders'), ('app_state'),
  ('merchant_reviews'), ('taxi_requests'), ('taxi_driver_status')
) AS missing(t)
WHERE NOT EXISTS (
  SELECT 1 FROM information_schema.tables
  WHERE table_schema = 'public' AND table_name = missing.t
)
ORDER BY section, result;

-- 2. الدوال
SELECT 'FUNCTIONS' as section, 'merge_app_state' as result,
  CASE WHEN COUNT(*) > 0 THEN 'exists' ELSE 'MISSING!' END as status
FROM pg_proc WHERE proname = 'merge_app_state';

-- 3. RLS
SELECT 'RLS' as section, tablename::text as result,
  CASE WHEN rowsecurity THEN 'enabled' ELSE 'DISABLED!' END as status
FROM pg_tables WHERE schemaname = 'public'
  AND tablename IN ('app_users','merchant_profiles','merchant_products',
    'customer_profiles','customer_orders','customer_favorites','app_state',
    'taxi_requests','merchant_reviews','taxi_driver_status','push_inbox_state')
ORDER BY result;

-- 4. إحصائيات الصفوف
SELECT 'ROW COUNTS' as section, 'app_users' as table_name, COUNT(*)::text as row_count FROM app_users
UNION ALL SELECT 'ROW COUNTS', 'merchant_profiles', COUNT(*)::text FROM merchant_profiles
UNION ALL SELECT 'ROW COUNTS', 'merchant_products', COUNT(*)::text FROM merchant_products
UNION ALL SELECT 'ROW COUNTS', 'customer_orders', COUNT(*)::text FROM customer_orders
UNION ALL SELECT 'ROW COUNTS', 'app_state', COUNT(*)::text FROM app_state
UNION ALL SELECT 'ROW COUNTS', 'taxi_requests', COUNT(*)::text FROM taxi_requests
UNION ALL SELECT 'ROW COUNTS', 'merchant_reviews', COUNT(*)::text FROM merchant_reviews
UNION ALL SELECT 'ROW COUNTS', 'device_tokens', COUNT(*)::text FROM device_tokens
UNION ALL SELECT 'ROW COUNTS', 'otp_requests', COUNT(*)::text FROM otp_requests;

-- 5. الأيتام (سجلات تشير لمستخدمين غير موجودين)
SELECT 'ORPHANS' as section, 'merchant_profiles' as table_name,
  COUNT(*)::text || ' rows without parent' as issue
FROM merchant_profiles mp WHERE NOT EXISTS (
  SELECT 1 FROM app_users u WHERE u.phone = mp.phone
) AND mp.phone IS NOT NULL
UNION ALL
SELECT 'ORPHANS', 'customer_orders',
  COUNT(*)::text || ' rows without customer phone'
FROM customer_orders co WHERE NOT EXISTS (
  SELECT 1 FROM app_users u WHERE u.phone = co.phone
) AND co.phone IS NOT NULL
UNION ALL
SELECT 'ORPHANS', 'taxi_requests',
  COUNT(*)::text || ' rows without customer phone'
FROM taxi_requests tr WHERE NOT EXISTS (
  SELECT 1 FROM app_users u WHERE u.phone = tr.phone
) AND tr.phone IS NOT NULL;

-- 6. CHECK constraint على order_payload
SELECT 'CONSTRAINTS' as section, 'customer_orders.order_payload' as result,
  CASE WHEN COUNT(*) > 0 THEN 'has CHECK constraint' ELSE 'NO CHECK CONSTRAINT!' END as status
FROM information_schema.check_constraints cc
JOIN information_schema.constraint_column_usage ccu ON cc.constraint_name = ccu.constraint_name
WHERE ccu.table_name = 'customer_orders' AND ccu.column_name = 'order_payload';

-- 7. الـ FK constraints
SELECT 'FOREIGN KEYS' as section,
  conname::text as constraint_name,
  CASE WHEN connamespace > 0 THEN 'exists' ELSE 'MISSING!' END as status
FROM pg_constraint WHERE conname IN (
  'merchant_reviews_merchant_phone_fkey',
  'merchant_reviews_customer_phone_fkey',
  'taxi_driver_status_phone_fkey'
)
UNION ALL
SELECT 'FOREIGN KEYS', 'merchant_reviews_merchant_phone_fkey', 'MISSING!'
WHERE NOT EXISTS (
  SELECT 1 FROM pg_constraint WHERE conname = 'merchant_reviews_merchant_phone_fkey'
)
UNION ALL
SELECT 'FOREIGN KEYS', 'merchant_reviews_customer_phone_fkey', 'MISSING!'
WHERE NOT EXISTS (
  SELECT 1 FROM pg_constraint WHERE conname = 'merchant_reviews_customer_phone_fkey'
)
UNION ALL
SELECT 'FOREIGN KEYS', 'taxi_driver_status_phone_fkey', 'MISSING!'
WHERE NOT EXISTS (
  SELECT 1 FROM pg_constraint WHERE conname = 'taxi_driver_status_phone_fkey'
);

-- 8. تحقق من order_payload JSONB
SELECT 'JSON VALIDATION' as section, 'order_payload' as column_name,
  CASE WHEN COUNT(*) > 0 THEN
    COUNT(*)::text || ' rows with INVALID JSON'
  ELSE
    'ALL VALID'
  END as status
FROM customer_orders WHERE jsonb_typeof(order_payload) IS DISTINCT FROM 'object';
