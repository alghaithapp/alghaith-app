require('dotenv').config({ path: require('path').join(__dirname, '.env') });

const cors = require('cors');
const express = require('express');
const helmet = require('helmet');
const rateLimitLib = require('express-rate-limit');
const rateLimit = rateLimitLib.default || rateLimitLib;
const { version: backendVersion } = require('./package.json');
const { isPushConfigured } = require('./push_notifications');
const { startPushScheduler } = require('./push_scheduler');
const { validatePromoCode } = require('./promo_codes');
const logger = require('./lib/logger');
const { errorHandler, notFoundHandler } = require('./lib/error_handler');
const { verifySessionToken } = require('./lib/session');

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

// ── General rate limiter ────────────────────────────────────────────────

const generalRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: Number.parseInt(process.env.RATE_LIMIT_GENERAL_MAX || '120', 10),
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many requests. Try again later.' },
});

app.use(generalRateLimiter);

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
  });
});

// ── Emergency recovery (public, خارج نطاق /db) ─────────────────────────
app.get('/__/recover-merchant', async (req, res) => {
  try {
    const phone = String(req.body?.phone || req.query?.phone || '').trim();
    if (!phone) return res.status(400).json({ message: 'phone required' });
    const { getAppUser, getUserState, assertSupabaseAdmin } = require('./supabase_repo');
    const supabase = assertSupabaseAdmin();
    const [appUser, userState] = await Promise.all([
      getAppUser(phone).catch(() => null),
      getUserState(phone).catch(() => null),
    ]);
    if (!appUser) return res.json({ error: 'user not found' });
    const store = userState?.merchantStore || userState?.store || userState?.merchant_profile;
    if (!store) return res.json({ error: 'no merchant store found in app_state' });
    const profileRow = {
      phone: appUser.phone || phone,
      store_name: store.name || store.store_name || '',
      description: store.description || '',
      is_open: store.isOpen ?? store.is_open ?? true,
      is_approved: store.isApproved ?? store.is_approved ?? true,
      approval_status: store.approvalStatus || store.approval_status || 'approved',
      latitude: store.latitude ?? store.lat ?? null,
      longitude: store.longitude ?? store.lng ?? null,
      address: store.address || '',
      delivery_fee: store.deliveryFee ?? store.delivery_fee ?? 0,
      delivery_areas: store.deliveryAreas || store.delivery_areas || '',
      contact_phone: store.phone || appUser.phone || phone,
      updated_at: new Date().toISOString(),
    };
    const { error } = await supabase.from('merchant_profiles').upsert(profileRow, { onConflict: 'phone' });
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ success: true, phone, store_name: profileRow.store_name });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// ── Bulk recovery: استعادة جميع التجار من app_state ────────────────────
app.get('/__/recover-all-merchants', async (req, res) => {
  try {
    const { getAppUser, getUserState, assertSupabaseAdmin } = require('./supabase_repo');
    const supabase = assertSupabaseAdmin();
    const { data: states } = await supabase.from('app_state').select('phone, state').limit(500);
    if (!states) return res.json({ recovered: 0, errors: [] });
    
    const { data: existingProfiles } = await supabase.from('merchant_profiles').select('phone');
    const existingPhones = new Set((existingProfiles || []).map(r => r.phone));
    
    let recovered = 0;
    const errors = [];
    
    for (const row of states) {
      const state = row.state || {};
      const store = state.merchantStore || state.store || state.merchant_profile;
      if (!store) continue;
      const phone = row.phone;
      if (existingPhones.has(phone)) continue;
      
      try {
        const profileRow = {
          phone,
          store_name: String(store.name || store.store_name || '').trim(),
          description: String(store.description || '').trim(),
          is_open: store.isOpen ?? store.is_open ?? true,
          is_approved: store.isApproved ?? store.is_approved ?? false,
          approval_status: String(store.approvalStatus || store.approval_status || 'pending').trim(),
          latitude: store.latitude ?? store.lat ?? null,
          longitude: store.longitude ?? store.lng ?? null,
          address: String(store.address || '').trim(),
          delivery_fee: store.deliveryFee ?? store.delivery_fee ?? 0,
          delivery_areas: String(store.deliveryAreas || store.delivery_areas || '').trim(),
          contact_phone: String(store.phone || phone).trim(),
          updated_at: new Date().toISOString(),
        };
        if (!profileRow.store_name) continue;
        await supabase.from('merchant_profiles').upsert(profileRow, { onConflict: 'phone' });
        recovered++;
      } catch (e) {
        errors.push({ phone, error: e.message });
      }
    }
    return res.json({ recovered, totalScanned: states.length, errors });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// ── Debug endpoint (public) ─────────────────────────────────────────────
app.get('/db/debug/user-bundle', async (req, res) => {
  try {
    const phone = String(req.query?.phone || '').trim();
    if (!phone) return res.status(400).json({ message: 'phone required' });
    const { getAppUser, getUserState, assertSupabaseAdmin } = require('./supabase_repo');
    const supabase = assertSupabaseAdmin();
    let merchantProfile = null;
    let productCount = 0;
    try {
      const { data } = await supabase.from('merchant_profiles').select('store_name, is_approved, approval_status').eq('phone', phone).maybeSingle();
      merchantProfile = data;
    } catch (_) {}
    try {
      const { count } = await supabase.from('merchant_products').select('id', { count: 'exact', head: true }).eq('phone', phone);
      productCount = count || 0;
    } catch (_) {}
    const [appUser, userState] = await Promise.all([
      getAppUser(phone).catch(e => ({ error: e.message })),
      getUserState(phone).catch(e => ({ error: e.message })),
    ]);
    return res.json({
      phone,
      appUser: appUser?.phone ? { phone: appUser.phone, full_name: appUser.full_name, role: appUser.role } : null,
      merchantProfile: merchantProfile?.store_name ? { store_name: merchantProfile.store_name, is_approved: merchantProfile.is_approved, approval_status: merchantProfile.approval_status } : null,
      merchantProductsCount: productCount,
      userStateKeys: userState ? Object.keys(userState) : null,
      hasDriver: userState?.driverProfile?.name ? true : false,
      hasCourier: userState?.courierProfile?.name ? true : false,
      hasMerchantInState: userState?.merchantStore?.name || userState?.merchantStore?.store_name ? true : false,
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
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
app.use('/db', require('./routes/admin'));
app.use('/db/chat', require('./routes/chat'));
app.use('/db/taxi', require('./routes/taxi'));

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
  if (isPushConfigured()) {
    startPushScheduler();
    logger.info('Push scheduler started');
  }
});
