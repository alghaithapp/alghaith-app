require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const cors = require('cors');
const express = require('express');
const helmet = require('helmet');
const rateLimitLib = require('express-rate-limit');
const rateLimit = rateLimitLib.default || rateLimitLib;
const { version: backendVersion } = require('./package.json');
const { isPushConfigured } = require('./push_notifications');
const { mountDomainRoutes, startDomainWorkers } = require('./domains/registry');
const { validatePromoCode } = require('./promo_codes');
const logger = require('./lib/logger');
const { errorHandler, notFoundHandler } = require('./lib/error_handler');
const { verifySessionToken } = require('./lib/session');
const { cacheStats } = require('./lib/response_cache');
const { scheduleServerWarmup } = require('./lib/server_warmup');
const { redisStats } = require('./lib/redis_client');

// ── Config ──────────────────────────────────────────────────────────────

const app = express();
const port = process.env.PORT || 3000;
app.set('trust proxy', 1);

const sessionSecret = String(process.env.SESSION_SECRET || '').trim();
const mapboxAccessToken = String(process.env.MAPBOX_ACCESS_TOKEN || '').trim();

const corsAllowedOrigins = String(process.env.CORS_ALLOWED_ORIGINS || '')
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);

// ── Warnings ────────────────────────────────────────────────────────────

if (!sessionSecret) {
  logger.warn('Missing SESSION_SECRET');
}

if (!mapboxAccessToken) {
  logger.warn('Missing MAPBOX_ACCESS_TOKEN');
}

if (!isPushConfigured()) {
  logger.warn('Missing FIREBASE_SERVICE_ACCOUNT_JSON');
}

// ── CORS ────────────────────────────────────────────────────────────────

function isAllowedCorsOrigin(origin) {
  if (!origin) return true;
  if (corsAllowedOrigins.length === 0 || corsAllowedOrigins.includes(origin)) {
    return true;
  }
  // Allow localhost / local-dev origins
  if (/^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/i.test(origin)) {
    return true;
  }
  // Allow Tauri desktop app origins (v1 uses tauri://localhost, v2 uses https://tauri.localhost)
  if (/^tauri:\/\/localhost(:\d+)?$/i.test(origin)) {
    return true;
  }
  if (/^https:\/\/tauri\.localhost(:\d+)?$/i.test(origin)) {
    return true;
  }
  return false;
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

app.use((req, res, next) => {
  const startedAt = process.hrtime.bigint();
  const originalWriteHead = res.writeHead;
  res.writeHead = function writeHeadWithTiming(...args) {
    const elapsedMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
    if (!res.headersSent) {
      res.setHeader('X-Response-Time-Ms', elapsedMs.toFixed(1));
    }
    return originalWriteHead.apply(this, args);
  };
  res.on('finish', () => {
    const elapsedMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
    if (elapsedMs >= Number.parseInt(process.env.SLOW_REQUEST_MS || '1000', 10)) {
      logger.warn('slow request', {
        method: req.method,
        path: req.originalUrl,
        status: res.statusCode,
        elapsedMs: Math.round(elapsedMs),
      });
    }
  });
  next();
});

// ── Per-route rate limiters ─────────────────────────────────────────────
// كل مسار بحد خاص حسب احتياجه، بدل limiter عام يمنع كل شيء.

const minute = 60 * 1000;

function createLimiter(maxReqs, windowMs = minute) {
  const options = {
    windowMs,
    max: Number.parseInt(process.env[`RATE_LIMIT_${maxReqs}`] || String(maxReqs), 10),
    standardHeaders: true,
    legacyHeaders: false,
    message: { message: 'Too many requests. Try again later.' },
    keyGenerator: (req) => {
      // إذا كان الطلب يحتوي على توكن تسجيل دخول، نقوم بتحديد المعدل بناءً على التوكن لمنع تعارض المستخدمين المشتركين في نفس الـ IP (شبكات الهاتف)
      const authHeader = req.headers.authorization;
      if (authHeader && authHeader.startsWith('Bearer ')) {
        const token = authHeader.slice(7).trim();
        if (token) return `token:${token}`;
      }
      return req.ip;
    },
  };

  return rateLimit(options);
}

// مسارات سريعة للصحة والمعلومات العامة
app.use('/health', createLimiter(500));
app.use('/app', createLimiter(400));

// مسارات المحادثة — تحتاج حد أعلى بسبب الـ polling
app.use('/db/chat', createLimiter(600));

// مسارات التكسي والخرائط
app.use('/db/taxi', createLimiter(1200));
app.use('/maps', createLimiter(300));

// مسارات المصادقة — حد منخفض للحماية من brute force
app.use('/auth', createLimiter(60));

// المسارات الأخرى (الطلبات، المتاجر، المستخدمين، إلخ)
app.use('/db', createLimiter(300));

// ── Session verification ────────────────────────────────────────────────
// تستخدم دوال verifySessionToken من lib/session.js
// يتطابق التنفيذ مع Cloudflare Worker cloudflare_worker.js
// لضمان اتساق التحقق من رموز الجلسة عبر البيئتين.

// ── Health endpoint ─────────────────────────────────────────────────────

app.get('/health', (_, res) => {
  res.json({
    ok: true,
    version: backendVersion,
    pushConfigured: isPushConfigured(),
    cache: cacheStats(),
    redis: redisStats(),
  });
});

// ── Feature flags ──────────────────────────────────────────────────
app.use('/app', require('./routes/features'));

// ── Dynamic app config ─────────────────────────────────────────────
app.use('/app/config', require('./routes/app_config'));

// ── Emergency / debug routes (disabled unless ENABLE_EMERGENCY_ROUTES=true + key) ──
app.use(require('./routes/emergency'));

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

// ── Route mounts (domain registry) ─────────────────────────────────────

mountDomainRoutes(app);

// ── Promo code validation (kept inline) ────────────────────────────────

app.post('/db/validate-promo', async (req, res) => {
  try {
    const code = String(req.body?.code || req.body?.promoCode || '').trim();
    const subtotalIqd = Number(req.body?.subtotalIqd ?? req.body?.subtotal ?? 0);
    const result = validatePromoCode(code, subtotalIqd);
    return res.json(result);
  } catch (error) {
    logger.error('validate-promo error', { error: error.message });
    return res.status(500).json({ message: 'Failed to validate promo code.' });
  }
});

// ── Error handling ─────────────────────────────────────────────────────

app.use('/db', notFoundHandler);
app.use(notFoundHandler);
app.use(errorHandler);

// ── Start server ────────────────────────────────────────────────────────

app.listen(port, () => {
  logger.info(`Backend listening on port ${port} (v${backendVersion})`);
  startDomainWorkers();
  scheduleServerWarmup();
  if (isPushConfigured()) {
    logger.info('Push scheduler started');
  }
});
