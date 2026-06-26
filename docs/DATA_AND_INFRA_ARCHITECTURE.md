# بنية البيانات والبنية التحتية — سياسات الغيث

> هذا المستند يحدّد **مبادئ التصميم** التي نتبعها عند توسيع المنصة: قاعدة البيانات، التخزين، التكسي، الإشعارات، والكاش المحلي.
>
> مكمّل لـ [`MODULAR_ARCHITECTURE.md`](./MODULAR_ARCHITECTURE.md) (تنظيم الكود) و [`TAXI_API.md`](./TAXI_API.md) (واجهة التكسي الحالية).

---

## 1. قاعدة البيانات (PostgreSQL / Supabase)

### المبدأ العام

| نوع البيانات | أين تُخزَّن | لماذا |
|--------------|-------------|--------|
| **بيانات عمل أساسية** | جداول مستقلة + أعمدة مفهرسة | استعلامات، تقارير، صلاحيات، أداء |
| **حالة مؤقتة / تفضيلات UI** | JSON في `app_state` أو جدول `user_preferences` | مرونة بدون تعقيد الاستعلام |
| **مرفقات كبيرة / لقطات** | R2 + مرجع URL في الجدول | لا Base64 في Postgres |

> **قاعدة ذهبية:** كلما زاد الاعتماد على `JSONB` لبيانات تُستعلم عنها أو تُفلتر أو تُحسب عليها تقارير، أصبحت الاستعلامات أصعب وأبطأ. JSON مناسب للمؤقت فقط.

### ما يبقى في JSON (مؤقت / تفضيلات)

يُخزَّن في `app_state.state` أو (مستقبلاً) `user_preferences`:

- آخر شاشة / تبويب مفتوح
- إعدادات الواجهة (`darkMode`, `inAppAlertsEnabled`, لغة العرض المحلية)
- فلاتر البحث الأخيرة (غير محفوظة كقائمة منتجات)
- مسودات غير مُرسلة (نموذج نصف مكتمل)
- علامات onboarding (`skippedCustomerSetup`, …)
- cache metadata صغير (طوابع زمنية للمزامنة فقط — ليس المحتوى نفسه)

### ما يجب أن يكون جداولاً (بيانات عمل)

| المجال | الجدول الحالي / المستهدف | ملاحظات |
|--------|--------------------------|---------|
| المستخدمون | `app_users` | ✅ موجود |
| ملف الزبون | `customer_profiles` | ✅ موجود |
| عناوين الزبون | `customer_addresses` | ✅ موجود — لا تُكرَّر داخل JSON |
| الطلبات | `customer_orders` | ✅ موجود — **لا** `orders[]` داخل `app_state` |
| المفضلة | `customer_favorites` | ✅ موجود |
| التاجر | `merchant_profiles` | ✅ موجود |
| المنتجات | `merchant_products` | ✅ موجود |
| صلاحيات الإدارة | `admin_roles` | ✅ موجود |
| السائق | `driver_profiles` | ✅ موجود |
| المندوب | `courier_profiles` | ✅ موجود |
| التكسي | `taxi_requests` + أعمدة مفهرسة | ⚠️ يوجد `request_payload JSONB` — للتفاصيل فقط |
| الإشعارات | `notification_outbox` | ✅ `20260629_notification_outbox.sql` + BullMQ/inline worker |
| الصور | `media_assets` | ✅ `20260628_media_assets.sql` + `/db/media/upload` |

### الوضع الحالي في المشروع (ديون تقنية معروفة)

```
app_state.state  ← UI وتفضيلات فقط (darkMode, skippedCustomerSetup, taxiFavoritePlaces, …)
customer_orders.order_payload JSONB  ← مقبول كـ snapshot للعرض، الأعمدة المفهرسة للحالة
taxi_requests.request_payload JSONB  ← مقبول للتفاصيل؛ الحالة والموقع في أعمدة منفصلة
```

**خطة الخروج من JSON للبيانات الأساسية:**

1. **المرحلة أ** — ~~التوقف عن كتابة `orders` / `items` في `app_state`~~ ✅ **تم:**
   - `backend/services/app_state_policy.js` — يحذف `orders`/`items` عند الحفظ والقراءة
   - `merge_app_state` (SQL) — يدمج بدون `orders`/`items`
   - Flutter: `AppStatePolicy` في `database_repository.saveUserState`
   - `merchant_service._buildRemoteState()` — لم يعد يرسل `items`
   - النسخة المحلية على الجهاز ما زالت تحتفظ بالطلبات/المنتجات للعمل offline
