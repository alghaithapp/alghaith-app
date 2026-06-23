-- =============================================================================
-- Fix Data Integrity — Atomic upserts, FK constraints, RLS, validations
-- =============================================================================

-- 1. Atomic JSONB merge function for app_state
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
      WHEN p_state IS NULL THEN EXCLUDED.state
      ELSE COALESCE(app_state.state, '{}'::JSONB) || p_state
    END,
    updated_at = NOW();
  RETURN (SELECT state FROM app_state WHERE phone = p_phone);
END;
$$;

-- 2. Atomic JSONB path merge function (merge nested objects)
CREATE OR REPLACE FUNCTION merge_app_state_path(p_phone TEXT, p_path TEXT, p_value JSONB)
RETURNS JSONB
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  v_state JSONB;
  v_path TEXT[];
  v_temp JSONB;
  v_exists BOOLEAN;
BEGIN
  v_path := string_to_array(p_path, '.');
  v_state := COALESCE((SELECT state FROM app_state WHERE phone = p_phone), '{}'::JSONB);
  v_temp := jsonb_set(v_state, v_path, p_value, true);
  INSERT INTO app_state (phone, state, updated_at)
  VALUES (p_phone, v_temp, NOW())
  ON CONFLICT (phone)
  DO UPDATE SET state = v_temp, updated_at = NOW();
  RETURN (SELECT state FROM app_state WHERE phone = p_phone);
END;
$$;

-- 3. إنشاء الجداول المفقودة إن لم توجد
CREATE TABLE IF NOT EXISTS merchant_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_phone TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  order_id TEXT,
  stars INTEGER NOT NULL DEFAULT 5 CHECK (stars >= 1 AND stars <= 5),
  comment TEXT DEFAULT '',
  reply TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS taxi_driver_status (
  phone TEXT PRIMARY KEY,
  is_online BOOLEAN DEFAULT false,
  current_lat DOUBLE PRECISION DEFAULT 0,
  current_lng DOUBLE PRECISION DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. إضافة FOREIGN KEY للجداول المفقودة (فقط إذا كانت الأعمدة موجودة)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'merchant_reviews' AND column_name = 'merchant_phone'
  ) THEN
ALTER TABLE merchant_reviews
  DROP CONSTRAINT IF EXISTS merchant_reviews_merchant_user_id_fkey,
  ADD CONSTRAINT merchant_reviews_merchant_user_id_fkey
    FOREIGN KEY (merchant_user_id) REFERENCES app_users(phone) ON DELETE CASCADE;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'merchant_reviews' AND column_name = 'customer_phone'
  ) THEN
    ALTER TABLE merchant_reviews
      DROP CONSTRAINT IF EXISTS merchant_reviews_customer_phone_fkey,
      ADD CONSTRAINT merchant_reviews_customer_phone_fkey
        FOREIGN KEY (customer_phone) REFERENCES app_users(phone) ON DELETE CASCADE;
  END IF;
END $$;

ALTER TABLE taxi_driver_status
  DROP CONSTRAINT IF EXISTS taxi_driver_status_phone_fkey,
  ADD CONSTRAINT taxi_driver_status_phone_fkey
    FOREIGN KEY (phone) REFERENCES app_users(phone) ON DELETE CASCADE;

-- push_inbox_state قد لا تكون موجودة — نتحقق
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'push_inbox_state'
  ) THEN
    ALTER TABLE push_inbox_state
      DROP CONSTRAINT IF EXISTS push_inbox_state_phone_fkey,
      ADD CONSTRAINT push_inbox_state_phone_fkey
        FOREIGN KEY (phone) REFERENCES app_users(phone) ON DELETE CASCADE;
  END IF;
END $$;

-- 5. RLS للجداول المكشوفة
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON device_tokens FROM anon, authenticated;

ALTER TABLE merchant_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON merchant_reviews FROM anon, authenticated;

ALTER TABLE taxi_driver_status ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON taxi_driver_status FROM anon, authenticated;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'push_inbox_state'
  ) THEN
    EXECUTE 'ALTER TABLE push_inbox_state ENABLE ROW LEVEL SECURITY';
    EXECUTE 'REVOKE ALL ON push_inbox_state FROM anon, authenticated';
  END IF;
END $$;

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
