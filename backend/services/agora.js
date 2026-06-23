const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const TOKEN_TTL_SECONDS = 3600;

function getAgoraConfig() {
  const appId = String(process.env.AGORA_APP_ID || '').trim();
  const appCertificate = String(process.env.AGORA_APP_CERTIFICATE || '').trim();
  return {
    appId,
    appCertificate,
    enabled: appId.length > 0 && appCertificate.length > 0,
  };
}

function buildChannelName(threadType, threadId) {
  const safeType = String(threadType || 'order')
    .replace(/[^a-z0-9]/gi, '')
    .slice(0, 12)
    .toLowerCase();
  const safeId = String(threadId || '')
    .replace(/[^a-zA-Z0-9_-]/g, '_')
    .slice(0, 40);
  return `ag_${safeType || 'thread'}_${safeId || 'x'}`.slice(0, 64);
}

function uidFromPhone(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (!digits) return 0;
  const tail = digits.length > 9 ? digits.slice(-9) : digits;
  const parsed = Number.parseInt(tail, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return 0;
  return (parsed % 2147483646) + 1;
}

function buildRtcToken(channelName, uid) {
  const { appId, appCertificate, enabled } = getAgoraConfig();
  if (!enabled) {
    throw new Error('Agora is not configured on the server.');
  }

  const privilegeExpiredTs =
    Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;
  const numericUid = Number.isFinite(uid) ? Math.max(0, Math.floor(uid)) : 0;

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    numericUid,
    RtcRole.PUBLISHER,
    privilegeExpiredTs
  );

  return {
    appId,
    token,
    channelName,
    uid: numericUid,
    expiresAt: privilegeExpiredTs,
  };
}

function buildCallSession(threadType, threadId, callerPhone) {
  const channelName = buildChannelName(threadType, threadId);
  const uid = uidFromPhone(callerPhone);
  const session = buildRtcToken(channelName, uid);
  return {
    ...session,
    threadType: String(threadType || 'order').trim(),
    threadId: String(threadId || '').trim(),
  };
}

module.exports = {
  getAgoraConfig,
  buildChannelName,
  uidFromPhone,
  buildRtcToken,
  buildCallSession,
};
