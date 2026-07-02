-- موافقة المحتوى (منتجات / عقارات / إعلانات) — المرحلة 1
ALTER TABLE public.merchant_products
  ADD COLUMN IF NOT EXISTS is_approved boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS rejection_message_ar text,
  ADD COLUMN IF NOT EXISTS rejected_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_merchant_products_approval_status
  ON public.merchant_products (approval_status);

CREATE INDEX IF NOT EXISTS idx_merchant_products_pending
  ON public.merchant_products (is_approved, category)
  WHERE is_approved = false;

COMMENT ON COLUMN public.merchant_products.is_approved IS
  'يتحكم بظهور المنتج/الإعلان للزبائن. التعديلات تعيده إلى false حتى موافقة الإدارة.';

-- الحسابات المسجّلة من لوحة الإدارة (لا تحتاج موافقة حساب، لكن المحتوى يحتاج)
ALTER TABLE public.merchant_profiles
  ADD COLUMN IF NOT EXISTS admin_pre_registered boolean NOT NULL DEFAULT false;
