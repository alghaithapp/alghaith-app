-- أعمدة موافقة الإدارة على التجار والمهنيين

alter table if exists public.merchant_profiles
  add column if not exists is_approved boolean not null default false,
  add column if not exists approval_status text not null default 'pending',
  add column if not exists rejection_reason_key text,
  add column if not exists rejection_message_ar text,
  add column if not exists rejected_at timestamptz;

create index if not exists idx_merchant_profiles_approval_status
  on public.merchant_profiles (approval_status);

-- المهنيون الحاليون بدون موافقة صريحة → بانتظار المراجعة
update public.merchant_profiles
set
  is_approved = false,
  approval_status = 'pending',
  updated_at = now()
where (
  primary_service_id = 'professionals'
  or coalesce(service_ids::text, '') like '%professionals%'
  or nullif(trim(professional_category_id), '') is not null
  or coalesce(professional_info->>'name', '') <> ''
)
and coalesce(approval_status, 'pending') not in ('approved', 'rejected')
and is_approved is distinct from true;
