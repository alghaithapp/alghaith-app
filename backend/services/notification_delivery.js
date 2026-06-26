const admin = require('firebase-admin');
const {
  ANDROID_NOTIFICATION_CHANNEL_ID,
  ANDROID_NOTIFICATION_SOUND,
  IOS_NOTIFICATION_SOUND,
  isPushConfigured,
  initFirebaseAdmin,
} = require('../push_notifications');

function normalizeData(data = {}) {
  const normalized = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    if (key === 'showSystemBanner') continue;
    normalized[String(key)] = String(value);
  }
  return normalized;
}

async function sendPushToTokensDirect(
  tokens,
  { title, body, data = {}, showSystemBanner = false } = {}
) {
  const uniqueTokens = [
    ...new Set((tokens || []).map((item) => String(item || '').trim()).filter(Boolean)),
  ];
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
      ttl: 45000,
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

  if (showSystemBanner) {
    message.notification = { title: safeTitle, body: safeBody };
    message.android.notification = {
      channelId: ANDROID_NOTIFICATION_CHANNEL_ID,
      sound: ANDROID_NOTIFICATION_SOUND,
    };
    message.apns.payload.aps.alert = { title: safeTitle, body: safeBody };
  }

  const response = await messaging.sendEachForMulticast(message);
  const invalidTokens = [];
  response.responses.forEach((item, index) => {
    if (item.success) return;
    const code = item.error?.code || '';
    if (code.includes('registration-token-not-registered') || code.includes('invalid')) {
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
  sendPushToTokensDirect,
};
