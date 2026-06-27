/**
 * Al-Ghaith Auth Worker - Cloudflare Worker for OTP via OTPIQ
 */

const encoder = new TextEncoder();
const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;

function normalizePublicBase(env, requestUrl) {
  const configured = String(env.R2_PUBLIC_BASE_URL || '').trim().replace(/\/+$/, '');
  if (configured) return configured;
  return new URL(requestUrl).origin;
}

function buildObjectPath(bucket, fileName) {
  return `${bucket}/${fileName}`;
}

function buildPublicImageUrl(publicBase, objectPath, useMediaPrefix) {
  const base = String(publicBase || '').replace(/\/+$/, '');
  const path = String(objectPath || '').replace(/^\/+/, '');
  return useMediaPrefix ? `${base}/media/${path}` : `${base}/${path}`;
}

async function uploadImageToR2(env, objectPath, body, contentType) {
  if (!env.IMAGES_BUCKET) return false;
  await env.IMAGES_BUCKET.put(objectPath, body, {
    httpMetadata: {
      contentType: contentType || 'image/jpeg',
      cacheControl: 'public, max-age=31536000, immutable',
    },
  });
  return true;
}

async function uploadImageToSupabase(env, objectPath, body, contentType) {
  let supabaseUrl = env.SUPABASE_URL;
  if (!supabaseUrl || !env.SUPABASE_SERVICE_ROLE_KEY) return null;
  if (supabaseUrl.endsWith('/rest/v1/')) {
    supabaseUrl = supabaseUrl.replace('/rest/v1/', '');
  } else if (supabaseUrl.endsWith('/rest/v1')) {
    supabaseUrl = supabaseUrl.replace('/rest/v1', '');
  }
  if (supabaseUrl.endsWith('/')) {
    supabaseUrl = supabaseUrl.slice(0, -1);
  }

  const uploadUrl = `${supabaseUrl}/storage/v1/object/${objectPath}`;
  const uploadResponse = await fetch(uploadUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      'Content-Type': contentType || 'image/jpeg',
      'x-upsert': 'true',
      'cache-control': 'public, max-age=31536000, immutable',
    },
    body,
  });

  if (!uploadResponse.ok) {
    const error = await uploadResponse.text();
    throw new Error(`Supabase upload failed (${uploadResponse.status}): ${error}`);
  }

  return `${supabaseUrl}/storage/v1/object/public/${objectPath}`;
}

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
  if (digits === '000000000') return '9647000000000';
  if (digits.startsWith('964')) return digits;
  if (digits.startsWith('0')) return `964${digits.slice(1)}`;
  if (digits.startsWith('7')) return `964${digits}`;
  return digits;
}

const APPLE_REVIEW_CODE = '123456';

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
  const tauriOrigins = /^tauri:\/\/localhost(:\d+)?$/i;
  const tauriV2Origins = /^https:\/\/tauri\.localhost(:\d+)?$/i;
  const localOrigins = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i;

  if (allowedOrigins.length > 0) {
    if (allowedOrigins.includes(requestOrigin)) {
      allowOrigin = requestOrigin;
    } else if (tauriOrigins.test(requestOrigin) || tauriV2Origins.test(requestOrigin) || localOrigins.test(requestOrigin)) {
      allowOrigin = requestOrigin;
    } else {
      allowOrigin = 'null';
    }
  }

  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
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

const DEFAULT_RAILWAY_ORIGIN = 'https://alghaith-app-production.up.railway.app';

const EDGE_CACHEABLE_PATHS = new Set([
  '/db/shopping-stores',
  '/db/restaurant-stores',
  '/db/catalog-products',
  '/db/offer-catalog-products',
  '/db/marketplace-stats',
  '/app/home-categories',
  '/app/update-policy',
  '/app/maintenance',
  '/app/edge-manifest',
  '/health',
]);

const SNAPSHOT_BY_PATH = {
  '/app/home-categories': 'snapshots/v1/home-categories.json',
  '/db/shopping-stores': 'snapshots/v1/shopping-stores.json',
  '/db/restaurant-stores': 'snapshots/v1/restaurant-stores.json',
  '/db/catalog-products': 'snapshots/v1/catalog-products.json',
  '/db/offer-catalog-products': 'snapshots/v1/offer-catalog-products.json',
  '/db/marketplace-stats': 'snapshots/v1/marketplace-stats.json',
};

function getRailwayOrigin(env) {
  return String(env.RAILWAY_API_ORIGIN || DEFAULT_RAILWAY_ORIGIN).trim().replace(/\/+$/, '');
}

function getEdgeCacheTtlSeconds(env, upstreamPath) {
  const configured = Number.parseInt(String(env.EDGE_CACHE_TTL_SECONDS || ''), 10);
  if (Number.isFinite(configured) && configured > 0) return configured;
  if (upstreamPath.startsWith('/app/maintenance')) return 60;
  if (upstreamPath.startsWith('/app/')) return 300;
  if (upstreamPath === '/health') return 30;
  return 120;
}

