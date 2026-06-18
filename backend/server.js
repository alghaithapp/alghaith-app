require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const crypto = require('crypto');
const cors = require('cors');
const express = require('express');
const helmet = require('helmet');
const rateLimitLib = require('express-rate-limit');
const rateLimit = rateLimitLib.default || rateLimitLib;
const { version: backendVersion } = require('./package.json');
const { isPushConfigured } = require('./push_notifications');
const { startPushScheduler } = require('./push_scheduler');
const { validatePromoCode } = require('./promo_codes');
const { normalizePhone } = require('./routes/_middleware');

// ── Config ──────────────────────────────────────────────────────────────

const app = express();
const port = process.env.PORT || 3000;
// Railway/most managed platforms sit behind a reverse proxy.
app.set('trust proxy', 1);

const sessionSecret = String(process.env.SESSION_SECRET || '').trim();
const mapboxAccessToken = String(process.env.MAPBOX_ACCESS_TOKEN || '').trim();

const corsAllowedOrigins = String(process.env.CORS_ALLOWED_ORIGINS || '')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

// ── Warnings ────────────────────────────────────────────────────────────

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

if (!isPushConfigured()) {
  console.warn(
    'Missing FIREBASE_SERVICE_ACCOUNT_JSON. Push notifications are disabled until you add the Firebase service account JSON to Railway env.'
  );
}

// ── CORS ────────────────────────────────────────────────────────────────

function isAllowedCorsOrigin(origin) {
  if (!origin) return true;
  if (corsAllowedOrigins.length === 0 || corsAllowedOrigins.includes(origin)) {
    return true;
  }
  return /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/i.test(origin);
}

app.use(helmet());
app.use(
  cors({
    origin(origin, callback) {
      if (isAllowedCorsOrigin(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error('Not allowed by CORS'));
    },
  })
);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ── General rate limiter ────────────────────────────────────────────────

const generalRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: Number.parseInt(process.env.RATE_LIMIT_GENERAL_MAX || '120', 10),
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many requests. Try again later.' },
});

app.use(generalRateLimiter);

// ── Session helpers ─────────────────────────────────────────────────────

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

// ── Health endpoint ─────────────────────────────────────────────────────

app.get('/health', (_, res) => {
  res.json({
    ok: true,
    version: backendVersion,
    pushConfigured: isPushConfigured(),
  });
});

// ── DB auth middleware ─────────────────────────────────────────────────

app.use('/db', (req, res, next) => {
  const publicPaths = new Set([
    '/professionals',
    '/shopping-stores',
    '/restaurant-stores',
    '/service-stores',
    '/catalog-products',
    '/offer-catalog-products',
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

// ── Route mounts ────────────────────────────────────────────────────────

app.use('/auth', require('./routes/auth'));
app.use('/maps', require('./routes/maps'));
app.use('/app', require('./routes/app'));
app.use('/db', require('./routes/users'));
app.use('/db', require('./routes/merchants'));
app.use('/db', require('./routes/marketplace'));
app.use('/db', require('./routes/delivery'));
app.use('/db', require('./routes/taxi'));
app.use('/db', require('./routes/admin'));

// ── Promo code validation (kept inline) ────────────────────────────────

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

// ── 404 handlers ────────────────────────────────────────────────────────

app.use('/db', (req, res) => {
  return res.status(404).json({ message: `Unknown database route: ${req.method} ${req.path}` });
});

app.use((req, res) => {
  return res.status(404).json({ message: `Unknown route: ${req.method} ${req.path}` });
});

// ── Start server ────────────────────────────────────────────────────────

app.listen(port, () => {
  console.log(`Auth backend listening on port ${port}`);
  if (isPushConfigured()) {
    startPushScheduler();
    console.log('Push scheduler started.');
  }
});
