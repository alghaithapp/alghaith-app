create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.app_users (
  phone text primary key,
  full_name text,
  role text,
  avatar_base64 text,
  customer_phone text,
  customer_avatar_base64 text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.merchant_profiles (
  id uuid primary key default gen_random_uuid(),
  phone text not null unique references public.app_users(phone) on delete cascade,
  store_name text not null,
  description text,
  primary_service_id text not null default 'restaurant',
  whatsapp text,
  address text,
  open_time text,
  close_time text,
  delivery_areas text,
  delivery_fee integer not null default 0,
  is_open boolean not null default true,
  rating numeric(3,2) not null default 4.80,
  cover_image_url text,
  logo_image_url text,
  profile_image_base64 text,
  work_sample_images_base64 jsonb not null default '[]'::jsonb,
  professional_info jsonb not null default '{}'::jsonb,
  professional_category_id text,
  service_ids jsonb not null default '[]'::jsonb,
  active_service_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.merchant_products (
  id text primary key,
  phone text not null references public.app_users(phone) on delete cascade,
  name_ar text not null,
  name_en text not null,
  description_ar text not null,
  description_en text not null,
  price integer not null default 0,
  rating numeric(3,2) not null default 4.8,
  category text not null default 'restaurant',
  sub_category text,
  category_label_ar text,
  category_label_en text,
  image text not null default '',
  image_base64 text,
  is_favorite boolean not null default false,
  avg_price_label_ar text,
  avg_price_label_en text,
  action_label_ar text,
  action_label_en text,
  address text,
  bedrooms integer,
  bathrooms integer,
  area_square_meter integer,
  floor_count integer,
  listing_mode text,
  prep_minutes integer,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_profiles (
  phone text primary key references public.app_users(phone) on delete cascade,
  display_name text,
  avatar_base64 text,
  address text,
  customer_phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  phone text not null references public.app_users(phone) on delete cascade,
  address_text text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_addresses_phone_address_key unique (phone, address_text)
);

create table if not exists public.customer_favorites (
  phone text not null references public.app_users(phone) on delete cascade,
  product_id text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (phone, product_id)
);

create table if not exists public.customer_orders (
  id text primary key,
  phone text not null references public.app_users(phone) on delete cascade,
  order_number text,
  status_key text,
  delivery_status_key text,
  order_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_state (
  phone text primary key references public.app_users(phone) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'fk_merchant_profiles_phone_app_users'
  ) then
    alter table public.merchant_profiles
      add constraint fk_merchant_profiles_phone_app_users
      foreign key (phone) references public.app_users(phone) on delete cascade;
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'fk_app_state_phone_app_users'
  ) then
    alter table public.app_state
      add constraint fk_app_state_phone_app_users
      foreign key (phone) references public.app_users(phone) on delete cascade;
  end if;
end
$$;

drop trigger if exists trg_app_users_updated_at on public.app_users;
create trigger trg_app_users_updated_at
before update on public.app_users
for each row execute function public.set_updated_at();

drop trigger if exists trg_merchant_profiles_updated_at on public.merchant_profiles;
create trigger trg_merchant_profiles_updated_at
before update on public.merchant_profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_merchant_products_updated_at on public.merchant_products;
create trigger trg_merchant_products_updated_at
before update on public.merchant_products
for each row execute function public.set_updated_at();

drop trigger if exists trg_customer_profiles_updated_at on public.customer_profiles;
create trigger trg_customer_profiles_updated_at
before update on public.customer_profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_customer_addresses_updated_at on public.customer_addresses;
create trigger trg_customer_addresses_updated_at
before update on public.customer_addresses
for each row execute function public.set_updated_at();

drop trigger if exists trg_customer_favorites_updated_at on public.customer_favorites;
create trigger trg_customer_favorites_updated_at
before update on public.customer_favorites
for each row execute function public.set_updated_at();

drop trigger if exists trg_customer_orders_updated_at on public.customer_orders;
create trigger trg_customer_orders_updated_at
before update on public.customer_orders
for each row execute function public.set_updated_at();

drop trigger if exists trg_app_state_updated_at on public.app_state;
create trigger trg_app_state_updated_at
before update on public.app_state
for each row execute function public.set_updated_at();

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on
  public.app_users,
  public.merchant_profiles,
  public.merchant_products,
  public.customer_profiles,
  public.customer_addresses,
  public.customer_favorites,
  public.customer_orders,
  public.app_state
to anon, authenticated;

alter table if exists public.app_users disable row level security;
alter table if exists public.merchant_profiles disable row level security;
alter table if exists public.merchant_products disable row level security;
alter table if exists public.customer_profiles disable row level security;
alter table if exists public.customer_addresses disable row level security;
alter table if exists public.customer_favorites disable row level security;
alter table if exists public.customer_orders disable row level security;
alter table if exists public.app_state disable row level security;
