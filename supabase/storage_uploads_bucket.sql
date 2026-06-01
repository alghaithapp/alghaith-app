-- إنشاء bucket عام باسم uploads لرفع صور التطبيق (زبائن، تجار، منتجات)
-- نفّذ هذا الملف من: Supabase Dashboard → SQL Editor → New query → Run

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'uploads',
  'uploads',
  true,
  10485760, -- 10 MB
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/heic',
    'image/heif'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- قراءة عامة للملفات داخل uploads
drop policy if exists "Public read uploads" on storage.objects;
create policy "Public read uploads"
on storage.objects
for select
to public
using (bucket_id = 'uploads');

-- رفع عبر service_role (Worker / Backend) — لا يحتاج سياسة إضافية
-- رفع من التطبيق المباشر (anon/authenticated) إن استخدمت Supabase client:
drop policy if exists "Authenticated upload uploads" on storage.objects;
create policy "Authenticated upload uploads"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'uploads');

drop policy if exists "Authenticated update uploads" on storage.objects;
create policy "Authenticated update uploads"
on storage.objects
for update
to authenticated
using (bucket_id = 'uploads')
with check (bucket_id = 'uploads');

drop policy if exists "Authenticated delete uploads" on storage.objects;
create policy "Authenticated delete uploads"
on storage.objects
for delete
to authenticated
using (bucket_id = 'uploads');
