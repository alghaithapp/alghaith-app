-- تشغيل/إيقاف كل خدمة على حدة للتاجر متعدد الخدمات
alter table if exists public.merchant_profiles
  add column if not exists service_enabled jsonb not null default '{}'::jsonb;