function matchesDefaultSnapshotQuery(upstreamPath, searchParams) {
  if (!SNAPSHOT_BY_PATH[upstreamPath]) return false;
  if (upstreamPath === '/app/home-categories' || upstreamPath === '/db/offer-catalog-products') {
    return !searchParams.toString();
  }
  if (upstreamPath === '/db/shopping-stores' || upstreamPath === '/db/restaurant-stores') {
    return !String(searchParams.get('subCategoryId') || '').trim();
  }
  if (upstreamPath === '/db/catalog-products') {
    const category = String(searchParams.get('category') || '').trim();
    const subCategoryId = String(searchParams.get('subCategoryId') || '').trim();
    return !category && !subCategoryId;
  }
  if (upstreamPath === '/db/marketplace-stats') {
    return !searchParams.toString();
  }
  return false;
}

function mergeCorsHeaders(responseHeaders, corsHeaders, extra = {}) {
  const headers = new Headers(responseHeaders);
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }
  for (const [key, value] of Object.entries(extra)) {
    headers.set(key, value);
  }
  return headers;
}

async function serveR2Object(env, objectKey, corsHeaders, cacheControl) {
  if (!env.IMAGES_BUCKET) {
    return new Response('Not Found', { status: 404, headers: corsHeaders });
  }
  const object = await env.IMAGES_BUCKET.get(objectKey);
  if (!object) {
    return new Response('Not Found', { status: 404, headers: corsHeaders });
  }
  const headers = mergeCorsHeaders(
    {
      'Content-Type': object.httpMetadata?.contentType || 'application/json; charset=utf-8',
      'Cache-Control': cacheControl || object.httpMetadata?.cacheControl || 'public, max-age=120',
    },
    corsHeaders,
    { 'X-Edge-Source': 'r2-snapshot' }
  );
  return new Response(object.body, { headers });
}

async function tryServeDefaultSnapshot(request, env, corsHeaders, upstreamPath, search) {
  if (request.method !== 'GET') return null;
  const snapshotKey = SNAPSHOT_BY_PATH[upstreamPath];
  if (!snapshotKey) return null;
  const params = new URLSearchParams(search.startsWith('?') ? search.slice(1) : search);
  if (!matchesDefaultSnapshotQuery(upstreamPath, params)) return null;
  return serveR2Object(env, snapshotKey, corsHeaders, 'public, max-age=120, s-maxage=300');
}

async function fetchRailwayUpstream(request, env, upstreamPath, search) {
  const targetUrl = `${getRailwayOrigin(env)}${upstreamPath}${search || ''}`;
  const headers = new Headers();
  const passHeaders = [
    'authorization',
    'content-type',
    'accept',
    'accept-language',
    'x-request-id',
  ];
  for (const name of passHeaders) {
    const value = request.headers.get(name);
    if (value) headers.set(name, value);
  }

  const init = {
    method: request.method,
    headers,
    redirect: 'follow',
  };
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    init.body = request.body;
  }

  return fetch(targetUrl, init);
}

async function handleRailwayProxy(request, env, corsHeaders, upstreamPath, search) {
  const snapshotResponse = await tryServeDefaultSnapshot(
    request,
    env,
    corsHeaders,
    upstreamPath,
    search
  );
  if (snapshotResponse) return snapshotResponse;

  const hasAuth = Boolean(String(request.headers.get('Authorization') || '').trim());
  const cacheable =
    request.method === 'GET' &&
    !hasAuth &&
    EDGE_CACHEABLE_PATHS.has(upstreamPath);

  const cache = caches.default;
  const cacheUrl = new URL(request.url);
  cacheUrl.pathname = `/__edge_cache__${upstreamPath}`;
  cacheUrl.search = search || '';
  const cacheKey = new Request(cacheUrl.toString(), { method: 'GET' });

  if (cacheable) {
    const cached = await cache.match(cacheKey);
    if (cached) {
      return new Response(cached.body, {
        status: cached.status,
        headers: mergeCorsHeaders(cached.headers, corsHeaders, { 'X-Edge-Cache': 'HIT' }),
      });
    }
  }

  const upstream = await fetchRailwayUpstream(request, env, upstreamPath, search);
  const upstreamHeaders = mergeCorsHeaders(upstream.headers, corsHeaders, {
    'X-Edge-Cache': cacheable ? 'MISS' : 'BYPASS',
  });

  if (!cacheable || !upstream.ok) {
    return new Response(upstream.body, {
      status: upstream.status,
      headers: upstreamHeaders,
    });
  }

  const ttl = getEdgeCacheTtlSeconds(env, upstreamPath);
  const body = await upstream.arrayBuffer();
  const responseToCache = new Response(body, {
    status: upstream.status,
    headers: {
      'Content-Type': upstream.headers.get('Content-Type') || 'application/json',
      'Cache-Control': `public, max-age=${ttl}`,
    },
  });
  await cache.put(cacheKey, responseToCache.clone());

  return new Response(body, {
    status: upstream.status,
    headers: mergeCorsHeaders(responseToCache.headers, corsHeaders, { 'X-Edge-Cache': 'MISS' }),
  });
}

