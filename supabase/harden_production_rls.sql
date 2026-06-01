-- Production hardening for Al-Ghaith.
-- Run this in Supabase SQL Editor only after the Railway backend is live and
-- the mobile app is built with DATABASE_BACKEND_BASE_URL.

begin;

-- Stop public and client-side roles from touching application tables directly.
revoke all on table public.app_users from anon, authenticated;
revoke all on table public.merchant_profiles from anon, authenticated;
revoke all on table public.merchant_products from anon, authenticated;
revoke all on table public.customer_profiles from anon, authenticated;
revoke all on table public.customer_addresses from anon, authenticated;
revoke all on table public.customer_favorites from anon, authenticated;
revoke all on table public.customer_orders from anon, authenticated;
revoke all on table public.app_state from anon, authenticated;

-- Make row-level security the default posture on every app table.
alter table if exists public.app_users enable row level security;
alter table if exists public.merchant_profiles enable row level security;
alter table if exists public.merchant_products enable row level security;
alter table if exists public.customer_profiles enable row level security;
alter table if exists public.customer_addresses enable row level security;
alter table if exists public.customer_favorites enable row level security;
alter table if exists public.customer_orders enable row level security;
alter table if exists public.app_state enable row level security;

-- Remove any broad client policies that may have been added earlier.
drop policy if exists "anon_full_access_app_users" on public.app_users;
drop policy if exists "anon_full_access_merchant_profiles" on public.merchant_profiles;
drop policy if exists "anon_full_access_merchant_products" on public.merchant_products;
drop policy if exists "anon_full_access_customer_profiles" on public.customer_profiles;
drop policy if exists "anon_full_access_customer_addresses" on public.customer_addresses;
drop policy if exists "anon_full_access_customer_favorites" on public.customer_favorites;
drop policy if exists "anon_full_access_customer_orders" on public.customer_orders;
drop policy if exists "anon_full_access_app_state" on public.app_state;

-- Optional safety check for dashboards: service_role bypasses RLS already, so
-- the backend keeps working while anon/authenticated lose direct access.
comment on table public.app_users is
  'Protected by Railway backend + service_role only. Direct anon/authenticated access revoked.';

commit;
