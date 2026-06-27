const express = require('express');
const router = express.Router();

/**
 * Feature Flags — التحكم بالميزات عن بُعد بدون بناء التطبيق.
 *
 * الفكرة: التطبيق يسأل هذا الـ endpoint عند التشغيل وبشكل دوري.
 * لو غيرت قيمة flag هنا، يحتاج المستخدم يفتح التطبيق مرة ثانية عشان يسري التغيير.
 *
 * القيم الافتراضية (fallback) موجودة في Flutter إذا تعذّر الاتصال.
 */

const features = {
  // ── Chat ────────────────────────────────────────────────────────
  chat_v2: true,               // Socket.io عبر VPS بدل HTTP polling
  chat_timestamps: true,       // إظهار وقت الإرسال في الرسائل
  chat_date_separators: true,  // فواصل التاريخ بين الأيام (مثل واتساب)

  // ── Taxi ────────────────────────────────────────────────────────
  taxi_cancel_direct: true,    // إلغاء مباشر للزبون بدون موافقة السائق
  taxi_show_banner: true,      // إظهار إشعار النظام للسائق عند طلب جديد

  // ── Calls ───────────────────────────────────────────────────────
  call_cancelled_notify: true, // إيقاف الرنين عند الطرف الآخر إذا ألغى المتصل

  // ── General ─────────────────────────────────────────────────────
  use_vps_socket: true,        // الاتصال بـ VPS Socket.io (true) أو polling (false)
  inbox_filter: true,          // فلترة المحادثات حسب النوع في صندوق الوارد

  // ── قراءة من متغيرات البيئة (أولوية أعلى) ─────────────────────
};

// تطبيق override من متغيرات البيئة لو موجودة
for (const key of Object.keys(features)) {
  const envKey = `FEATURE_${key.toUpperCase()}`;
  if (process.env[envKey] !== undefined) {
    features[key] = process.env[envKey] === 'true' || process.env[envKey] === '1';
  }
}

router.get('/features', (_req, res) => {
  res.json({
    ...features,
    _meta: {
      version: '1.0',
      updatedAt: new Date().toISOString(),
    },
  });
});

module.exports = router;
