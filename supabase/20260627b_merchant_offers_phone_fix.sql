-- Run BEFORE merchant_offers INSERT in 20260627 (safe to re-run).

-- 1) Inspect current columns (optional)
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'merchant_offers'
-- ORDER BY ordinal_position;

DO $$
BEGIN
  IF to_regclass('public.merchant_offers') IS NULL THEN
    RAISE EXCEPTION 'Table public.merchant_offers does not exist';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'merchant_offers' AND column_name = 'phone'
  ) THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'merchant_offers' AND column_name = 'merchant_phone'
  ) THEN
    ALTER TABLE public.merchant_offers RENAME COLUMN merchant_phone TO phone;
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'merchant_offers' AND column_name = 'merchant_user_id'
  ) THEN
    ALTER TABLE public.merchant_offers RENAME COLUMN merchant_user_id TO phone;
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'merchant_offers' AND column_name = 'user_phone'
  ) THEN
    ALTER TABLE public.merchant_offers RENAME COLUMN user_phone TO phone;
    RETURN;
  END IF;

  ALTER TABLE public.merchant_offers ADD COLUMN phone text;
END $$;

CREATE INDEX IF NOT EXISTS idx_merchant_offers_phone
  ON public.merchant_offers (phone, is_active);
