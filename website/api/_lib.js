const DEFAULT_TTL_MS = 5 * 60 * 1000;
const DEFAULT_OTP_LENGTH = 6;

function getEnv(name, fallback = '') {
  const value = process.env[name];
  return value == null || value === '' ? fallback : value;
}

function normalizePhone(phone) {
  const raw = String(phone || '').trim().replace(/[\s-]/g, '');
  if (!raw) return '';

  const digits = raw.replace(/\D/g, '');
  if (digits.startsWith('0')) {
    return `964${digits.slice(1)}`;
  }
  if (digits.startsWith('964')) {
    return digits;
  }
  return `964${digits}`;
}

function normalizePhoneForDisplay(phone) {
  const normalized = normalizePhone(phone);
  return normalized ? `+${normalized}` : '';
}

function generateOtp(length = DEFAULT_OTP_LENGTH) {
  const safeLength = Number.isFinite(length) && length > 0 ? length : DEFAULT_OTP_LENGTH;
  const upperBound = 10 ** safeLength;
  const lowerBound = 10 ** (safeLength - 1);
  return String(Math.floor(lowerBound + Math.random() * (upperBound - lowerBound)));
}

async function readJsonBody(req) {
  if (!req) return {};
  if (typeof req.body === 'string') {
    try {
      return JSON.parse(req.body);
    } catch (_) {
      return {};
    }
  }
  if (req.body && typeof req.body === 'object') {
    return req.body;
  }
  return {};
}

async function sendOtpViaOtpiq(phoneNumber, verificationCode, channel = 'sms') {
  const otpiqApiKey = getEnv('OTPIQ_API_KEY');
  const otpiqBaseUrl = getEnv('OTPIQ_BASE_URL', 'https://api.otpiq.com').replace(/\/$/, '');
  const smsProvider = getEnv('OTPIQ_SMS_PROVIDER', 'sms');
  const whatsappProvider = getEnv('OTPIQ_WHATSAPP_PROVIDER', 'whatsapp-telegram-sms');
  const telegramProvider = getEnv('OTPIQ_TELEGRAM_PROVIDER', 'whatsapp-telegram-sms');

  if (!otpiqApiKey) {
    throw new Error('OTPIQ_API_KEY is not configured.');
  }

  const normalizedChannel = String(channel || 'sms').trim().toLowerCase();
  const provider =
    normalizedChannel === 'whatsapp'
      ? whatsappProvider
      : normalizedChannel === 'telegram'
        ? telegramProvider
        : smsProvider;

  const response = await fetch(`${otpiqBaseUrl}/api/sms`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${otpiqApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      phoneNumber,
      smsType: 'verification',
      provider,
      verificationCode,
    }),
  });

  const bodyText = await response.text();
  let payload = null;
  try {
    payload = bodyText ? JSON.parse(bodyText) : null;
  } catch (_) {
    payload = null;
  }

  if (!response.ok) {
    const message =
      payload?.message ||
      payload?.error ||
      bodyText ||
      `OTPIQ request failed with status ${response.status}`;
    throw new Error(message);
  }

  return payload;
}

function supabaseHeaders() {
  const serviceRoleKey = getEnv('SUPABASE_SERVICE_ROLE_KEY');
  if (!serviceRoleKey) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY is not configured.');
  }

  return {
    Authorization: `Bearer ${serviceRoleKey}`,
    apikey: serviceRoleKey,
    'Content-Type': 'application/json',
  };
}

function supabaseUrl() {
  const raw = getEnv('SUPABASE_URL');
  if (!raw) {
    throw new Error('SUPABASE_URL is not configured.');
  }
  return raw.replace(/\/$/, '');
}

async function loadOtpRequest(phone) {
  const response = await fetch(
    `${supabaseUrl()}/rest/v1/otp_requests?phone=eq.${encodeURIComponent(phone)}&select=phone,code,expires_at,channel,sms_id`,
    {
      headers: supabaseHeaders(),
    }
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || 'Failed to load OTP request.');
  }

  const rows = await response.json();
  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}

async function saveOtpRequest(phone, code, expiresAt, channel, smsId = null) {
  const response = await fetch(`${supabaseUrl()}/rest/v1/otp_requests?on_conflict=phone`, {
    method: 'POST',
    headers: {
      ...supabaseHeaders(),
      Prefer: 'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify({
      phone,
      code,
      expires_at: expiresAt,
      channel,
      sms_id: smsId,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || 'Failed to save OTP request.');
  }

  return response.json();
}

async function deleteAuthOtp(phone) {
  const response = await fetch(
    `${supabaseUrl()}/rest/v1/otp_requests?phone=eq.${encodeURIComponent(phone)}`,
    {
      method: 'DELETE',
      headers: {
        ...supabaseHeaders(),
        Prefer: 'return=minimal',
      },
    }
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || 'Failed to delete OTP request.');
  }

  return true;
}

module.exports = {
  DEFAULT_TTL_MS,
  generateOtp,
  getEnv,
  normalizePhone,
  normalizePhoneForDisplay,
  readJsonBody,
  loadOtpRequest,
  saveOtpRequest,
  deleteAuthOtp,
  sendOtpViaOtpiq,
};
