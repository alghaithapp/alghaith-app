# إعداد إشعارات FCM (الغيث)

## 1) Firebase Console

1. أنشئ مشروعاً في [Firebase Console](https://console.firebase.google.com/).
2. أضف تطبيق **Android** بـ package: `com.alghaith.app`.
3. حمّل `google-services.json` وضعه في `android/app/google-services.json`.
4. أضف تطبيق **iOS** بـ bundle: `com.alghaith.app`.
5. حمّل `GoogleService-Info.plist` وضعه في `ios/Runner/GoogleService-Info.plist`.
6. في **Project Settings → Cloud Messaging**:
   - Android: تأكد من تفعيل FCM.
   - iOS: ارفع مفتاح APNs (.p8) من Apple Developer.

## 2) Flutter

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

أو عدّل القيم في `lib/firebase_options.dart` يدوياً (استبدل `REPLACE_ME`).

ثم:

```bash
flutter pub get
```

## 3) iOS (Xcode)

1. افتح `ios/Runner.xcworkspace`.
2. **Signing & Capabilities** → أضف **Push Notifications**.
3. أضف **Background Modes** → **Remote notifications** (موجود في Info.plist).
4. ابنِ من Codemagic أو Xcode بعد ربط APNs.

## 4) Railway (Backend)

1. Firebase Console → **Project Settings → Service accounts** → **Generate new private key**.
2. انسخ محتوى JSON كاملاً إلى متغير البيئة:

```
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
```

3. نفّذ SQL في Supabase:

```
supabase/add_device_tokens.sql
supabase/add_push_inbox_state.sql
```

4. ادفع `backend/` إلى Railway (أو أعد النشر).

تحقق:

```
GET https://alghaith-app-production.up.railway.app/health
```

يجب أن يظهر `"pushConfigured": true`.

## 5) الإشعارات المفعّلة (المرحلة 1)

| الحدث | المستلم |
|-------|---------|
| طلب جديد | التاجر |
| قبول الطلب | الزبون |
| إلغاء الطلب | الزبون |
| جاهز للتوصيل | الزبون |
| تعيين مندوب | الزبون + التاجر |
| استلام من المتجر | الزبون |
| في الطريق | الزبون |
| تم التسليم | الزبون |
| اكتمال الطلب | الزبون |

## 6) صوت الإشعار المميز

التطبيق يستخدم صوتاً مخصصاً باسم `alghaith_notify.wav`.

لتغيير الصوت:

1. استبدل الملف في `assets/sounds/alghaith_notify.wav` بصوتك (أقل من 30 ثانية، WAV أو MP3 محوّل لـ WAV).
2. شغّل:

```bash
node scripts/generate_notification_sound.cjs
```

3. أعد بناء التطبيق (Android + iOS).

ملاحظات:

- **Android**: الملف يُنسخ إلى `android/app/src/main/res/raw/`.
- **iOS**: الملف يُنسخ إلى `ios/Runner/` ويُضمَّن في Xcode Resources.
- على Android، تغيير الصوت يستخدم قناة جديدة `alghaith_orders_v3` لأن القناة القديمة لا تتغير بعد إنشائها.

## 7) تذكير الإشعارات غير المقروءة

إذا وصلت إشعارات للمستخدم ولم يفتح التطبيق لمدة **ساعتين**، يرسل الخادم تذكيراً واحداً:

> «لديك X إشعارات لم تقرأها في الغيث»

عند فتح التطبيق يُصفَّر العداد تلقائياً عبر `PUT /db/push-inbox/opened`.

## 8) اختبار سريع

1. سجّل دخولاً من جهاز حقيقي (محاكي iOS لا يدعم push بشكل كامل).
2. وافق على صلاحية الإشعارات.
3. أنشئ طلباً من حساب زبون → يجب أن يصل إشعار للتاجر.
4. قبل الطلب من التاجر → يصل إشعار للزبون.

## ملاحظات

- بدون `google-services.json` / `GoogleService-Info.plist` يبقى التطبيق يعمل لكن **بدون push خارجي**.
- الإشعارات الداخلية (البانر داخل التطبيق) تبقى تعمل كما هي.
- يحتاج بناء APK/AAB/iOS جديد بعد إعداد Firebase.

## 9) Railway Deployment — Detailed

### 9.1 Set the environment variable

**Option A — Railway Dashboard:**
1. Open [Railway Dashboard](https://railway.app/project) → your project → **Variables**.
2. Add variable `FIREBASE_SERVICE_ACCOUNT_JSON`.
3. Paste the **entire** service account JSON as the value (including `{}` and quotes).
4. Deploy or restart.

**Option B — Railway CLI (recommended for CI):**
```bash
railway variables set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...", ...}'
```

**Option C — File reference (Railway CLI):**
```bash
railway variables set FIREBASE_SERVICE_ACCOUNT_JSON=@backend/firebase-service-account.json
```

**Option D — PowerShell helper (Windows):**
```powershell
.\scripts\configure_fcm_railway.ps1
```

### 9.2 Verify the variable is set

```bash
railway variables list | grep FIREBASE
```

Or check the `/health` endpoint:
```
GET https://your-project.up.railway.app/health
```
Expected response includes `"pushConfigured": true`.

### 9.3 Redeploy

```bash
cd backend
railway up
```

Or trigger a redeploy from the Railway Dashboard → Deployments → **Redeploy**.

### 9.4 Local testing with .env

Add to `backend/.env`:
```
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"...",...}
```

Then start the backend:
```bash
cd backend
node server.js
```

### 9.5 Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `pushConfigured: false` in /health | JSON missing or invalid | Check Railway variable is set correctly; validate JSON syntax |
| `Failed to parse private key` | Newlines in key are escaped | Ensure `\n` in private key are literal newlines, not `\\n` |
| `Credential implementation provided to initializeApp() must be a non-empty string` | Env var empty | Verify variable name matches `FIREBASE_SERVICE_ACCOUNT_JSON` exactly |
