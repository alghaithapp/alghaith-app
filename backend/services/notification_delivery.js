const admin = require('firebase-admin');
const {
  ANDROID_NOTIFICATION_CHANNEL_ID,
  ANDROID_TAXI_REQUEST_CHANNEL_ID,
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

const FCM_BATCH_SIZE = 500;

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

  if (!uniqueTokens.length) return { sent: 0, failed: 0, invalidTokens: [] };

  const messaging = admin.messaging();
  const safeTitle = String(title || 'الغيث').trim();
  const safeBody = String(body || '').trim();
  const category = String(data?.category ?? '').trim();
  const eventKey = String(data?.eventKey ?? '').trim();
  const isIncomingCall =
    category === 'call' || eventKey === 'call:incoming';
  const isTaxiRequest = category === 'taxi' && eventKey === 'taxi:pool_new';
  const wantsBanner = !dataOnly && (showSystemBanner || isIncomingCall || isTaxiRequest);

  function buildBatchMessage(batchTokens) {
    const apnsHeaders = {
      'apns-expiration': isTaxiRequest ? '300' : '45',
    };
    const apnsAps = {
      'content-available': 1,
    };

    if (wantsBanner) {
      apnsHeaders['apns-priority'] = '10';
      apnsHeaders['apns-push-type'] = 'alert';
      apnsAps.alert = { title: safeTitle, body: safeBody };
      apnsAps.sound = isIncomingCall ? IOS_INCOMING_CALL_SOUND : IOS_NOTIFICATION_SOUND;
      apnsAps.badge = 1;
      apnsAps.mutableContent = 1;
      if (isIncomingCall) {
        apnsAps['interruption-level'] = 'time-sensitive';
      }
    } else {
      apnsHeaders['apns-priority'] = '5';
      apnsHeaders['apns-push-type'] = 'background';
    }

    const msg = {
      tokens: batchTokens,
      data: normalizeData({
        ...data,
        title: safeTitle,
        body: safeBody,
      }),
      android: {
        priority: 'high',
        ttl: isTaxiRequest ? 300000 : 45000,
      },
      apns: {
        headers: apnsHeaders,
        payload: {
          aps: apnsAps,
        },
      },
    };

    if (wantsBanner) {
      msg.notification = { title: safeTitle, body: safeBody };
      msg.android.notification = {
        channelId: isIncomingCall
          ? ANDROID_INCOMING_CALL_CHANNEL_ID
          : isTaxiRequest
            ? ANDROID_TAXI_REQUEST_CHANNEL_ID
          : ANDROID_NOTIFICATION_CHANNEL_ID,
        sound: isIncomingCall ? ANDROID_INCOMING_CALL_SOUND : ANDROID_NOTIFICATION_SOUND,
        priority: isIncomingCall ? 'max' : 'high',
        visibility: isIncomingCall ? 'public' : 'private',
        defaultVibrateTimings: isIncomingCall,
        notificationCount: isIncomingCall ? 1 : undefined,
      };
      if (isIncomingCall) {
        msg.android.collapseKey = 'alghaith_incoming_call';
        msg.android.ttl = 120000;
      }
    }
    return msg;
  }

  let totalSent = 0;
  let totalFailed = 0;
  const allInvalidTokens = [];
  const errors = [];

  for (let i = 0; i < uniqueTokens.length; i += FCM_BATCH_SIZE) {
    const batch = uniqueTokens.slice(i, i + FCM_BATCH_SIZE);
    try {
      const response = await messaging.sendEachForMulticast(buildBatchMessage(batch));
      totalSent += response.successCount;
      totalFailed += response.failureCount;
      response.responses.forEach((item, index) => {
        if (item.success) return;
        const code = item.error?.code || '';
        const message = item.error?.message || '';
        if (code.includes('registration-token-not-registered') || code.includes('invalid')) {
          allInvalidTokens.push(batch[index]);
        }
        errors.push({ index, code, message });
      });
    } catch (batchError) {
      console.error('push: FCM batch send error:', batchError?.message || batchError);
      totalFailed += batch.length;
    }
  }

  return {
    sent: totalSent,
    failed: totalFailed,
    invalidTokens: allInvalidTokens,
    errors,
  };
}

module.exports = {
  sendPushToTokensDirect,
};
