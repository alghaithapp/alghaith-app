/**
 * Al-Ghaith Auth Worker - Cloudflare Worker for OTP via OTPIQ
 */

const encoder = new TextEncoder();
const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;

function json(data, status, corsHeaders) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function normalizePhone(phone) {
  const raw = String(phone || '').trim().replace(/[\s-]/g, '');
  const digits = raw.replace(/\D/g, '');
  if (!digits) return '';
  if (digits.startsWith('964')) return digits;
  if (digits.startsWith('0')) return `964${digits.slice(1)}`;
  if (digits.startsWith('7')) return `964${digits}`;
  return digits;
}

function mapProvider(channel) {
  const normalized = String(channel || '').trim().toLowerCase();
  if (normalized === 'sms') return 'sms';
  if (normalized === 'telegram') return 'telegram';
  if (normalized === 'whatsapp') return 'whatsapp';
  return 'whatsapp-telegram-sms';
}

function base64UrlEncode(input) {
  const bytes = typeof input === 'string' ? encoder.encode(input) : input;
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

async function signHmac(secret, message) {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  return new Uint8Array(
    await crypto.subtle.sign('HMAC', key, encoder.encode(message))
  );
}

async function createSessionToken(phone, secret) {
  const payload = {
    phone,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30,
  };
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signature = await signHmac(secret, encodedPayload);
  return `${encodedPayload}.${base64UrlEncode(signature)}`;
}

function base64UrlDecodeToBytes(input) {
  const normalized = String(input || '')
    .replace(/-/g, '+')
    .replace(/_/g, '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

async function verifySessionToken(token, secret) {
  const [encodedPayload, encodedSignature] = String(token || '').split('.');
  if (!encodedPayload || !encodedSignature || !secret) {
    throw new Error('Invalid authorization token.');
  }

  const expectedSignature = await signHmac(secret, encodedPayload);
  const actualSignature = base64UrlDecodeToBytes(encodedSignature);
  if (actualSignature.length !== expectedSignature.length) {
    throw new Error('Invalid token signature.');
  }
  let signatureMatch = true;
  for (let i = 0; i < actualSignature.length; i += 1) {
    if (actualSignature[i] !== expectedSignature[i]) {
      signatureMatch = false;
    }
  }
  if (!signatureMatch) {
    throw new Error('Invalid token signature.');
  }

  const payloadText = new TextDecoder().decode(base64UrlDecodeToBytes(encodedPayload));
  let payload = null;
  try {
    payload = JSON.parse(payloadText);
  } catch (_) {
    throw new Error('Invalid token payload.');
  }

  const phone = normalizePhone(payload?.phone);
  const exp = Number(payload?.exp || 0);
  const now = Math.floor(Date.now() / 1000);
  if (!phone || !exp || exp <= now) {
    throw new Error('Token expired or invalid.');
  }

  return { phone, exp };
}

function buildCorsHeaders(request, env) {
  const allowedOrigins = String(env.CORS_ALLOWED_ORIGINS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  const requestOrigin = request.headers.get('Origin') || '';
  let allowOrigin = '*';

  if (allowedOrigins.length > 0) {
    allowOrigin = allowedOrigins.includes(requestOrigin) ? requestOrigin : 'null';
  }

  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}

async function checkRateLimit(env, key, limit, windowSeconds) {
  if (!env.AUTH_KV || !key) return true;
  const bucket = Math.floor(Date.now() / (windowSeconds * 1000));
  const kvKey = `rl:${key}:${bucket}`;
  const current = Number(await env.AUTH_KV.get(kvKey) || '0');
  if (current >= limit) return false;
  await env.AUTH_KV.put(kvKey, String(current + 1), { expirationTtl: windowSeconds });
  return true;
}

function readBearerToken(request) {
  const authorization = String(request.headers.get('Authorization') || '').trim();
  if (!authorization.startsWith('Bearer ')) {
    return '';
  }
  return authorization.slice('Bearer '.length).trim();
}

async function parseJsonSafely(response) {
  const text = await response.text();
  try {
    return text ? JSON.parse(text) : null;
  } catch (_) {
    return text || null;
  }
}

export default {
  async fetch(request, env) {
    const corsHeaders = buildCorsHeaders(request, env);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const clientIp = request.headers.get('CF-Connecting-IP') || 'unknown';

    try {
      if (url.pathname === '/auth/send-code' && request.method === 'POST') {
        const { phone, channel } = await request.json();
        const normalizedPhone = normalizePhone(phone);

        if (!normalizedPhone) {
          return json({ success: false, message: 'Phone number is required.' }, 400, corsHeaders);
        }

        const allowedByPhone = await checkRateLimit(
          env,
          `send-code:phone:${normalizedPhone}`,
          3,
          15 * 60
        );
        const allowedByIp = await checkRateLimit(
          env,
          `send-code:ip:${clientIp}`,
          10,
          15 * 60
        );
        if (!allowedByPhone || !allowedByIp) {
          return json(
            { success: false, message: 'Too many OTP requests. Try again later.' },
            429,
            corsHeaders
          );
        }

        if (!env.OTPIQ_API_KEY) {
          return json(
            { success: false, message: 'OTPIQ_API_KEY is not configured.' },
            500,
            corsHeaders
          );
        }

        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();

        if (env.AUTH_KV) {
          await env.AUTH_KV.put(normalizedPhone, otpCode, {
            expirationTtl: 300,
          });
        }

        const provider = mapProvider(channel);
        const otpiqResponse = await fetch('https://api.otpiq.com/api/sms', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.OTPIQ_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            phoneNumber: normalizedPhone,
            smsType: 'verification',
            verificationCode: otpCode,
            provider,
          }),
        });

        const otpiqPayload = await parseJsonSafely(otpiqResponse);

        if (!otpiqResponse.ok) {
          const message =
            otpiqPayload?.message ||
            otpiqPayload?.error ||
            `OTPIQ request failed with status ${otpiqResponse.status}`;

          return json(
            {
              success: false,
              message,
              otpiqStatus: otpiqResponse.status,
              otpiqPayload,
            },
            otpiqResponse.status,
            corsHeaders
          );
        }

        return json(
          {
            success: true,
            message: otpiqPayload?.message || 'OTP Sent',
            smsId: otpiqPayload?.smsId || null,
            phoneNumber: normalizedPhone,
            provider,
          },
          200,
          corsHeaders
        );
      }

      if (url.pathname === '/auth/verify-code' && request.method === 'POST') {
        const { phone, code } = await request.json();
        const normalizedPhone = normalizePhone(phone);

        if (!normalizedPhone || !code) {
          return json(
            {
              success: false,
              message: 'Phone number and code are required.',
            },
            400,
            corsHeaders
          );
        }

        const allowedByPhone = await checkRateLimit(
          env,
          `verify-code:phone:${normalizedPhone}`,
          8,
          15 * 60
        );
        const allowedByIp = await checkRateLimit(
          env,
          `verify-code:ip:${clientIp}`,
          20,
          15 * 60
        );
        if (!allowedByPhone || !allowedByIp) {
          return json(
            { success: false, message: 'Too many verification attempts. Try again later.' },
            429,
            corsHeaders
          );
        }

        const storedCode = env.AUTH_KV
          ? await env.AUTH_KV.get(normalizedPhone)
          : null;

        if (!storedCode) {
          return json(
            {
              success: false,
              message: 'Verification code expired. Please resend it.',
            },
            401,
            corsHeaders
          );
        }

        if (code !== storedCode) {
          return json({ success: false, message: 'Invalid Code' }, 401, corsHeaders);
        }

        if (env.AUTH_KV) {
          await env.AUTH_KV.delete(normalizedPhone);
        }

        if (!env.SESSION_SECRET) {
          return json(
            { success: false, message: 'SESSION_SECRET is not configured.' },
            500,
            corsHeaders
          );
        }

        const token = await createSessionToken(normalizedPhone, env.SESSION_SECRET);

        return json(
          {
            success: true,
            token,
            phoneNumber: normalizedPhone.startsWith('+')
              ? normalizedPhone
              : `+${normalizedPhone}`,
            expiresInSeconds: 60 * 60 * 24 * 30,
          },
          200,
          corsHeaders
        );
      }

      if (url.pathname === '/upload' && request.method === 'POST') {
        if (!env.SESSION_SECRET) {
          return json(
            { success: false, message: 'SESSION_SECRET is not configured.' },
            500,
            corsHeaders
          );
        }

        const token = readBearerToken(request);
        if (!token) {
          return json(
            { success: false, message: 'Missing authorization token.' },
            401,
            corsHeaders
          );
        }

        try {
          await verifySessionToken(token, env.SESSION_SECRET);
        } catch (error) {
          return json(
            {
              success: false,
              message: error?.message || 'Invalid authorization token.',
            },
            401,
            corsHeaders
          );
        }

        const requestContentType = request.headers.get('content-type') || '';
        if (!requestContentType.includes('multipart/form-data')) {
          return json({ success: false, message: 'Invalid content type' }, 400, corsHeaders);
        }

        const formData = await request.formData();
        const file = formData.get('file');
        const bucket = String(formData.get('bucket') || 'uploads').trim();

        if (bucket !== 'uploads') {
          return json({ success: false, message: 'Invalid bucket.' }, 400, corsHeaders);
        }

        if (!file || !(file instanceof File)) {
          return json({ success: false, message: 'No file provided' }, 400, corsHeaders);
        }

        if (file.size > MAX_UPLOAD_BYTES) {
          return json({ success: false, message: 'File is too large.' }, 413, corsHeaders);
        }

        let supabaseUrl = env.SUPABASE_URL;
        if (supabaseUrl.endsWith('/rest/v1/')) {
          supabaseUrl = supabaseUrl.replace('/rest/v1/', '');
        } else if (supabaseUrl.endsWith('/rest/v1')) {
          supabaseUrl = supabaseUrl.replace('/rest/v1', '');
        }
        if (supabaseUrl.endsWith('/')) {
          supabaseUrl = supabaseUrl.slice(0, -1);
        }

        const supabaseKey = env.SUPABASE_SERVICE_ROLE_KEY;

        if (!supabaseUrl || !supabaseKey) {
          return json(
            { success: false, message: 'Supabase not configured in Worker' },
            500,
            corsHeaders
          );
        }

        const safeName = String(file.name || 'image.jpg')
          .replace(/[^a-zA-Z0-9._-]/g, '_');
        const fileName = `${Date.now()}_${safeName}`;
        const objectPath = `${bucket}/${fileName}`;
        const uploadUrl = `${supabaseUrl}/storage/v1/object/${objectPath}`;
        const fileContentType = file.type || 'image/jpeg';

        const uploadResponse = await fetch(uploadUrl, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${supabaseKey}`,
            apikey: supabaseKey,
            'Content-Type': fileContentType,
            'x-upsert': 'true',
            'cache-control': '3600',
          },
          body: await file.arrayBuffer(),
        });

        if (!uploadResponse.ok) {
          const error = await uploadResponse.text();
          return json(
            { success: false, message: 'Upload failed', error },
            uploadResponse.status,
            corsHeaders
          );
        }

        const publicUrl = `${supabaseUrl}/storage/v1/object/public/${objectPath}`;
        return json(
          { success: true, url: publicUrl, bucket, path: fileName },
          200,
          corsHeaders
        );
      }

      return new Response('Al-Ghaith API Active', {
        status: 200,
        headers: corsHeaders,
      });
    } catch (error) {
      return json(
        {
          success: false,
          message: error?.message || 'Unexpected worker error.',
        },
        500,
        corsHeaders
      );
    }
  },
};
