-- Taxi requests - إنشاء جدول طلبات التكسي الجديد
-- يعتمد على هيكل JSONB للمرونة مع أعمدة منفصلة للبيانات الأساسية

create table if not exists public.taxi_requests (
  id text primary key,
  phone text not null references public.app_users(phone) on delete cascade,
  request_number text,
  status_key text not null default 'pending',
  driver_phone text,
  
  -- الأعمدة الجديدة
  pickup_lat double precision,
  pickup_lng double precision,
  dropoff_lat double precision,
  dropoff_lng double precision,
  distance_km double precision,
  taxi_type text,
  fare_economic integer,
  fare_super integer,
  fare integer,
  driver_rating integer,
  cash_collected boolean default false,
  accepted_at timestamptz,
  completed_at timestamptz,
  cancellation_reason text,
  is_paid boolean default false,
  driver_name text,
  vehicle_info text,
  
  -- JSONB للمرونة والتوسع المستقبلي
  request_payload jsonb not null default '{}'::jsonb,
  
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- إنشاء الفهارس
create index if not exists idx_taxi_requests_phone on public.taxi_requests (phone);
create index if not exists idx_taxi_requests_driver_phone on public.taxi_requests (driver_phone);
create index if not exists idx_taxi_requests_status_key on public.taxi_requests (status_key);
create index if not exists idx_taxi_requests_taxi_type on public.taxi_requests (taxi_type);
create index if not exists idx_taxi_requests_fare on public.taxi_requests (fare);
create index if not exists idx_taxi_requests_completed_at on public.taxi_requests (completed_at);
create index if not exists idx_taxi_requests_updated_at on public.taxi_requests (updated_at desc);

-- Trigger لتحديث updated_at
drop trigger if exists trg_taxi_requests_updated_at on public.taxi_requests;
create trigger trg_taxi_requests_updated_at
before update on public.taxi_requests
for each row execute function public.set_updated_at();

-- أذونات
revoke all on table public.taxi_requests from anon, authenticated;
alter table if exists public.taxi_requests enable row level security;
