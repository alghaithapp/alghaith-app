-- Taxi ride requests (customer ↔ driver pool, same pattern as customer_orders).

create table if not exists public.taxi_requests (
  id text primary key,
  phone text not null references public.app_users(phone) on delete cascade,
  request_number text,
  status_key text,
  ride_type_id text,
  driver_phone text,
  request_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_taxi_requests_phone on public.taxi_requests (phone);
create index if not exists idx_taxi_requests_driver_phone on public.taxi_requests (driver_phone);
create index if not exists idx_taxi_requests_status_key on public.taxi_requests (status_key);
create index if not exists idx_taxi_requests_updated_at on public.taxi_requests (updated_at desc);

drop trigger if exists trg_taxi_requests_updated_at on public.taxi_requests;
create trigger trg_taxi_requests_updated_at
before update on public.taxi_requests
for each row execute function public.set_updated_at();

revoke all on table public.taxi_requests from anon, authenticated;
alter table if exists public.taxi_requests enable row level security;