2. **المرحلة ب** — ~~سكربت ترحيل إلى `merchant_profiles`, `driver_profiles`, `courier_profiles`~~ ✅ **تم:**
   - `supabase/20260626_driver_courier_profiles.sql`
   - `backend/supabase_repo/operator_profiles.js` + `/db/driver-profile` + `/db/courier-profile`
   - `backend/scripts/migrate_app_state_to_tables.js`
   - `merchantStore` / `driverProfile` / `courierProfile` محظورة في `app_state`
3. **المرحلة ج** — ~~تقليص `app_state` إلى مفاتيح UI فقط~~ ✅ **تم:**
   - `ALLOWED_APP_STATE_KEYS` + `sanitizeAppState` في backend و Flutter
   - `supabase/20260627_app_state_ui_only.sql` — `admin_roles`, `merchant_offers`, merge UI-only
   - Flutter: `AppUiPreferences.toRemoteState()` — المصدر الوحيد لـ `app_state`
   - عروض التاجر → `merchant_offers` + `/db/merchant-offers`
   - صلاحيات الإدارة → `admin_roles` (بدل `adminAccess` في JSON)

### مثال: شكل `app_state` المستهدف

```json
{
  "darkMode": true,
  "inAppAlertsEnabled": true,
  "lastMainTab": 2,
  "homeCategoryFilter": "restaurant",
  "catalogSearchHistory": ["بيتزا", "قهوة"],
  "drafts": {
    "real_estate_form": { "step": 2 }
  },
  "syncHints": {
    "catalogFetchedAt": "2026-06-25T10:00:00Z"
  }
}
```

**لا يظهر هنا:** `orders`, `merchantStore`, `driverProfile`, `cart`, `adminAccess`.

### فهرسة واستعلام

- أي حقل يُستخدم في `WHERE` / `ORDER BY` / تقارير لوحة الإدارة → **عمود** وليس مفتاح JSON.
- `JSONB` مسموح كـ **ملحق** (metadata، snapshot تاريخي، إعدادات فرعية نادرة القراءة).

---

## 2. التخزين — Cloudflare R2 + إصدارات الصور

### الوضع الحالي

- رفع عبر `CloudflareService` / Worker → URL عام
- `ImageStorageService` (Flutter) + `backend/services/image_refs.js` — تطبيع URL وإزالة Base64 من الاستجابات
- بعض الحقول ما زالت `*_base64` في Postgres (قيد الإزالة)

### الهدف: نظام Image Versions

بدلاً من ملف واحد `store.jpg`، كل أصل منطقي يملك عدة إصدارات:

```
merchants/{merchantId}/logo/
  original.webp      ← أرشيف / لوحة إدارة فقط
  512.webp           ← بطاقات المتجر
  256.webp           ← قوائم مدمجة
  thumbnail.webp     ← 64–128px، خرائط، إشعارات
```

#### جدول `media_assets` (مقترح)

| عمود | نوع | وصف |
|------|-----|-----|
| `id` | uuid | PK |
| `owner_type` | text | `merchant` \| `product` \| `user` \| `listing` |
| `owner_id` | text | معرف المالك |
| `role` | text | `logo` \| `cover` \| `gallery` \| `avatar` |
| `variant` | text | `original` \| `512` \| `256` \| `thumbnail` |
| `url` | text | R2 public URL |
| `width` | int | |
| `height` | int | |
| `bytes` | int | |
| `created_at` | timestamptz | |

الواجهات تخزّن **مرجعاً** (`media_asset_id` أو URL الـ variant المناسب)، وليس Base64.

#### مسار الرفع (مستهدف)

```
Client → API /media/upload
  → Worker يستقبل original
  → يولّد 512 / 256 / thumbnail (sharp في Worker أو job خلفي)
  → يكتب كل variants إلى R2
  → يرجع { original, w512, w256, thumb }
```

#### Flutter

- قوائم وبطاقات: `AppImage` يختار `w256` أو `thumbnail` افتراضياً
- تكبير / معاينة: `original` أو `w512` عند الطلب
- لا تحميل `original` في `ListView`

