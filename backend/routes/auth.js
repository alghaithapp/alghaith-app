const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const rateLimitLib = require('express-rate-limit');
const rateLimit = rateLimitLib.default || rateLimitLib;
const ipKeyGenerator = rateLimitLib.ipKeyGenerator || ((ip) => ip);
const {
  ensurePlatformAdminAccess,
} = require('../supabase_repo');
const {
  normalizePhone,
} = require('./_middleware');

// ── Config ──────────────────────────────────────────────────────────────
const otpiqApiKey = process.env.OTPIQ_API_KEY;
const otpiqBaseUrl = (process.env.OTPIQ_BASE_URL || 'https://api.otpiq.com').replace(/\/$/, '');
const otpiqSmsProvider = process.env.OTPIQ_SMS_PROVIDER || 'sms';
const otpiqWhatsappProvider = process.env.OTPIQ_WHATSAPP_PROVIDER || 'whatsapp-telegram-sms';
const otpiqTelegramProvider = process.env.OTPIQ_TELEGRAM_PROVIDER || 'whatsapp-telegram-sms';
const otpTtlMs = Number.parseInt(process.env.OTP_TTL_MS || '300000', 10);
const parsedOtpLength = Number.parseInt(process.env.OTP_LENGTH || '6', 10);
const otpLength =
  Number.isInteger(parsedOtpLength) && parsedOtpLength >= 4 && parsedOtpLength <= 8
    ? parsedOtpLength
    : 6;
const sessionSecret = String(process.env.SESSION_SECRET || '').trim();

const APPLE_REVIEW_CODE = '123456';

// ── OTP storage ─────────────────────────────────────────────────────────
const pendingOtps = new Map();

// ── Helpers ─────────────────────────────────────────────────────────────

function normalizePhoneForDisplay(phone) {
  const normalized = normalizePhone(phone);
  return normalized ? `+${normalized}` : '';
}

function isAppleReviewPhone(phone) {
  const digits = String(phone || '').replace(/\D/g, '');
  if (!digits) return false;
  if (
    digits === '000000000' ||
    digits === '07000000000' ||
    digits === '96400000000' ||
    digits === '9647000000000' ||
    digits === '7000000000'
  ) {
    return true;
  }
  return digits.endsWith('000000000') && digits.replace(/0/g, '').length <= 2;
}

function generateOtp() {
  const upperBound = 10 ** otpLength;
  const lowerBound = 10 ** (otpLength - 1);
  return String(crypto.randomInt(lowerBound, upperBound));
}

function cleanupExpiredOtps() {
  const now = Date.now();
  for (const [phone, entry] of pendingOtps.entries()) {
    if (entry.expiresAt <= now) {
      pendingOtps.delete(phone);
    }
  }
}

async function sendOtpViaOtpiq(phoneNumber, verificationCode, channel = 'sms') {
  if (!otpiqApiKey) {
    throw new Error('OTPIQ_API_KEY is not configured.');
  }

  const normalizedChannel = String(channel || '').trim().toLowerCase();
  const provider = normalizedChannel === 'whatsapp'
    ? otpiqWhatsappProvider
    : normalizedChannel === 'telegram'
      ? otpiqTelegramProvider
      : otpiqSmsProvider;

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

function base64UrlDecode(input) {
  const normalized = String(input || '')
    .replace(/-/g, '+')
    .replace(/_/g, '/')
    .padEnd(Math.ceil(String(input || '').length / 4) * 4, '=');
  return Buffer.from(normalized, 'base64');
}

function base64UrlEncode(input) {
  const buffer = Buffer.isBuffer(input) ? input : Buffer.from(String(input), 'utf8');
  return buffer
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function createSessionToken(phone) {
  if (!sessionSecret) {
    throw new Error('SESSION_SECRET is not configured.');
  }

  const payload = {
    phone: normalizePhone(phone),
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30,
  };
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signature = crypto
    .createHmac('sha256', sessionSecret)
    .update(encodedPayload)
    .digest();
  return `${encodedPayload}.${base64UrlEncode(signature)}`;
}

// ── Rate limiters ───────────────────────────────────────────────────────

const authSendCodeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number.parseInt(process.env.RATE_LIMIT_OTP_SEND_MAX || '5', 10),
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator(req) {
    const phone = normalizePhone(req.body?.phone);
    const ipKey = ipKeyGenerator(req.ip || '');
    return phone ? `send:${phone}:${ipKey}` : ipKey;
  },
  message: { message: 'Too many OTP requests. Try again later.' },
});

const authVerifyCodeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number.parseInt(process.env.RATE_LIMIT_OTP_VERIFY_MAX || '10', 10),
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator(req) {
    const phone = normalizePhone(req.body?.phone);
    const ipKey = ipKeyGenerator(req.ip || '');
    return phone ? `verify:${phone}:${ipKey}` : ipKey;
  },
  message: { message: 'Too many verification attempts. Try again later.' },
});

// ── Routes ──────────────────────────────────────────────────────────────

router.post('/send-code', authSendCodeLimiter, async (req, res) => {
  try {
    cleanupExpiredOtps();

    const phone = normalizePhone(req.body?.phone);
    const channel = String(req.body?.channel || 'sms').trim().toLowerCase();
    if (!phone) {
      return res.status(400).json({ message: 'Phone number is required.' });
    }

    if (isAppleReviewPhone(phone)) {
      return res.json({
        success: true,
        phoneNumber: normalizePhoneForDisplay(phone),
        channel,
        expiresInMs: otpTtlMs,
        message: 'Demo account ready. Use verification code 123456.',
      });
    }

    const verificationCode = generateOtp();
    const smsResult = await sendOtpViaOtpiq(phone, verificationCode, channel);
    pendingOtps.set(phone, {
      code: verificationCode,
      expiresAt: Date.now() + otpTtlMs,
      smsId: smsResult?.smsId || null,
    });

    return res.json({
      success: true,
      phoneNumber: normalizePhoneForDisplay(phone),
      smsId: smsResult?.smsId || null,
      channel,
      expiresInMs: otpTtlMs,
    });
  } catch (error) {
    console.error('send-code error:', error);
    return res.status(500).json({
      success: false,
      message: error?.message || 'Failed to send verification code.',
    });
  }
});

router.post('/verify-code', authVerifyCodeLimiter, async (req, res) => {
  try {
    cleanupExpiredOtps();

    const phone = normalizePhone(req.body?.phone);
    const code = String(req.body?.code || '').trim();

    if (!phone || !code) {
      return res.status(400).json({ message: 'Phone number and code are required.' });
    }

    if (isAppleReviewPhone(phone) && code === APPLE_REVIEW_CODE) {
      await ensurePlatformAdminAccess(phone);
      const token = createSessionToken(phone);
      return res.json({
        success: true,
        token,
        phoneNumber: normalizePhoneForDisplay(phone),
        expiresInSeconds: 60 * 60 * 24 * 30,
      });
    }
    // -----------------------------

    const otpEntry = pendingOtps.get(phone);
    if (!otpEntry) {
      return res.status(400).json({ success: false, message: 'Verification code expired. Please resend it.' });
    }

    if (otpEntry.code !== code) {
      return res.status(400).json({ success: false, message: 'Invalid verification code.' });
    }

    pendingOtps.delete(phone);
    await ensurePlatformAdminAccess(phone);
    const token = createSessionToken(phone);
    return res.json({
      success: true,
      token,
      phoneNumber: normalizePhoneForDisplay(phone),
      expiresInSeconds: 60 * 60 * 24 * 30,
    });
  } catch (error) {
    console.error('verify-code error:', error);
    return res.status(500).json({
      success: false,
      message: error?.message || 'Failed to verify code.',
    });
  }
});

module.exports = router;
