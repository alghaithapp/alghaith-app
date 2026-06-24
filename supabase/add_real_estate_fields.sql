-- حقول إضافية لإعلانات العقارات
alter table if exists public.merchant_products
  add column if not exists neighborhood text,
  add column if not exists facade text,
  add column if not exists gallery_images_base64 jsonb not null default '[]'::jsonb;
