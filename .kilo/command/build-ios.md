---
description: بناء تطبيق iOS (Release) عبر Codemagic ورفعه إلى TestFlight
---

# بناء iOS

## عبر Kilo (تلقائي من GitHub)
ادفع التعديلات إلى `main` و Codemagic سيبني تلقائياً ويرفع إلى TestFlight:

```powershell
git add .
git commit -m "وصف التغييرات"
git push origin main
```

## عبر Codemagic Dashboard (يدوي)
1. اذهب إلى https://codemagic.io
2. سجل دخول بحساب alghaithapp@gmail.com
3. اختر المشروع → Start new build
4. Workflow: **Al-Ghaith iOS Release** (ios-release)
5. Branch: main
6. Start build

## متطلبات أساسية
- `firebase_credentials` group في Codemagic → Environment variables
  - `IOS_GOOGLE_SERVICE_INFO_PLIST` — مشفر base64
  - `ANDROID_GOOGLE_SERVICES_JSON` — مشفر base64
- App Store Connect integration → اسم المفتاح: `algaith`
- شهادة Distribution + Provisioning profile لـ `com.alghaith.app` في Code signing identities

## بعد البناء
- الـ IPA يُرفع تلقائياً إلى TestFlight
- شاهد البريد alghaithapp@gmail.com لحالة الرفع
