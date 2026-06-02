-- ربط طلبات الزبائن بالتاجر لاستقبالها في لوحة التاجر
alter table if exists public.customer_orders
  add column if not exists merchant_phone text references public.app_users(phone) on delete set null;

create index if not exists idx_customer_orders_merchant_phone
  on public.customer_orders (merchant_phone, created_at desc);

analyze public.customer_orders;
