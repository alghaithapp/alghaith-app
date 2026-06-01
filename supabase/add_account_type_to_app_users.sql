-- نوع الحساب يُقفل عند أول تسجيل: marketplace | delivery | driver
alter table if exists public.app_users
  add column if not exists account_type text;

create index if not exists idx_app_users_account_type
  on public.app_users (account_type);

-- ترقية الحسابات القديمة
update public.app_users
set account_type = case
  when role in ('customer', 'merchant') then 'marketplace'
  when role = 'delivery' then 'delivery'
  when role = 'driver' then 'driver'
  else account_type
end
where account_type is null
  and role is not null;
