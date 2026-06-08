require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const crypto = require('crypto');
const cors = require('cors');
const express = require('express');
const helmet = require('helmet');
const rateLimitLib = require('express-rate-limit');
const rateLimit = rateLimitLib.default || rateLimitLib;
const ipKeyGenerator = rateLimitLib.ipKeyGenerator || ((ip) => ip);
const {
  isConfigured: isSupabaseConfigured,
  supabaseKeyRole,
  isLikelyAnonKey,
  isLikelyServiceRoleKey,
  getAppUser,
  saveAppUser,
  deleteAppUser,
  getCustomerProfile,
  saveCustomerProfile,
  deleteCustomerProfile,
  getCustomerAddresses,
  saveCustomerAddress,
  deleteCustomerAddress,
  getCustomerFavorites,
  saveCustomerFavorite,
  getCustomerOrders,
  saveCustomerOrder,
  getMerchantProfile,
  saveMerchantProfile,
  deleteMerchantProfile,
  getUserState,
  saveUserState,
  deleteUserState,
  getMerchantProducts,
  saveMerchantProduct,
  deleteMerchantProduct,
  listProfessionalProfiles,
  listShoppingStores,
  listRestaurantStores,
  listServiceStores,
  listCatalogProducts,
  listOfferCatalogProducts,
  getMarketplaceStats,
  listRealEstateListings,
  getMerchantIncomingOrders,
  updateIncomingOrderStatus,
  getDeliveryPoolOrders,
  getCourierAssignedOrders,
  acceptDeliveryOrder,
  rejectDeliveryOrder,
  updateCourierDeliveryStatus,
  getAdminReports,
  saveMerchantReview,
  getAllMerchants,
  getAdminMerchantDetails,
  toggleBazaarMemberStatus,
  toggleMerchantFreezeStatus,
} = require('./supabase_repo');
const { validatePromoCode } = require('./promo_codes');

const app = express();
const port = process.env.PORT || 3000;
// Railway/most managed platforms sit behind a reverse proxy.
app.set('trust proxy', 1);

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
const mapboxAccessToken = String(process.env.MAPBOX_ACCESS_TOKEN || '').trim();
const mapboxPublicToken = String(process.env.MAPBOX_PUBLIC_TOKEN || '').trim();

function resolvePublicMapboxToken() {
  if (mapboxPublicToken.startsWith('pk.')) return mapboxPublicToken;
  if (mapboxAccessToken.startsWith('pk.')) return mapboxAccessToken;
  return '';
}
const corsAllowedOrigins = String(process.env.CORS_ALLOWED_ORIGINS || '')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

if (!otpiqApiKey) {
  console.warn(
    'Missing OTPIQ_API_KEY. Add it to backend/.env before sending OTPs.'
  );
}

if (!sessionSecret) {
  console.warn(
    'Missing SESSION_SECRET. Private database routes and signed login sessions will not work until you add it to backend/.env.'
  );
}

if (!mapboxAccessToken) {
  console.warn(
    'Missing MAPBOX_ACCESS_TOKEN. Road-distance route API will use fallback behavior in the app.'
  );
}

if (!isSupabaseConfigured) {
  console.warn(
    'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. Database routes will not work until you add them to backend/.env.'
  );
} else if (isLikelyAnonKey || !isLikelyServiceRoleKey) {
  console.warn(
    `SUPABASE_SERVICE_ROLE_KEY does not look like a service_role key. Current role: ${supabaseKeyRole || 'unknown'}. Replace it with the real service_role key from Supabase Dashboard -> Project Settings -> API.`
  );
}

function normalizePhone(phone) {
  const raw = String(phone || '').trim().replace(/[\s-]/g, '');
  if (!raw) return '';

  const digits = raw.replace(/\D/g, '');
  if (digits === '000000000') {
    return '9647000000000';
  }
  if (digits.startsWith('0')) {
    return `964${digits.slice(1)}`;
  }
  if (digits.startsWith('964')) {
    return digits;
  }
  return `964${digits}`;
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

app.use(helmet());
app.use(
  cors({
    origin(origin, callback) {
      // Mobile/native clients often send no Origin header.
      if (!origin) {
        callback(null, true);
        return;
      }
      if (corsAllowedOrigins.length === 0 || corsAllowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error('Not allowed by CORS'));
    },
  })
);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

const generalRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: Number.parseInt(process.env.RATE_LIMIT_GENERAL_MAX || '120', 10),
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many requests. Try again later.' },
});

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