async function handleSnapshotRequest(request, env, corsHeaders, url) {
  const key = decodeURIComponent(url.pathname.slice(1));
  if (!key.startsWith('snapshots/') || key.includes('..')) {
    return new Response('Bad Request', { status: 400, headers: corsHeaders });
  }
  return serveR2Object(env, key, corsHeaders);
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
      if (url.pathname.startsWith('/snapshots/') && request.method === 'GET') {
        return handleSnapshotRequest(request, env, corsHeaders, url);
      }

      if (url.pathname === '/railway' || url.pathname.startsWith('/railway/')) {
        const upstreamPath = url.pathname === '/railway'
          ? '/'
          : url.pathname.slice('/railway'.length);
        return handleRailwayProxy(request, env, corsHeaders, upstreamPath, url.search);
      }

      const railwayBackedPrefixes = ['/db/', '/app/', '/maps/', '/voice/'];
      if (
        url.pathname === '/health' ||
        railwayBackedPrefixes.some((prefix) => url.pathname.startsWith(prefix))
      ) {
        return handleRailwayProxy(request, env, corsHeaders, url.pathname, url.search);
      }

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

        if (isAppleReviewPhone(normalizedPhone)) {
          return json(
            {
              success: true,
              message: 'Demo account ready. Use verification code 123456.',
              phoneNumber: `+${normalizedPhone}`,
              channel: mapProvider(channel),
            },
            200,
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

        if (isAppleReviewPhone(normalizedPhone) && code === APPLE_REVIEW_CODE) {
          if (!env.SESSION_SECRET) {
            return json({ success: false, message: 'SESSION_SECRET is not configured.' }, 500, corsHeaders);
          }
          const token = await createSessionToken(normalizedPhone, env.SESSION_SECRET);
          return json({
            success: true,
            token,
            phoneNumber: `+${normalizedPhone}`,
            expiresInSeconds: 60 * 60 * 24 * 30,
          }, 200, corsHeaders);
        }
        // -----------------------------

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

      if (url.pathname.startsWith('/media/') && request.method === 'GET') {
        if (!env.IMAGES_BUCKET) {
          return new Response('Not Found', { status: 404, headers: corsHeaders });
        }

        const key = decodeURIComponent(url.pathname.slice('/media/'.length));
        if (!key || key.includes('..')) {
          return new Response('Bad Request', { status: 400, headers: corsHeaders });
        }

        const object = await env.IMAGES_BUCKET.get(key);
        if (!object) {
          return new Response('Not Found', { status: 404, headers: corsHeaders });
        }

        const headers = new Headers(corsHeaders);
        headers.set(
          'Content-Type',
          object.httpMetadata?.contentType || 'application/octet-stream'
        );
        headers.set(
          'Cache-Control',
          object.httpMetadata?.cacheControl || 'public, max-age=31536000, immutable'
        );
        return new Response(object.body, { headers });
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

        const safeName = String(file.name || 'image.jpg')
          .replace(/[^a-zA-Z0-9._-]/g, '_');
        const fileName = `${Date.now()}_${safeName}`;
        const objectPath = buildObjectPath(bucket, fileName);
        const fileContentType = file.type || 'image/jpeg';
        const fileBody = await file.arrayBuffer();
        const hasCustomPublicBase = Boolean(String(env.R2_PUBLIC_BASE_URL || '').trim());

        if (env.IMAGES_BUCKET) {
          try {
            const uploaded = await uploadImageToR2(
              env,
              objectPath,
              fileBody,
              fileContentType
            );
            if (uploaded) {
              const publicBase = normalizePublicBase(env, request.url);
              const publicUrl = buildPublicImageUrl(
                publicBase,
                objectPath,
                !hasCustomPublicBase
              );
              return json(
                {
                  success: true,
                  url: publicUrl,
                  bucket,
                  path: fileName,
                  storage: 'r2',
                },
                200,
                corsHeaders
              );
            }
          } catch (error) {
            console.error('R2 upload failed, falling back to Supabase:', error);
          }
        }

        try {
          const publicUrl = await uploadImageToSupabase(
            env,
            objectPath,
            fileBody,
            fileContentType
          );
          if (!publicUrl) {
            return json(
              { success: false, message: 'Image storage is not configured.' },
              500,
              corsHeaders
            );
          }
          return json(
            {
              success: true,
              url: publicUrl,
              bucket,
              path: fileName,
              storage: 'supabase',
            },
            200,
            corsHeaders
          );
        } catch (error) {
          return json(
            {
              success: false,
              message: 'Upload failed',
              error: error?.message || String(error),
            },
            500,
            corsHeaders
          );
        }
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
