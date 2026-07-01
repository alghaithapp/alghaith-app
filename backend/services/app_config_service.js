/**
 * App Config Service
 * إعدادات التطبيق الديناميكية — تعديل بدون تحديث المتجر
 */

const { assertSupabaseAdmin } = require('../supabase_repo/common');

const _cache = {};
let _cacheTimestamp = 0;
const CACHE_TTL_MS = 60_000; // دقيقة واحدة

async function _queryConfigs() {
  const supabase = assertSupabaseAdmin();
  const { data, error } = await supabase.from('app_configs').select('key, value');
  if (error) throw new Error(`Failed to load app configs: ${error.message}`);
  const map = {};
  for (const row of data || []) {
    map[row.key] = row.value;
  }
  _cache = map;
  _cacheTimestamp = Date.now();
  return map;
}

async function _getConfigs() {
  if (Date.now() - _cacheTimestamp > CACHE_TTL_MS || Object.keys(_cache).length === 0) {
    return await _queryConfigs();
  }
  return _cache;
}

function _mergeWithDefaults(key, config, defaults) {
  if (!config || typeof config !== 'object') return defaults;
  if (typeof defaults === 'object' && !Array.isArray(defaults)) {
    return { ...defaults, ...config };
  }
  return config;
}

// ── Taxi Pricing ──────────────────────────────────────────────────
async function getTaxiPricing() {
  const configs = await _getConfigs();
  return _mergeWithDefaults('taxi_pricing', configs['taxi_pricing'], {
    tuktuk: { base: 1000, extraKm: 250, min: 1000 },
    wazz: { base: 1500, extraKm: 300, min: 1500 },
    economic: { base: 1500, extraKm: 500, min: 1500 },
    maxFare: 50000,
    includedKm: 2.0,
    roundingStep: 250,
  });
}

async function getTaxiConfig() {
  const configs = await _getConfigs();
  return _mergeWithDefaults('taxi_config', configs['taxi_config'], {
    searchTimeoutSeconds: 300,
    maxStops: 3,
    matchingRadiusKm: 10,
    matchingRadiusExpandKm: 25,
    maxDriversPerNotify: 40,
  });
}

// ── Map Defaults ──────────────────────────────────────────────────
async function getMapDefaults() {
  const configs = await _getConfigs();
  return _mergeWithDefaults('map_defaults', configs['map_defaults'], {
    centerLat: 32.9256,
    centerLng: 44.7766,
    defaultZoom: 12,
  });
}

// ── Home Categories ───────────────────────────────────────────────
async function getHomeCategories() {
  const configs = await _getConfigs();
  const defaultOrder = ['restaurant', 'cars', 'product', 'eden_printing', 'global_shopping'];
  const raw = configs['home_categories'];
  if (!raw || typeof raw !== 'object') return { order: defaultOrder, categories: {} };
  return {
    order: Array.isArray(raw.order) ? raw.order : defaultOrder,
    categories: raw.categories || {},
  };
}

async function getSubCategories() {
  const configs = await _getConfigs();
  return configs['sub_categories'] || {};
}

// ── Neighborhoods ─────────────────────────────────────────────────
async function getNeighborhoods() {
  const configs = await _getConfigs();
  return configs['neighborhoods'] || {};
}

// ── Notification Texts ────────────────────────────────────────────
async function getNotificationTexts() {
  const configs = await _getConfigs();
  return configs['notification_texts'] || {};
}

async function getCartConfig() {
  const configs = await _getConfigs();
  return _mergeWithDefaults('cart_config', configs['cart_config'], {
    minAmount: 1000,
    maxAmount: 500000,
    enabledCategoryIds: ['restaurant', 'product', 'bazar_ghaith'],
  });
}

async function getCategoryConfig() {
  const configs = await _getConfigs();
  return _mergeWithDefaults('category_config', configs['category_config'], {
    professionalExcludedIds: [],
  });
}

async function getDeliveryConfig() {
  const configs = await _getConfigs();
  return _mergeWithDefaults('delivery_config', configs['delivery_config'], {
    defaultFee: 3000,
    processingTimeoutMinutes: 30,
  });
}

async function getErrorMessages() {
  const configs = await _getConfigs();
  return _mergeWithDefaults('error_messages', configs['error_messages'], {
    network: 'خطأ في الاتصال. تحقق من الإنترنت وحاول مجدداً.',
    server: 'الخدمة غير متاحة حالياً. حاول لاحقاً.',
    generic: 'تعذر إكمال الطلب حالياً. حاول مرة أخرى.',
  });
}

// ── App Theme ─────────────────────────────────────────────────────
async function getAppTheme() {
  const configs = await _getConfigs();
  return configs['app_theme'] || {};
}

// ── Admin: Update Config ──────────────────────────────────────────
async function updateConfig(key, value) {
  const supabase = assertSupabaseAdmin();
  const { error } = await supabase
    .from('app_configs')
    .upsert({ key, value, updated_at: new Date().toISOString() }, { onConflict: 'key' });
  if (error) throw new Error(`Failed to update config: ${error.message}`);
  // Clear cache
  _cacheTimestamp = 0;
  return { success: true, key };
}

async function getAllConfigs() {
  return await _getConfigs();
}

module.exports = {
  getTaxiPricing,
  getTaxiConfig,
  getMapDefaults,
  getHomeCategories,
  getSubCategories,
  getNeighborhoods,
  getNotificationTexts,
  getAppTheme,
  getCartConfig,
  getCategoryConfig,
  getDeliveryConfig,
  getErrorMessages,
  updateConfig,
  getAllConfigs,
};
