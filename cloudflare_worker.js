/**
 * Al-Ghaith Auth Worker - Cloudflare Worker for OTP via OTPIQ
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

const encoder = new TextEncoder();

function json(data, status = 200) {
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
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    try {
      if (url.pathname === '/auth/send-code' && request.method === 'POST') {
        const { phone, channel } = await request.json();
        const normalizedPhone = normalizePhone(phone);

        if (!normalizedPhone) {
          return json({ success: false, message: 'Phone number is required.' }, 400);
        }

        if (!env.OTPIQ_API_KEY) {
          return json(
            { success: false, message: 'OTPIQ_API_KEY is not configured.' },
            500
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
            otpiqResponse.status
          );
        }

        return json({
          success: true,
          message: otpiqPayload?.message || 'OTP Sent',
          smsId: otpiqPayload?.smsId || null,
          phoneNumber: normalizedPhone,
          provider,
        });
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
            400
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
            401
          );
        }

        if (code !== storedCode) {
          return json({ success: false, message: 'Invalid Code' }, 401);
        }

        if (env.AUTH_KV) {
          await env.AUTH_KV.delete(normalizedPhone);
        }

        if (!env.SESSION_SECRET) {
          return json(
            { success: false, message: 'SESSION_SECRET is not configured.' },
            500
          );
        }

        const token = await createSessionToken(normalizedPhone, env.SESSION_SECRET);

        return json({
          success: true,
          token,
          phoneNumber: normalizedPhone.startsWith('+')
            ? normalizedPhone
            : `+${normalizedPhone}`,
          expiresInSeconds: 60 * 60 * 24 * 30,
        });
      }

      // --- Image Upload Endpoint ---
      if (url.pathname === '/upload' && request.method === 'POST') {
        const requestContentType = request.headers.get('content-type') || '';
        if (!requestContentType.includes('multipart/form-data')) {
          return json({ success: false, message: 'Invalid content type' }, 400);
        }

        const formData = await request.formData();
        const file = formData.get('file');
        const bucket = formData.get('bucket') || 'uploads';

        if (!file || !(file instanceof File)) {
          return json({ success: false, message: 'No file provided' }, 400);
        }

        // تنظيف الرابط لضمان عمله مع الاستورج
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
          return json({ success: false, message: 'Supabase not configured in Worker' }, 500);
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
            uploadResponse.status
          );
        }

        const publicUrl = `${supabaseUrl}/storage/v1/object/public/${objectPath}`;
        return json({ success: true, url: publicUrl, bucket, path: fileName });
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
        500
      );
    }
  },
};
