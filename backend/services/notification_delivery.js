const admin = require('firebase-admin');
const {
  ANDROID_NOTIFICATION_CHANNEL_ID,
  ANDROID_INCOMING_CALL_CHANNEL_ID,
  ANDROID_NOTIFICATION_SOUND,
  ANDROID_INCOMING_CALL_SOUND,
  IOS_NOTIFICATION_SOUND,
  IOS_INCOMING_CALL_SOUND,
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
  { title, body, data = {}, showSystemBanner = false, dataOnly = false } = {}
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
  const category = String(data?.category ?? '').trim();
  const isIncomingCall =
    category === 'call' || String(data?.eventKey ?? '').trim() === 'call:incoming';
  const wantsBanner = !dataOnly && (showSystemBanner || isIncomingCall);
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
          sound: isIncomingCall ? IOS_INCOMING_CALL_SOUND : IOS_NOTIFICATION_SOUND,
        },
      },
    },
  };

  if (wantsBanner) {
    message.notification = { title: safeTitle, body: safeBody };
    message.android.notification = {
      channelId: isIncomingCall
        ? ANDROID_INCOMING_CALL_CHANNEL_ID
        : ANDROID_NOTIFICATION_CHANNEL_ID,
      sound: isIncomingCall ? ANDROID_INCOMING_CALL_SOUND : ANDROID_NOTIFICATION_SOUND,
      priority: isIncomingCall ? 'max' : 'high',
      visibility: isIncomingCall ? 'public' : 'private',
      defaultVibrateTimings: isIncomingCall,
      notificationCount: isIncomingCall ? 1 : undefined,
    };
    if (isIncomingCall) {
      message.android.collapseKey = 'alghaith_incoming_call';
      message.android.ttl = 120000;
    }
    message.apns.payload.aps.alert = { title: safeTitle, body: safeBody };
    message.apns.payload.aps.sound = isIncomingCall
      ? IOS_INCOMING_CALL_SOUND
      : IOS_NOTIFICATION_SOUND;
    message.apns.headers['apns-push-type'] = 'alert';
    if (isIncomingCall) {
      message.apns.payload.aps['interruption-level'] = 'time-sensitive';
    }
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
