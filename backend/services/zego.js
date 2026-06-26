const { generateToken04 } = require('./zego_token04');

const TOKEN_TTL_SECONDS = 3600;

function getZegoConfig() {
  const appIdRaw = String(process.env.ZEGO_APP_ID || '').trim();
  const serverSecret = String(process.env.ZEGO_SERVER_SECRET || '').trim();
  const appId = Number.parseInt(appIdRaw, 10);
  return {
    appId: Number.isFinite(appId) ? appId : 0,
    serverSecret,
    enabled: Number.isFinite(appId) && appId > 0 && serverSecret.length === 32,
  };
}

function buildRoomId(threadType, threadId) {
  const safeType = String(threadType || 'order')
    .replace(/[^a-z0-9]/gi, '')
    .slice(0, 12)
    .toLowerCase();
  const safeId = String(threadId || '')
    .replace(/[^a-zA-Z0-9_-]/g, '_')
    .slice(0, 40);
  return `zg_${safeType || 'thread'}_${safeId || 'x'}`.slice(0, 64);
}

function userIdFromPhone(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (!digits) return '0';
  return digits.length > 15 ? digits.slice(-15) : digits;
}

function buildStreamId(userId) {
  const safe = String(userId).replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 48);
  return `a_${safe || 'u'}`.slice(0, 64);
}

function buildRtcToken(roomId, userId) {
  const { appId, serverSecret, enabled } = getZegoConfig();
  if (!enabled) {
    throw new Error('ZEGOCLOUD is not configured on the server.');
  }

  const payload = JSON.stringify({
    room_id: roomId,
    privilege: {
      1: 1,
      2: 1,
    },
    stream_id_list: null,
  });

  const token = generateToken04(
    appId,
    userId,
    serverSecret,
    TOKEN_TTL_SECONDS,
    payload
  );

  return {
    appId,
    token,
    roomId,
    channelName: roomId,
    userId,
    streamId: buildStreamId(userId),
    expiresAt: Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS,
  };
}

function buildCallSession(threadType, threadId, callerPhone) {
  const roomId = buildRoomId(threadType, threadId);
  const userId = userIdFromPhone(callerPhone);
  const session = buildRtcToken(roomId, userId);
  return {
    ...session,
    threadType: String(threadType || 'order').trim(),
    threadId: String(threadId || '').trim(),
  };
}

module.exports = {
  getZegoConfig,
  buildRoomId,
  userIdFromPhone,
  buildStreamId,
  buildRtcToken,
  buildCallSession,
};
