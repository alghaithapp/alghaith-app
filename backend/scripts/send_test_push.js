const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const { getDeviceTokensForPhone } = require('../supabase_repo');
const { sendPushToTokens } = require('../push_notifications');

async function main() {
  const phone = process.argv[2];
  if (!phone) {
    console.error('الرجاء تحديد رقم الهاتف كمعامل لتشغيل السكربت. مثال:');
    console.error('node backend/scripts/send_test_push.js +9647744009992');
    process.exit(1);
  }

  console.log(`البحث عن رموز الأجهزة للرقم: ${phone}...`);
  const rows = await getDeviceTokensForPhone(phone);
  const tokens = rows.map((r) => r.token).filter(Boolean);

  if (!tokens.length) {
    console.error(`❌ لم يتم العثور على أي رموز أجهزة مسجلة للرقم: ${phone}. يرجى التأكد من تسجيل الدخول في التطبيق بهذا الرقم وتفعيل أذونات الإشعارات.`);
    process.exit(1);
  }

  console.log(`✅ تم العثور على ${tokens.length} رمز جهاز مسجل. جاري إرسال إشعار تجريبي لتشغيل نغمة الصوت المخصصة...`);

  const payload = {
    title: 'تنبيه تجربة الصوت 🔔',
    body: 'هذا إشعار تجريبي مرسل من السيرفر الخلفي لاختبار نغمة الصوت المخصصة.',
    data: {
      category: 'system',
      orderId: 'test-fcm-123'
    },
    showSystemBanner: true
  };

  const result = await sendPushToTokens(tokens, payload);

  console.log('النتيجة:', result);
  if (result.sent > 0) {
    console.log('🎉 تم إرسال الإشعار بنجاح إلى جهازك! يرجى التحقق وسماع الصوت الآن.');
  } else {
    console.error('❌ فشل إرسال الإشعار. يرجى التحقق من إعدادات Firebase والاتصال.');
  }
}

main().catch((err) => {
  console.error('حدث خطأ أثناء التشغيل:', err);
});