app.use(generalRateLimiter);

const pendingOtps = new Map();

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

function verifySessionToken(token) {
  if (!sessionSecret) {
    throw new Error('SESSION_SECRET is not configured.');
  }

  const [encodedPayload, encodedSignature] = String(token || '').split('.');
  if (!encodedPayload || !encodedSignature) {
    throw new Error('Missing token payload or signature.');
  }

  const expectedSignature = crypto
    .createHmac('sha256', sessionSecret)
    .update(encodedPayload)
    .digest();
  const actualSignature = base64UrlDecode(encodedSignature);

  if (
    actualSignature.length !== expectedSignature.length ||
    !crypto.timingSafeEqual(actualSignature, expectedSignature)
  ) {
    throw new Error('Invalid token signature.');
  }

  const payloadText = base64UrlDecode(encodedPayload).toString('utf8');
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

function normalizePhoneForDisplay(phone) {
  const normalized = normalizePhone(phone);
  return normalized ? `+${normalized}` : '';
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

app.get('/health', (_, res) => {
  res.json({ ok: true, version: '1.1.10' });
});

app.get('/maps/public-token', (_, res) => {
  const token = resolvePublicMapboxToken();
  if (!token) {
    return res.status(503).json({
      message: 'MAPBOX_PUBLIC_TOKEN is not configured on backend.',
    });
  }
  return res.json({ publicToken: token });
});

async function geocodeAddressWithMapbox(addressText) {
  const address = String(addressText || '').trim();
  const query = encodeURIComponent(address);
  const params = new URLSearchParams({
    language: 'ar',
    country: 'iq',
    limit: '1',
    access_token: mapboxAccessToken,
  });
  const response = await fetch(
    `https://api.mapbox.com/geocoding/v5/mapbox.places/${query}.json?${params.toString()}`
  );
  if (!response.ok) {
    throw new Error(`Mapbox geocoding failed with status ${response.status}`);
  }
  const payload = await response.json();
  const feature = Array.isArray(payload?.features) ? payload.features[0] : null;
  const center = Array.isArray(feature?.center) ? feature.center : null;
  if (!center || center.length < 2) {
    throw new Error('Could not geocode one of the addresses.');
  }
  const longitude = Number(center[0]);
  const latitude = Number(center[1]);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new Error('Invalid coordinates from geocoding result.');
  }
  return { latitude, longitude };
}

async function computeRoadDistanceMeters(origin, destination) {
  const coordinates =
    `${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}`;
  const params = new URLSearchParams({
    alternatives: 'false',
    overview: 'false',
    language: 'ar',
    access_token: mapboxAccessToken,
  });
  const response = await fetch(
    `https://api.mapbox.com/directions/v5/mapbox/driving/${coordinates}?${params.toString()}`
  );

  if (!response.ok) {
    const bodyText = await response.text();
    throw new Error(bodyText || `Mapbox directions failed with status ${response.status}`);
  }

  const payload = await response.json();
  const route = Array.isArray(payload?.routes) ? payload.routes[0] : null;
  if (!route || typeof route.distance !== 'number') {
    throw new Error('No routes available between the selected points.');
  }
  return {
    distanceMeters: route.distance,
    duration: String(route.duration || ''),
  };
}

app.post('/maps/route-distance', async (req, res) => {
  try {
    if (!mapboxAccessToken) {
      return res.status(503).json({
        message: 'MAPBOX_ACCESS_TOKEN is not configured on backend.',
      });
    }

    const pickupAddress = String(req.body?.pickupAddress || '').trim();
    const dropoffAddress = String(req.body?.dropoffAddress || '').trim();
    const pickupLatitude = Number(req.body?.pickupLatitude);
    const pickupLongitude = Number(req.body?.pickupLongitude);
    const dropoffLatitude = Number(req.body?.dropoffLatitude);
    const dropoffLongitude = Number(req.body?.dropoffLongitude);

    const hasPickupCoords =
      Number.isFinite(pickupLatitude) && Number.isFinite(pickupLongitude);
    const hasDropoffCoords =
      Number.isFinite(dropoffLatitude) && Number.isFinite(dropoffLongitude);

    const origin = hasPickupCoords
      ? { latitude: pickupLatitude, longitude: pickupLongitude }
      : pickupAddress
        ? await geocodeAddressWithMapbox(pickupAddress)
        : null;
    const destination = hasDropoffCoords
      ? { latitude: dropoffLatitude, longitude: dropoffLongitude }
      : dropoffAddress
        ? await geocodeAddressWithMapbox(dropoffAddress)
        : null;

    if (!origin || !destination) {
      return res.status(400).json({
        message:
          'Provide pickup/dropoff coordinates or valid addresses for both points.',
      });
    }

    const route = await computeRoadDistanceMeters(origin, destination);
    return res.json({
      distanceMeters: route.distanceMeters,
      distanceKm: route.distanceMeters / 1000,
      duration: route.duration,
    });
  } catch (error) {
    console.error('route-distance error:', error);
    return res.status(500).json({
      message: error?.message || 'Failed to compute route distance.',
    });
  }
});

app.post('/auth/send-code', authSendCodeLimiter, async (req, res) => {
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

app.post('/auth/verify-code', authVerifyCodeLimiter, async (req, res) => {
  try {
    cleanupExpiredOtps();

    const phone = normalizePhone(req.body?.phone);
    const code = String(req.body?.code || '').trim();

    if (!phone || !code) {
      return res.status(400).json({ message: 'Phone number and code are required.' });
    }

    if (isAppleReviewPhone(phone) && code === APPLE_REVIEW_CODE) {
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

function parseQueryValue(value) {
  if (Array.isArray(value)) return value[0];
  return value;
}

function readRequestedPhone(req) {
  if (req.method === 'GET' || req.method === 'DELETE') {
    return String(parseQueryValue(req.query.phone) || '').trim();
  }
  return String(req.body?.phone || '').trim();
}

function requireAuthorizedPhone(req, res, { allowMissing = false } = {}) {
  const requestedPhone = normalizePhone(readRequestedPhone(req));
  if (!requestedPhone) {
    if (allowMissing) {
      return req.authPhone;
    }
    res.status(400).json({ message: 'Phone number is required.' });
    return null;
  }

  if (requestedPhone !== req.authPhone) {
    res.status(403).json({ message: 'You are not allowed to access this phone number.' });
    return null;
  }

  return requestedPhone;
}

app.use('/db', (req, res, next) => {
  const publicPaths = new Set([
    '/professionals',
    '/shopping-stores',
    '/restaurant-stores',
    '/service-stores',
    '/catalog',
    '/offers-catalog',
    '/marketplace-stats',
    '/validate-promo',
    '/real-estate-listings',
  ]);

  if (publicPaths.has(req.path)) {
    return next();
  }

  const authorization = String(req.headers.authorization || '').trim();
  if (!authorization.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Missing authorization token.' });
  }

  try {
    const token = authorization.slice('Bearer '.length).trim();
    const session = verifySessionToken(token);
    req.authPhone = session.phone;
    req.authSessionExpiresAt = session.exp;
    return next();
  } catch (error) {
    return res.status(401).json({
      message: error?.message || 'Invalid authorization token.',
    });
  }
});

app.get('/db/app-user', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await getAppUser(phone);
    return res.json(row);
  } catch (error) {
    console.error('get app-user error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load app user.' });
  }
});

app.put('/db/app-user', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveAppUser(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save app-user error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save app user.' });
  }
});

app.delete('/db/app-user', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    await deleteAppUser(phone);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete app-user error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete app user.' });
  }
});

app.get('/db/customer-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await getCustomerProfile(phone);
    return res.json(row);
  } catch (error) {
    console.error('get customer-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load customer profile.' });
  }
});

