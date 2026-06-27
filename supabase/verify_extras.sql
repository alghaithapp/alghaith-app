-- =============================================================================
-- Al-Ghaith — كشف أشياء زائدة / قديمة في Supabase (public schema)
-- شغّل في SQL Editor بعد verify_integrity.sql
-- النتيجة: section | item | status | note
-- =============================================================================

WITH expected_tables AS (
  SELECT unnest(ARRAY[
    'app_users', 'merchant_profiles', 'merchant_products', 'customer_profiles',
    'customer_addresses', 'customer_favorites', 'customer_orders', 'app_state',
    'otp_requests', 'device_tokens', 'merchant_reviews', 'taxi_requests',
    'taxi_driver_status', 'push_inbox_state', 'chat_messages', 'voice_call_logs',
    'merchant_offers', 'admin_roles', 'driver_profiles', 'courier_profiles',
    'notification_outbox', 'media_assets'
  ]) AS table_name
),
extra_tables AS (
  SELECT
    'EXTRA TABLES'::text AS section,
    t.tablename AS item,
    'not used by app'::text AS status,
    'راجع قبل الحذف — قد يكون من تجربة قديمة'::text AS note
  FROM pg_tables t
  WHERE t.schemaname = 'public'
    AND t.tablename NOT IN (SELECT table_name FROM expected_tables)
    AND t.tablename NOT IN ('schema_migrations', 'spatial_ref_sys')
),
table_sizes AS (
  SELECT
    'TABLE SIZE'::text AS section,
    c.relname AS item,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS status,
    CASE
      WHEN pg_total_relation_size(c.oid) > 50 * 1024 * 1024 THEN 'كبير — راجع المحتوى'
      WHEN pg_total_relation_size(c.oid) = 0 THEN 'فارغ'
      ELSE 'طبيعي'
    END AS note
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND c.relname IN (SELECT table_name FROM expected_tables)
),
empty_tables AS (
  SELECT
    'EMPTY TABLES'::text AS section,
    t.table_name AS item,
    '0 rows'::text AS status,
    'قد يكون طبيعياً (مثلاً voice_call_logs جديد)'::text AS note
  FROM expected_tables t
  WHERE EXISTS (
    SELECT 1 FROM information_schema.tables i
    WHERE i.table_schema = 'public' AND i.table_name = t.table_name
  )
  AND NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = t.table_name AND c.reltuples > 0
  )
),
legacy_app_state AS (
  SELECT
    'LEGACY app_state KEYS'::text AS section,
    key AS item,
    cnt::text || ' users'::text AS status,
    'يُفترض نقلها لجداول — ليس في app_state'::text AS note
  FROM (
    SELECT 'orders' AS key, COUNT(*) AS cnt
    FROM app_state WHERE state ? 'orders'
    UNION ALL
    SELECT 'items', COUNT(*) FROM app_state WHERE state ? 'items'
    UNION ALL
    SELECT 'merchantStore', COUNT(*) FROM app_state WHERE state ? 'merchantStore'
    UNION ALL
    SELECT 'driverProfile', COUNT(*) FROM app_state WHERE state ? 'driverProfile'
    UNION ALL
    SELECT 'courierProfile', COUNT(*) FROM app_state WHERE state ? 'courierProfile'
    UNION ALL
    SELECT 'adminAccess', COUNT(*) FROM app_state WHERE state ? 'adminAccess'
    UNION ALL
    SELECT 'merchantOffers', COUNT(*) FROM app_state WHERE state ? 'merchantOffers'
  ) x
  WHERE cnt > 0
),
base64_bloat AS (
  SELECT 'BASE64 BLOAT'::text AS section, 'merchant_products.image_base64' AS item,
    COUNT(*)::text || ' rows'::text AS status,
    'نفّذ migrate_base64_images إن كانت كبيرة'::text AS note
  FROM merchant_products
  WHERE COALESCE(image_base64, '') <> ''
  UNION ALL
  SELECT 'BASE64 BLOAT', 'merchant_profiles.profile_image_base64',
    COUNT(*)::text || ' rows', 'انقل للـ R2'
  FROM merchant_profiles
  WHERE COALESCE(profile_image_base64, '') <> ''
  UNION ALL
  SELECT 'BASE64 BLOAT', 'app_users.avatar_base64',
    COUNT(*)::text || ' rows', 'انقل للـ R2'
  FROM app_users
  WHERE COALESCE(avatar_base64, '') <> ''
),
stale_otp AS (
  SELECT 'STALE DATA'::text AS section, 'otp_requests (>7 days)' AS item,
    COUNT(*)::text || ' rows'::text AS status,
    'يمكن حذف القديم'::text AS note
  FROM otp_requests
  WHERE created_at < now() - interval '7 days'
),
stale_call_logs AS (
  SELECT 'STALE DATA'::text AS section, 'voice_call_logs ringing >1h' AS item,
    COUNT(*)::text || ' rows'::text AS status,
    'مكالمات عالقة — حدّث status'::text AS note
  FROM voice_call_logs
  WHERE status = 'ringing' AND started_at < now() - interval '1 hour'
),
sent_outbox AS (
  SELECT 'STALE DATA'::text AS section, 'notification_outbox sent (>30d)' AS item,
    COUNT(*)::text || ' rows'::text AS status,
    'أرشفة/حذف اختياري'::text AS note
  FROM notification_outbox
  WHERE status = 'sent' AND created_at < now() - interval '30 days'
),
unused_realtime AS (
  SELECT
    'REALTIME EXTRA'::text AS section,
    p.tablename AS item,
    'published but not in app list'::text AS status,
    'قد يكون زائداً'::text AS note
  FROM pg_publication_tables p
  WHERE p.pubname = 'supabase_realtime'
    AND p.schemaname = 'public'
    AND p.tablename NOT IN ('chat_messages', 'taxi_requests', 'voice_call_logs')
),
combined AS (
  SELECT section, item, status, note FROM extra_tables
  UNION ALL SELECT section, item, status, note FROM table_sizes
  UNION ALL SELECT section, item, status, note FROM empty_tables
  UNION ALL SELECT section, item, status, note FROM legacy_app_state
  UNION ALL SELECT section, item, status, note FROM base64_bloat
  UNION ALL SELECT section, item, status, note FROM stale_otp
  UNION ALL SELECT section, item, status, note FROM stale_call_logs
  UNION ALL SELECT section, item, status, note FROM sent_outbox
  UNION ALL SELECT section, item, status, note FROM unused_realtime
)
SELECT section, item, status, note
FROM combined
ORDER BY
  CASE section
    WHEN 'EXTRA TABLES' THEN 1
    WHEN 'LEGACY app_state KEYS' THEN 2
    WHEN 'BASE64 BLOAT' THEN 3
    WHEN 'STALE DATA' THEN 4
    WHEN 'TABLE SIZE' THEN 5
    WHEN 'EMPTY TABLES' THEN 6
    WHEN 'REALTIME EXTRA' THEN 7
    ELSE 8
  END,
  item;
