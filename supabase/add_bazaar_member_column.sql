-- إضافة عمود is_bazaar_member إلى merchant_profiles
-- هذا العمود يسمح للمدير السوبر بمنح التجار صلاحية النشر في قسم البازار

alter table if exists public.merchant_profiles 
add column if not exists is_bazaar_member boolean not null default false;

-- فهرس لتسريع الاستعلامات
create index if not exists idx_merchant_profiles_bazaar 
on public.merchant_profiles (is_bazaar_member) 
where is_bazaar_member = true;