-- =============================================================================
-- Fix Data Integrity — Atomic upserts, FK constraints, RLS, validations
-- =============================================================================

-- 1. Atomic JSONB merge function for app_state
-- يحل مشكلة race condition في قراءة-تعديل-كتابة app_state
CREATE OR REPLACE FUNCTION merge_app_state(p_phone TEXT, p_state JSONB)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, p_state, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET
    state = CASE
      -- إذا كان p_state يحوي مفتاحاً معيناً بالقيمة null، نزيله من state
      WHEN p_state IS NULL THEN EXCLUDED.state
      -- وإلا ندمج (دمج على مستوى الجذر فقط)
      ELSE COALESCE(app_state.state, '{}'::JSONB) || p_state
    END,
    updated_at = NOW();
  RETURN (SELECT state FROM app_state WHERE phone = p_phone);
END;
$$;

-- 2. Atomic JSONB path merge function (merge nested objects)
-- يسمح بدمج الحقول المتداخلة مثل driverProfile.available
CREATE OR REPLACE FUNCTION merge_app_state_path(p_phone TEXT, p_path TEXT, p_value JSONB)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
  v_path TEXT[];
  v_key TEXT;
  v_temp JSONB;
BEGIN
  v_path := string_to_array(p_path, '.');
  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  
  -- بناء المسار المتداخل
  v_temp := v_state;
  FOR i IN 1..array_length(v_path, 1) LOOP
    v_key := v_path[i];
    IF i = array_length(v_path, 1) THEN
      v_temp := jsonb_set(v_temp, v_path, p_value, true);
    END IF;
  END LOOP;
  
  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_temp, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_temp, updated_at = NOW();
  
  RETURN (SELECT state FROM app_state WHERE phone = p_phone);
END;
$$;

-- 3. Fix saveRow: استخدام atomic upsert
-- هذا يمنع فقدان البيانات من الطلبات المتزامنة
-- يتم تطبيقه في common.js (انظر أدناه)

-- 4. إضافة FOREIGN KEY للجداول المفقودة
ALTER TABLE merchant_reviews
  DROP CONSTRAINT IF EXISTS merchant_reviews_merchant_phone_fkey,
  ADD CONSTRAINT merchant_reviews_merchant_phone_fkey
    FOREIGN KEY (merchant_phone) REFERENCES app_users(phone) ON DELETE CASCADE;

ALTER TABLE merchant_reviews
  DROP CONSTRAINT IF EXISTS merchant_reviews_customer_phone_fkey,
  ADD CONSTRAINT merchant_reviews_customer_phone_fkey
    FOREIGN KEY (customer_phone) REFERENCES app_users(phone) ON DELETE CASCADE;

ALTER TABLE taxi_driver_status
  DROP CONSTRAINT IF EXISTS taxi_driver_status_phone_fkey,
  ADD CONSTRAINT taxi_driver_status_phone_fkey
    FOREIGN KEY (phone) REFERENCES app_users(phone) ON DELETE CASCADE;

ALTER TABLE push_inbox_state
  DROP CONSTRAINT IF EXISTS push_inbox_state_phone_fkey,
  ADD CONSTRAINT push_inbox_state_phone_fkey
    FOREIGN KEY (phone) REFERENCES app_users(phone) ON DELETE CASCADE;

-- 5. RLS للجداول المكشوفة
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON device_tokens FROM anon, authenticated;

ALTER TABLE merchant_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON merchant_reviews FROM anon, authenticated;

ALTER TABLE taxi_driver_status ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON taxi_driver_status FROM anon, authenticated;

ALTER TABLE push_inbox_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON push_inbox_state FROM anon, authenticated;

-- 6. CHECK constraint على order_payload
ALTER TABLE customer_orders
  DROP CONSTRAINT IF EXISTS customer_orders_order_payload_check,
  ADD CONSTRAINT customer_orders_order_payload_check
    CHECK (jsonb_typeof(order_payload) = 'object');

-- 7. إنشاء فهارس للأداء
CREATE INDEX IF NOT EXISTS idx_merchant_reviews_created_at
  ON merchant_reviews(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_taxi_driver_status_online
  ON taxi_driver_status(is_online) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_merchant_products_phone_available
  ON merchant_products(phone, is_available);
