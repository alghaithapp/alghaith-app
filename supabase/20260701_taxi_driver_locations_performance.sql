-- Taxi performance upgrade: fast driver discovery + safer indexed queries.
-- Run in Supabase SQL Editor before deploying the matching backend changes.

create table if not exists public.driver_locations (
  phone text primary key references public.app_users(phone) on delete cascade,
  lat double precision,
  lng double precision,
  taxi_type text not null default 'economic',
  is_online boolean not null default false,
  available boolean not null default false,
  is_approved boolean not null default false,
  driver_name text,
  vehicle_model text,
  plate_number text,
  color text,
  governorate text,
  city text,
  rating double precision default 0,
  total_trips integer default 0,
  location_updated_at timestamptz,
  offline_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists idx_driver_locations_fast_match
  on public.driver_locations (taxi_type, is_online, available, is_approved, location_updated_at desc);

create index if not exists idx_driver_locations_city_match
  on public.driver_locations (governorate, city, taxi_type, is_online, available, is_approved, location_updated_at desc);

create index if not exists idx_driver_locations_lat_lng
  on public.driver_locations (lat, lng);

create index if not exists idx_taxi_requests_status_type_created
  on public.taxi_requests (status_key, taxi_type, created_at desc);

create index if not exists idx_taxi_requests_customer_active
  on public.taxi_requests (phone, status_key, created_at desc);

create index if not exists idx_taxi_requests_driver_active
  on public.taxi_requests (driver_phone, status_key, created_at desc);

create index if not exists idx_customer_orders_status_merchant_courier
  on public.customer_orders (status_key, merchant_phone, courier_phone, created_at desc);

analyze public.driver_locations;
analyze public.taxi_requests;
analyze public.customer_orders;