app.put('/db/customer-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveCustomerProfile(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save customer-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save customer profile.' });
  }
});

app.delete('/db/customer-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    await deleteCustomerProfile(phone);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete customer-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete customer profile.' });
  }
});

app.get('/db/customer-addresses', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getCustomerAddresses(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get customer-addresses error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load customer addresses.' });
  }
});

app.put('/db/customer-address', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveCustomerAddress(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save customer-address error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save customer address.' });
  }
});

app.delete('/db/customer-address', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    const address = String(parseQueryValue(req.query.address) || '').trim();
    if (!phone) return;
    if (!address) {
      return res.status(400).json({ message: 'Address is required.' });
    }
    await deleteCustomerAddress(phone, address);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete customer-address error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete customer address.' });
  }
});

app.get('/db/customer-favorites', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getCustomerFavorites(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get customer-favorites error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load customer favorites.' });
  }
});

app.put('/db/customer-favorite', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveCustomerFavorite(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save customer-favorite error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save customer favorite.' });
  }
});

app.get('/db/customer-orders', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getCustomerOrders(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get customer-orders error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load customer orders.' });
  }
});

app.put('/db/customer-order', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveCustomerOrder(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save customer-order error:', error);
    const message = error?.message || 'Failed to save customer order.';
    const status = message === 'MERCHANT_FROZEN' ? 409 : 500;
    return res.status(status).json({ message });
  }
});

