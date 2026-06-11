-- Merchant-defined menu/store sections + restaurant cuisine type.

ALTER TABLE public.merchant_profiles
  ADD COLUMN IF NOT EXISTS product_sections jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.merchant_profiles
  ADD COLUMN IF NOT EXISTS restaurant_category text;

ALTER TABLE public.merchant_products
  ADD COLUMN IF NOT EXISTS section_id text;

CREATE INDEX IF NOT EXISTS idx_merchant_products_section_id
  ON public.merchant_products (phone, section_id);