---

## 3. التكسي — فصل كامل من البداية

التكسي **أكثر خدمة ستستهلك موارد** (موقع لحظي، مطابقة، تسعير، إشعارات متكررة). الهدف: حدود واضحة قابلة للفصل إلى خدمة مستقلة لاحقاً.

### البنية المستهدفة (داخل Monolith اليوم → Microservice غداً)

```
backend/domains/taxi/
├── index.js                 # mount + workers
├── routes/                  # Taxi API فقط (/db/taxi/*)
├── repository/              # Taxi Repository — SQL فقط
│   ├── requests.js
│   ├── drivers.js
│   └── pricing_rules.js
├── services/
│   ├── matching.js          # Taxi Matching
│   ├── pricing.js           # Taxi Pricing
│   ├── tracking.js          # Taxi Tracking (مواقع، ETA)
│   └── trip_lifecycle.js
├── notifications/           # Taxi Notifications — لا FCM مباشر من routes
│   └── enqueue.js           # يضيف إلى Notification Queue
└── workers/
    ├── scheduler.js         # مهلة الطلبات، إعادة الإرسال
    └── location_cleanup.js
```

### قواعد

| القاعدة | التفاصيل |
|---------|----------|
| **Taxi API** | كل مسارات التكسي تحت `/db/taxi` — لا منطق تكسي في `merchants.js` أو `users.js` |
| **Taxi Database** | جداول `taxi_*` فقط؛ لا تخزين رحلات في `app_state` |
| **ملفات صغيرة** | كل service &lt; ~300 سطر؛ لا `taxi_mega.js` |
| **لا اعتماد دائري** | `taxi` يستدعي `users` للقراءة فقط؛ الإشعارات عبر Queue |

### الوضع الحالي → الخطوة التالية

| مكوّن | اليوم | التالي |
|--------|-------|--------|
| Domain registry | `backend/domains/taxi/index.js` | نقل `routes/taxi.js` → `domains/taxi/routes/` |
| Repository | `supabase_repo/taxi.js` | `domains/taxi/repository/` |
| Matching / Pricing | `backend/services/taxi_*` | نقل تحت `domains/taxi/services/` |
| Push | `backend/push/taxi_push_events.js` | `domains/taxi/notifications/` + Queue |
| DB | `taxi_requests` + JSONB payload | أعمدة إضافية للاستعلام؛ تقليص payload |

### متى Microservice؟

عندما يتجاوز التكسي ~40% حمل CPU أو يحتاج نشراً مستقلاً:

1. انسخ `domains/taxi/` إلى repo `alghaith-taxi-api`
2. نفس قاعدة البيانات (أو schema منفصل) في البداية
3. Flutter يستدعي `TAXI_API_URL` بدلاً من `/db/taxi`

---

## 4. الإشعارات — FCM + Notification Queue

### الوضع الحالي

- **FCM** عبر `PushNotificationService` (Flutter) و `backend/push/*`
- الإرسال غالباً **متزامن** من مسار الطلب (خطر عند ذروة الطلبات)

### الهدف: طابور إشعارات

```
حدث (طلب جديد / تكسي / موافقة تاجر)
  → API يكتب صفاً في notification_outbox (Postgres)
  → BullMQ job (Redis)
  → Worker يقرأ الدفعة ويرسل FCM
  → يحدّث الحالة: sent | failed | retry
```

#### مكدس مقترح

| طبقة | تقنية |
|------|--------|
| Queue | **Redis** + **BullMQ** |
| سجل دائم | جدول `notification_outbox` في Supabase |
| إرسال | FCM Admin SDK (كما اليوم) |
| Rate limit | BullMQ `limiter` — مثلاً 500 إشعار/دقيقة |

#### جدول `notification_outbox` (مقترح)

```sql
create table notification_outbox (
  id uuid primary key default gen_random_uuid(),
  event_key text not null,
  audience_role text not null,
  target_phone text,
  fcm_tokens text[],
  title text not null,
  body text not null,
  data jsonb not null default '{}',
  status text not null default 'pending',  -- pending | processing | sent | failed
  attempts int not null default 0,
  scheduled_at timestamptz not null default now(),
  sent_at timestamptz,
  created_at timestamptz not null default now()
);
create index on notification_outbox (status, scheduled_at);
```