app.get('/db/merchant-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await getMerchantProfile(phone);
    return res.json(row);
  } catch (error) {
    console.error('get merchant-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load merchant profile.' });
  }
});

app.put('/db/merchant-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveMerchantProfile(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save merchant-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save merchant profile.' });
  }
});

app.delete('/db/merchant-profile', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    await deleteMerchantProfile(phone);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete merchant-profile error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete merchant profile.' });
  }
});

app.get('/db/user-state', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const state = await getUserState(phone);
    return res.json(state);
  } catch (error) {
    console.error('get user-state error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load user state.' });
  }
});

app.put('/db/user-state', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveUserState(phone, req.body?.state || {});
    return res.json(row);
  } catch (error) {
    console.error('save user-state error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save user state.' });
  }
});

app.delete('/db/user-state', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    await deleteUserState(phone);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete user-state error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete user state.' });
  }
});

app.get('/db/merchant-products', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const rows = await getMerchantProducts(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get merchant-products error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load merchant products.' });
  }
});

app.put('/db/merchant-product', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    if (!phone) return;
    const row = await saveMerchantProduct(phone, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('save merchant-product error:', error);
    const message = error?.message || 'Failed to save merchant product.';
    const status = message === 'BAZAAR_APPROVAL_REQUIRED' ? 409 : 500;
    return res.status(status).json({ message });
  }
});

app.delete('/db/merchant-product', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res);
    const id = String(parseQueryValue(req.query.id) || '').trim();
    if (!phone) return;
    if (!id) {
      return res.status(400).json({ message: 'Product id is required.' });
    }
    await deleteMerchantProduct(id, phone);
    return res.json({ success: true });
  } catch (error) {
    console.error('delete merchant-product error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to delete merchant product.' });
  }
});

app.get('/db/professionals', async (req, res) => {
  try {
    const professionId = String(parseQueryValue(req.query.professionId) || '').trim();
    const rows = await listProfessionalProfiles(professionId);
    return res.json(rows);
  } catch (error) {
    console.error('list professionals error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load professionals.' });
  }
});

app.get('/db/shopping-stores', async (req, res) => {
  try {
    const subCategoryId = String(parseQueryValue(req.query.subCategoryId) || '').trim();
    const rows = await listShoppingStores(subCategoryId);
    return res.json(rows);
  } catch (error) {
    console.error('list shopping-stores error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load shopping stores.' });
  }
});

app.get('/db/restaurant-stores', async (req, res) => {
  try {
    const subCategoryId = String(parseQueryValue(req.query.subCategoryId) || '').trim();
    const rows = await listRestaurantStores(subCategoryId);
    return res.json(rows);
  } catch (error) {
    console.error('list restaurant-stores error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load restaurant stores.' });
  }
});

app.get('/db/catalog', async (req, res) => {
  try {
    const category = String(parseQueryValue(req.query.category) || '').trim();
    const subCategoryId = String(parseQueryValue(req.query.subCategoryId) || '').trim();
    const rows = await listCatalogProducts(category, subCategoryId);
    return res.json(rows);
  } catch (error) {
    console.error('list catalog error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load catalog.' });
  }
});

