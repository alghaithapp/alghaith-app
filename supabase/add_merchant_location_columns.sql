alter table if exists public.merchant_profiles
  add column if not exists latitude double precision;

alter table if exists public.merchant_profiles
  add column if not exists longitude double precision;