#### فوائد

- لا يتجمّد `POST /db/orders` بسبب آلاف `sendToDevice`
- إعادة محاولة تلقائية عند فشل FCM
- مراقبة ولوحة: «كم إشعار معلّق؟»

---

## 5. الكاش المحلي (Flutter)

### الوضع الحالي

| الاستخدام | التقنية |
|-----------|---------|
| جلسة، OTP hints | `SharedPreferences` (`local_session_store`) |
| كتالوج، فئات الرئيسية | `SharedPreferences` (`catalog_cache`, `home_categories_cache`) |
| صندوق push محلي | `SharedPreferences` (`push_notification_inbox`) |

**مناسب** للإعدادات والقيم الصغيرة.

### عندما تكبر البيانات

إذا تجاوز الكاش المحلي ~1–2 MB أو احتجنا استعلامات (مثلاً كتالوج 5000 منتج، سجل طلبات offline):

| خيار | ملاحظات |
|------|---------|
| **Hive CE** | خفيف، سريع، مناسب لـ key-value وقوائم JSON |
| **Isar** | فهرسة واستعلامات أقوى؛ مناسب لكتالوج + طلبات محلية |

#### خطة ترحيل تدريجية

1. **يبقى SharedPreferences:** لغة، ثيم، توكن الجلسة، إعدادات بسيطة
2. **ينتقل إلى Hive/Isar:**
   - `catalog_cache` → box `catalog_items`
   - طلبات الزبون الأخيرة (عرض offline)
   - inbox الإشعارات إذا تجاوز 40 عنصراً
3. **واجهة موحدة:** `lib/core/storage/local_cache.dart` يخفي التطبيق عن المحرك

```dart
// مستهدف
abstract class LocalCache {
  Future<void> writeCatalog(List<ListItem> items);
  Future<List<ListItem>?> readCatalog();
  Future<void> clearOnLogout();
}
```

---

## 6. ملخص القرارات

| الموضوع | القرار |
|---------|--------|
| `app_state` JSONB | **مؤقت وUI فقط** — ليس طلبات ولا تاجر ولا سائق |
| بيانات العمل | **جداول مستقلة** مع فهارس |
| الصور | **R2 + variants** (`original`, `512`, `256`, `thumbnail`) |
| التكسي | **مجال معزول**: API / Repo / DB / Workers / Notifications |
| الإشعارات | **FCM + BullMQ + outbox** — لا إرسال جماعي متزامن |
| كاش Flutter | **SharedPreferences** للصغير؛ **Hive CE / Isar** عند النمو |

---

## 7. ترتيب التنفيذ المقترح

| # | مهمة | الجهد | الأثر |
|---|------|-------|-------|
| 1 | ~~إيقاف كتابة `orders`/`items` في `app_state`~~ | منخفض | عالٍ — **تم** (انظر أدناه) |
| 2 | ~~جداول `driver_profiles` / `courier_profiles` + ترحيل~~ | متوسط | عالٍ — **تم** |
| 2b | ~~تقليص `app_state` إلى UI فقط + `admin_roles` + `merchant_offers`~~ | متوسط | عالٍ — **تم** |
| 3 | ~~`media_assets` + رفع متعدد الأحجام~~ | متوسط | أداء Flutter — **تم** |
| 4 | ~~`notification_outbox` + BullMQ worker~~ | متوسط | استقرار الذروة — **تم** (fallback بدون Redis) |
| 5 | ~~نقل ملفات taxi تحت `domains/taxi/` بالكامل~~ | متوسط | فصل الخدمة — **تم** |
| 6 | ~~Hive CE لـ `catalog_cache`~~ | منخفض | أداء محلي — **تم** |

---

## 8. مراجع في المستودع

| مسار | محتوى |
|------|--------|
| `supabase/schema.sql` | الجداول الأساسية |
| `backend/supabase_repo/users.js` | `app_state` / `merge_app_state` |
| `backend/domains/taxi/` | بذرة فصل التكسي |
| `backend/services/image_refs.js` | تطبيع صور API |
| `lib/services/image_storage_service.dart` | رفع Flutter → R2 |
| `docs/FCM_SETUP.md` | إعداد FCM |
| `docs/MODULAR_ARCHITECTURE.md` | وحدات Flutter و Backend |
