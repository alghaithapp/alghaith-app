-- Merchant reviews table
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

-- Taxi driver status table  
CREATE TABLE IF NOT EXISTS taxi_driver_status (
  phone TEXT PRIMARY KEY,
  is_online BOOLEAN DEFAULT false,
  current_lat DOUBLE PRECISION DEFAULT 0,
  current_lng DOUBLE PRECISION DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_merchant_reviews_merchant ON merchant_reviews(merchant_phone);
CREATE INDEX IF NOT EXISTS idx_merchant_reviews_customer ON merchant_reviews(customer_phone);
