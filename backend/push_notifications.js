const admin = require('firebase-admin');

const ANDROID_NOTIFICATION_CHANNEL_ID = 'alghaith_orders_v3';
const ANDROID_NOTIFICATION_SOUND = 'alghaith_notify';
const IOS_NOTIFICATION_SOUND = 'alghaith_notify.wav';

let initialized = false;

function initFirebaseAdmin() {
  if (initialized) return true;

  const raw = String(process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '').trim();
  if (!raw) {
    return false;
  }

  try {
    const credentials = JSON.parse(raw);
    if (!credentials?.project_id || !credentials?.client_email || !credentials?.private_key) {
      console.error('push: FIREBASE_SERVICE_ACCOUNT_JSON is missing required fields.');
      return false;
    }
    admin.initializeApp({
      credential: admin.credential.cert(credentials),
    });
    initialized = true;
    return true;
  } catch (error) {
    console.error('push: failed to initialize Firebase Admin:', error?.message || error);
    return false;
  }
}

function isPushConfigured() {
  return initFirebaseAdmin();
}

function normalizeData(data = {}) {
  const normalized = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    normalized[String(key)] = String(value);
  }
  return normalized;
}

async function sendPushToTokens(
  tokens,
  { title, body, data = {}, showSystemBanner = false } = {}
) {
  const uniqueTokens = [...new Set((tokens || []).map((item) => String(item || '').trim()).filter(Boolean))];
  if (!uniqueTokens.length) {
    return { sent: 0, failed: 0, invalidTokens: [] };
  }
  if (!initFirebaseAdmin()) {
    return { sent: 0, failed: uniqueTokens.length, invalidTokens: [], skipped: true };
  }

  const messaging = admin.messaging();
  const safeTitle = String(title || 'الغيث').trim();
  const safeBody = String(body || '').trim();
  const message = {
    tokens: uniqueTokens,
    data: normalizeData({
      ...data,
      title: safeTitle,
      body: safeBody,
    }),
    android: {
      priority: 'high',
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          'content-available': 1,
          badge: 1,
          sound: IOS_NOTIFICATION_SOUND,
        },
      },
    },
  };

  // إشعار النظام يُضاف فقط لبعض الإشعارات المهمة (مثل تغيير الحساب).
  // باقي الإشعارات ترسل data-only، والتطبيق يعرضها بنفسه
  // عبر flutter_local_notifications بشكل صحيح مع العنوان والمحتوى.
  if (showSystemBanner && safeBody) {
    message.notification = {
      title: safeTitle,
      body: safeBody,
    };
    message.android = {
      ...message.android,
      notification: {
        channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
        sound: ANDROID_NOTIFICATION_SOUND,
      },
    };
  }

  const response = await messaging.sendEachForMulticast(message);

  const invalidTokens = [];
  response.responses.forEach((item, index) => {
    if (item.success) return;
    const code = item.error?.code || '';
    if (
      code === 'messaging/invalid-registration-token' ||
      code === 'messaging/registration-token-not-registered'
    ) {
      invalidTokens.push(uniqueTokens[index]);
    }
  });

  return {
    sent: response.successCount,
    failed: response.failureCount,
    invalidTokens,
  };
}

module.exports = {
  isPushConfigured,
  sendPushToTokens,
};
