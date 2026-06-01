alter table if exists public.customer_profiles
add column if not exists address text;
