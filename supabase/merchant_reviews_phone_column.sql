-- توحيد جدول merchant_reviews مع الباكند (merchant_phone)
-- شغّل في Supabase → SQL Editor إذا ظهر خطأ: column merchant_phone does not exist

BEGIN;

CREATE TABLE IF NOT EXISTS public.merchant_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_phone text NOT NULL,
  customer_phone text NOT NULL,
  order_id text,
  stars integer NOT NULL DEFAULT 5 CHECK (stars >= 1 AND stars <= 5),
  comment text DEFAULT '',
  reply text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.merchant_reviews ADD COLUMN IF NOT EXISTS merchant_phone text;
ALTER TABLE public.merchant_reviews ADD COLUMN IF NOT EXISTS customer_phone text;
ALTER TABLE public.merchant_reviews ADD COLUMN IF NOT EXISTS customer_name text;
ALTER TABLE public.merchant_reviews ADD COLUMN IF NOT EXISTS order_id text;
ALTER TABLE public.merchant_reviews ADD COLUMN IF NOT EXISTS stars integer DEFAULT 5;
ALTER TABLE public.merchant_reviews ADD COLUMN IF NOT EXISTS comment text DEFAULT '';
ALTER TABLE public.merchant_reviews ADD COLUMN IF NOT EXISTS reply text DEFAULT '';
ALTER TABLE public.merchant_reviews ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.merchant_reviews ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- ترحيل من merchant_user_id إن وُجد
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'merchant_reviews' AND column_name = 'merchant_user_id'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'merchant_reviews' AND column_name = 'merchant_phone'
  ) THEN
    UPDATE public.merchant_reviews r
    SET merchant_phone = u.phone
    FROM public.app_users u
    WHERE r.merchant_phone IS NULL
      AND r.merchant_user_id IS NOT NULL
      AND u.id = r.merchant_user_id;
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_merchant_reviews_order_id
  ON public.merchant_reviews (order_id)
  WHERE order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_merchant_reviews_merchant_phone
  ON public.merchant_reviews (merchant_phone, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_merchant_reviews_customer_phone
  ON public.merchant_reviews (customer_phone, created_at DESC);

COMMIT;
