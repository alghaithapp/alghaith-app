-- فهارس الإنتاج لآلاف المستخدمين (العراق + توسع لاحق)
-- نفّذ في Supabase SQL Editor بعد schema.sql

CREATE INDEX IF NOT EXISTS idx_app_users_phone ON app_users (phone);
CREATE INDEX IF NOT EXISTS idx_app_users_updated_at ON app_users (updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_customer_profiles_phone ON customer_profiles (phone);
CREATE INDEX IF NOT EXISTS idx_merchant_profiles_phone ON merchant_profiles (phone);
CREATE INDEX IF NOT EXISTS idx_merchant_profiles_service_ids ON merchant_profiles USING GIN (service_ids);

CREATE INDEX IF NOT EXISTS idx_customer_orders_courier_phone ON customer_orders (courier_phone, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_customer_orders_merchant_phone ON customer_orders (merchant_phone, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_customer_orders_delivery_pool ON customer_orders (status_key, delivery_status_key, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_merchant_products_phone ON merchant_products (phone);
CREATE INDEX IF NOT EXISTS idx_merchant_products_category ON merchant_products (category, sub_category);
CREATE INDEX IF NOT EXISTS idx_merchant_products_updated_at ON merchant_products (updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_customer_addresses_phone ON customer_addresses (phone);
CREATE INDEX IF NOT EXISTS idx_customer_favorites_phone ON customer_favorites (phone);
CREATE INDEX IF NOT EXISTS idx_customer_orders_phone ON customer_orders (phone);
CREATE INDEX IF NOT EXISTS idx_customer_orders_status ON customer_orders (status_key, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_state_phone ON app_state (phone);

-- تحليل الجداول بعد إنشاء الفهارس
ANALYZE app_users;
ANALYZE customer_profiles;
ANALYZE merchant_profiles;
ANALYZE merchant_products;
ANALYZE customer_addresses;
ANALYZE customer_favorites;
ANALYZE customer_orders;
ANALYZE app_state;
