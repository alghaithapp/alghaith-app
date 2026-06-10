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

## 6) اختبار سريع

1. سجّل دخولاً من جهاز حقيقي (محاكي iOS لا يدعم push بشكل كامل).
2. وافق على صلاحية الإشعارات.
3. أنشئ طلباً من حساب زبون → يجب أن يصل إشعار للتاجر.
4. قبل الطلب من التاجر → يصل إشعار للزبون.

## ملاحظات

- بدون `google-services.json` / `GoogleService-Info.plist` يبقى التطبيق يعمل لكن **بدون push خارجي**.
- الإشعارات الداخلية (البانر داخل التطبيق) تبقى تعمل كما هي.
- يحتاج بناء APK/AAB/iOS جديد بعد إعداد Firebase.