app.get('/db/service-stores', async (req, res) => {
  try {
    const serviceId = String(parseQueryValue(req.query.serviceId) || '').trim();
    const productCategory = String(parseQueryValue(req.query.productCategory) || serviceId).trim();
    const subCategoryId = String(parseQueryValue(req.query.subCategoryId) || '').trim();
    const marketplaceCategory = String(
      parseQueryValue(req.query.marketplaceCategory) || ''
    ).trim();
    if (!serviceId) {
      return res.status(400).json({ message: 'serviceId is required.' });
    }
    const rows = await listServiceStores(
      serviceId,
      productCategory,
      subCategoryId,
      marketplaceCategory
    );
    return res.json(rows);
  } catch (error) {
    console.error('list service-stores error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load service stores.' });
  }
});

app.get('/db/offers-catalog', async (req, res) => {
  try {
    const rows = await listOfferCatalogProducts();
    return res.json(rows);
  } catch (error) {
    console.error('list offers-catalog error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load offers catalog.' });
  }
});

app.get('/db/marketplace-stats', async (req, res) => {
  try {
    const rows = await getMarketplaceStats();
    return res.json(rows);
  } catch (error) {
    console.error('marketplace-stats error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load marketplace stats.' });
  }
});

app.post('/db/validate-promo', async (req, res) => {
  try {
    const code = String(req.body?.code || req.body?.promoCode || '').trim();
    const subtotalIqd = Number(req.body?.subtotalIqd ?? req.body?.subtotal ?? 0);
    const result = validatePromoCode(code, subtotalIqd);
    return res.json(result);
  } catch (error) {
    console.error('validate-promo error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to validate promo code.' });
  }
});

app.post('/db/merchant-review', async (req, res) => {
  try {
    const { merchantPhone, customerPhone, customerName, orderId, stars, comment } = req.body;
    if (!merchantPhone || !customerPhone || !orderId || !stars) {
      return res.status(400).json({ message: 'Missing required review fields.' });
    }
    const result = await saveMerchantReview({
      merchantPhone,
      customerPhone,
      customerName,
      orderId,
      stars,
      comment
    });
    return res.json(result);
  } catch (error) {
    console.error('merchant-review error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to save review.' });
  }
});

app.get('/db/merchant-incoming-orders', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const rows = await getMerchantIncomingOrders(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get merchant-incoming-orders error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load merchant orders.' });
  }
});

app.put('/db/incoming-order-status', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const orderId = String(req.body?.orderId || req.body?.id || '').trim();
    if (!orderId) {
      return res.status(400).json({ message: 'Order id is required.' });
    }
    const row = await updateIncomingOrderStatus(phone, orderId, {
      statusKey: req.body?.statusKey,
      statusAr: req.body?.statusAr,
      statusEn: req.body?.statusEn,
      noteAr: req.body?.noteAr,
      noteEn: req.body?.noteEn,
      deliveryStatusKey: req.body?.deliveryStatusKey,
      deliveryStatusAr: req.body?.deliveryStatusAr,
      deliveryStatusEn: req.body?.deliveryStatusEn,
    });
    return res.json(row);
  } catch (error) {
    console.error('update incoming-order-status error:', error);
    const status = String(error?.message || '').includes('not allowed') ? 403 : 500;
    return res.status(status).json({ message: error?.message || 'Failed to update order status.' });
  }
});

app.get('/db/delivery-pool', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const rows = await getDeliveryPoolOrders(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get delivery-pool error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load delivery pool.' });
  }
});

app.get('/db/courier-orders', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const rows = await getCourierAssignedOrders(phone);
    return res.json(rows);
  } catch (error) {
    console.error('get courier-orders error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load courier orders.' });
  }
});

app.put('/db/delivery-order/accept', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const orderId = String(req.body?.orderId || req.body?.id || '').trim();
    if (!orderId) {
      return res.status(400).json({ message: 'Order id is required.' });
    }
    const row = await acceptDeliveryOrder(phone, orderId, req.body || {});
    return res.json(row);
  } catch (error) {
    console.error('accept delivery-order error:', error);
    const message = error?.message || 'Failed to accept delivery order.';
    const status = message.includes('not available') ? 409 : 500;
    return res.status(status).json({ message });
  }
});

