-- ربط طلبات التوصيل بمندوب التوصيل
alter table if exists public.customer_orders
  add column if not exists courier_phone text references public.app_users(phone) on delete set null;

create index if not exists idx_customer_orders_courier_phone
  on public.customer_orders (courier_phone, created_at desc);

create index if not exists idx_customer_orders_delivery_pool
  on public.customer_orders (status_key, delivery_status_key, updated_at desc);

analyze public.customer_orders;
