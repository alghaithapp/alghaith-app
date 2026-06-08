-- إضافة عمود is_frozen إلى merchant_profiles
-- هذا العمود يسمح للمدير السوبر بتجميد حسابات التجار المخالفين

alter table if exists public.merchant_profiles 
add column if not exists is_frozen boolean not null default false;

-- فهرس لتسريع الاستعلامات على التجار المجمّدين
create index if not exists idx_merchant_profiles_frozen 
on public.merchant_profiles (is_frozen) 
where is_frozen = true;