# Cloudflare R2 — صور التطبيق

## الهدف

- رفع صور المنتجات والمتاجر إلى **Cloudflare R2** بدل Supabase Storage
- عرض الصور عبر **CDN Cloudflare** بدون Egress على Supabase
- التكلفة المتوقعة: **~$0.25–5/شهر** حسب عدد التحميلات

## البنية

```
التطبيق → POST /upload (Worker) → R2 bucket: alghaith-images
المستخدم يفتح الصورة → GET /media/uploads/... (Worker + CDN)
                      أو https://cdn.alghaithst.com/uploads/... (دومين مخصص)
```

## 1) إنشاء R2 bucket (مرة واحدة)

```bash
npx wrangler r2 bucket create alghaith-images
```

أو عبر لوحة Cloudflare: **R2 → Create bucket → `alghaith-images`**

## 2) نشر Worker

```powershell
$env:CLOUDFLARE_API_TOKEN = "YOUR_TOKEN"
.\scripts\deploy-worker.ps1
```

الملف `wrangler.toml` يربط الـ bucket:

```toml
[[r2_buckets]]
binding = "IMAGES_BUCKET"
bucket_name = "alghaith-images"
```

## 3) روابط الصور العامة

### الخيار أ — فوري (بدون دومين إضافي)

بعد النشر، الروابط تلقائياً:

```
https://lively-wind-9d98.alghaithapp.workers.dev/media/uploads/1730_photo.jpg
```

### الخيار ب — دومين CDN (موصى به للإنتاج)

1. Cloudflare → R2 → `alghaith-images` → **Settings → Custom Domains**
2. أضف: `cdn.alghaithst.com`
3. عيّن سر Worker:

```bash
npx wrangler secret put R2_PUBLIC_BASE_URL
# القيمة: https://cdn.alghaithst.com
```

## 4) مفاتيح R2 لسكربتات الترحيل (backend)

Cloudflare → R2 → **Manage R2 API Tokens** → Create token (Object Read & Write)

أضف في `backend/.env`:

```env
R2_ACCOUNT_ID=your_account_id
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET_NAME=alghaith-images
R2_PUBLIC_BASE_URL=https://lively-wind-9d98.alghaithapp.workers.dev
```

## 5) ترحيل الصور القديمة من Supabase

```bash
cd backend
npm install
npm run migrate-supabase-to-r2 -- --dry-run
npm run migrate-supabase-to-r2
```

## 6) التحقق

1. ارفع صورة من التطبيق (تاجر/زبون)
2. تأكد أن الرابط الجديد يحتوي `workers.dev/media/` أو `cdn.alghaithst.com`
3. راقب **Supabase → Usage → Storage Egress** خلال أيام

## Fallback

إذا فشل R2 لأي سبب، Worker يعود تلقائياً لـ Supabase Storage حتى لا يتوقف الرفع.
