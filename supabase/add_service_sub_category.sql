-- إضافة عمود service_sub_category لجدول merchant_profiles
-- يُخزّن التخصص الفرعي للخدمة (مثل: صالون رجالي، صيدلية، بيع سيارات، إلخ)

ALTER TABLE merchant_profiles
  ADD COLUMN IF NOT EXISTS service_sub_category TEXT DEFAULT NULL;

-- فهرس للبحث السريع بالفئة الفرعية
CREATE INDEX IF NOT EXISTS idx_merchant_profiles_service_sub_category
  ON merchant_profiles (service_sub_category);

COMMENT ON COLUMN merchant_profiles.service_sub_category IS
  'الفئة الفرعية لنشاط التاجر (صالون رجالي، صالون نسائي، عيادة تجميل، صيدلية، بيع سيارات، إلخ)';
