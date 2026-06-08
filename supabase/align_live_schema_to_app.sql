begin;

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

alter table if exists public.app_users
  add column if not exists customer_phone text,
  add column if not exists customer_avatar_base64 text,
  add column if not exists last_seen_at timestamptz;

update public.app_users
set customer_phone = coalesce(nullif(customer_phone, ''), phone)
where customer_phone is null or customer_phone = '';

alter table if exists public.merchant_profiles
  add column if not exists whatsapp text,
  add column if not exists work_sample_images_base64 jsonb not null default '[]'::jsonb,
  add column if not exists professional_info jsonb not null default '{}'::jsonb,
  add column if not exists professional_category_id text,
  add column if not exists active_service_id text,
  add column if not exists is_frozen boolean not null default false;

alter table if exists public.customer_profiles
  add column if not exists customer_phone text;

update public.customer_profiles
set customer_phone = coalesce(nullif(customer_phone, ''), phone)
where customer_phone is null or customer_phone = '';

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'customer_favorites_product_id_fkey'
  ) then
    alter table public.customer_favorites
      drop constraint customer_favorites_product_id_fkey;
  end if;

  if exists (
    select 1
    from pg_constraint
    where conname = 'order_items_product_id_fkey'
  ) then
    alter table public.order_items
      drop constraint order_items_product_id_fkey;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'merchant_products'
      and column_name = 'id'
      and data_type <> 'text'
  ) then
    alter table public.merchant_products
      alter column id type text using id::text;
  end if;
end
$$;

alter table if exists public.merchant_products
  add column if not exists phone text,
  add column if not exists category text not null default 'restaurant',
  add column if not exists sub_category text,
  add column if not exists image text not null default '',
  add column if not exists address text,
  add column if not exists floor_count integer,
  add column if not exists listing_mode text;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'merchant_products'
      and column_name = 'phone'
  ) and not exists (
    select 1
    from pg_constraint
    where conname = 'fk_merchant_products_phone_app_users'
  ) then
    alter table public.merchant_products
      add constraint fk_merchant_products_phone_app_users
      foreign key (phone) references public.app_users(phone) on delete cascade;
  end if;
end
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'order_items'
      and column_name = 'product_id'
      and data_type <> 'text'
  ) then
      alter table public.order_items
      alter column product_id type text using product_id::text;
  end if;
end
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'order_items'
      and column_name = 'product_id'
  ) and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'merchant_products'
      and column_name = 'id'
  ) and not exists (
    select 1
    from pg_constraint
    where conname = 'order_items_product_id_fkey'
  ) then
    alter table public.order_items
      add constraint order_items_product_id_fkey
      foreign key (product_id) references public.merchant_products(id) on delete cascade;
  end if;
end
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'customer_favorites'
      and column_name = 'product_id'
      and data_type <> 'text'
  ) then
    alter table public.customer_favorites
      alter column product_id type text using product_id::text;
  end if;
end
$$;

alter table if exists public.customer_favorites
  add column if not exists phone text,
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'customer_favorites'
      and column_name = 'user_id'
  ) then
    update public.customer_favorites fav
    set phone = users.phone
    from public.app_users users
    where fav.user_id = users.id
      and (fav.phone is null or fav.phone = '');
  end if;
end
$$;

create unique index if not exists idx_customer_favorites_phone_product_id
  on public.customer_favorites (phone, product_id)
  where phone is not null;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'customer_favorites'
      and column_name = 'product_id'
  ) and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'merchant_products'
      and column_name = 'id'
  ) and not exists (
    select 1
    from pg_constraint
    where conname = 'customer_favorites_product_id_fkey'
  ) then
    alter table public.customer_favorites
      add constraint customer_favorites_product_id_fkey
      foreign key (product_id) references public.merchant_products(id) on delete cascade;
  end if;
end
$$;

alter table if exists public.customer_addresses
  add column if not exists phone text,
  add column if not exists address_text text,
  add column if not exists sort_order integer not null default 0;

update public.customer_addresses
set address_text = coalesce(nullif(address_text, ''), address)
where address_text is null or address_text = '';

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'customer_addresses'
      and column_name = 'user_id'
  ) then
    update public.customer_addresses addr
    set phone = users.phone
    from public.app_users users
    where addr.user_id = users.id
      and (addr.phone is null or addr.phone = '');
  end if;
end
$$;

alter table if exists public.customer_addresses
  alter column address_text set not null;

create unique index if not exists idx_customer_addresses_phone_address_text
  on public.customer_addresses (phone, address_text)
  where phone is not null;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'customer_addresses'
      and column_name = 'phone'
  ) and not exists (
    select 1
    from pg_constraint
    where conname = 'fk_customer_addresses_phone_app_users'
  ) then
    alter table public.customer_addresses
      add constraint fk_customer_addresses_phone_app_users
      foreign key (phone) references public.app_users(phone) on delete cascade;
  end if;
end
$$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'customer_favorites'
      and column_name = 'phone'
  ) and not exists (
    select 1
    from pg_constraint
    where conname = 'fk_customer_favorites_phone_app_users'
  ) then
    alter table public.customer_favorites
      add constraint fk_customer_favorites_phone_app_users
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

commit;
