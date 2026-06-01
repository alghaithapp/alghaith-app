create table if not exists public.otp_requests (
  phone text primary key,
  code text not null,
  expires_at bigint not null,
  channel text not null default 'sms',
  sms_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_otp_requests_updated_at on public.otp_requests;
create trigger trg_otp_requests_updated_at
before update on public.otp_requests
for each row execute function public.set_updated_at();

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on
  public.otp_requests
to anon, authenticated;

alter table if exists public.otp_requests disable row level security;