app.put('/db/delivery-order/status', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const orderId = String(req.body?.orderId || req.body?.id || '').trim();
    if (!orderId) {
      return res.status(400).json({ message: 'Order id is required.' });
    }
    const row = await updateCourierDeliveryStatus(phone, orderId, {
      deliveryStatusKey: req.body?.deliveryStatusKey,
      deliveryStatusAr: req.body?.deliveryStatusAr,
      deliveryStatusEn: req.body?.deliveryStatusEn,
    });
    return res.json(row);
  } catch (error) {
    console.error('update delivery-order status error:', error);
    const message = error?.message || 'Failed to update delivery status.';
    const status = message.includes('not assigned') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

app.put('/db/delivery-order/reject', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const orderId = String(req.body?.orderId || req.body?.id || '').trim();
    if (!orderId) {
      return res.status(400).json({ message: 'Order id is required.' });
    }
    const row = await rejectDeliveryOrder(phone, orderId);
    return res.json(row);
  } catch (error) {
    console.error('reject delivery-order error:', error);
    const message = error?.message || 'Failed to reject delivery order.';
    const status = message.includes('not available') ? 409 : 500;
    return res.status(status).json({ message });
  }
});

app.get('/db/admin/reports', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const reports = await getAdminReports(phone);
    return res.json(reports);
  } catch (error) {
    console.error('admin reports error:', error);
    const message = error?.message || 'Failed to load admin reports.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

app.get('/db/real-estate-listings', async (req, res) => {
  try {
    const subCategoryId = String(parseQueryValue(req.query.subCategoryId) || '').trim();
    const listingMode = String(parseQueryValue(req.query.listingMode) || '').trim();
    const rows = await listRealEstateListings(subCategoryId, listingMode);
    return res.json(rows);
  } catch (error) {
    console.error('list real-estate-listings error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load real estate listings.' });
  }
});

app.get('/db/admin/merchants', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const merchants = await getAllMerchants(phone);
    return res.json(merchants);
  } catch (error) {
    console.error('admin merchants error:', error);
    const message = error?.message || 'Failed to load merchants.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

app.get('/db/admin/merchant-details', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const merchantPhone = String(parseQueryValue(req.query.merchantPhone) || '').trim();
    if (!merchantPhone) {
      return res.status(400).json({ message: 'merchantPhone is required.' });
    }
    const details = await getAdminMerchantDetails(phone, merchantPhone);
    return res.json(details);
  } catch (error) {
    console.error('admin merchant-details error:', error);
    const message = error?.message || 'Failed to load merchant details.';
    const status = message.includes('Admin access')
      ? 403
      : message.includes('required')
        ? 400
        : message.includes('not found')
          ? 404
          : 500;
    return res.status(status).json({ message });
  }
});

app.put('/db/admin/merchant-bazaar', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const merchantPhone = String(req.body?.merchantPhone || '').trim();
    const isBazaarMember = req.body?.isBazaarMember === true;
    if (!merchantPhone) {
      return res.status(400).json({ message: 'merchantPhone is required.' });
    }
    const result = await toggleBazaarMemberStatus(phone, merchantPhone, isBazaarMember);
    return res.json(result);
  } catch (error) {
    console.error('toggle bazaar error:', error);
    const message = error?.message || 'Failed to toggle bazaar status.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

app.put('/db/admin/merchant-freeze', async (req, res) => {
  try {
    const phone = requireAuthorizedPhone(req, res, { allowMissing: true });
    if (!phone) return;
    const merchantPhone = String(req.body?.merchantPhone || '').trim();
    const isFrozen = req.body?.isFrozen === true;
    if (!merchantPhone) {
      return res.status(400).json({ message: 'merchantPhone is required.' });
    }
    const result = await toggleMerchantFreezeStatus(phone, merchantPhone, isFrozen);
    return res.json(result);
  } catch (error) {
    console.error('toggle freeze error:', error);
    const message = error?.message || 'Failed to toggle freeze status.';
    const status = message.includes('Admin access') ? 403 : 500;
    return res.status(status).json({ message });
  }
});

app.listen(port, () => {
  console.log(`Auth backend listening on port ${port}`);
});
