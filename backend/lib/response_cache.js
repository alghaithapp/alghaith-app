/**
 * كاش استجابات للمسارات العامة — ذاكرة محلية + Redis اختياري (REDIS_URL).
 * يُسرّع القراءة المتكررة دون تغيير التطبيق.
 */

const logger = require('./logger');

const memoryStore = new Map();
let redisClient = null;
let redisInitAttempted = false;

function parseTtlMs(value, fallbackMs) {
  const parsed = Number.parseInt(String(value || ''), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallbackMs;
}

const DEFAULT_TTLS = {
  homeCategories: parseTtlMs(process.env.CACHE_TTL_HOME_CATEGORIES_MS, 5 * 60_000),
  marketplaceStats: parseTtlMs(process.env.CACHE_TTL_MARKETPLACE_STATS_MS, 3 * 60_000),
  storeLists: parseTtlMs(process.env.CACHE_TTL_STORE_LISTS_MS, 2 * 60_000),
  catalog: parseTtlMs(process.env.CACHE_TTL_CATALOG_MS, 2 * 60_000),
  appPolicy: parseTtlMs(process.env.CACHE_TTL_APP_POLICY_MS, 10 * 60_000),
};

function getRedisClient() {
  if (redisInitAttempted) return redisClient;
  redisInitAttempted = true;

  const url = String(process.env.REDIS_URL || '').trim();
  if (!url) return null;

  try {
    const Redis = require('ioredis');
    redisClient = new Redis(url, {
      maxRetriesPerRequest: 1,
      enableReadyCheck: true,
      lazyConnect: true,
    });
    redisClient.on('error', (error) => {
      logger.warn('response_cache redis error', { message: error?.message || error });
    });
    redisClient.connect().catch((error) => {
      logger.warn('response_cache redis connect failed', {
        message: error?.message || error,
      });
    });
  } catch (error) {
    logger.warn('response_cache redis unavailable', { message: error?.message || error });
    redisClient = null;
  }

  return redisClient;
}

function readMemory(key) {
  const entry = memoryStore.get(key);
  if (!entry) return null;
  if (entry.expiresAt <= Date.now()) {
    memoryStore.delete(key);
    return null;
  }
  return entry.value;
}

function writeMemory(key, value, ttlMs) {
  memoryStore.set(key, {
    value,
    expiresAt: Date.now() + ttlMs,
  });
}

async function readRedis(key) {
  const client = getRedisClient();
  if (!client) return null;
  try {
    const raw = await client.get(`rc:${key}`);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
}

async function writeRedis(key, value, ttlMs) {
  const client = getRedisClient();
  if (!client) return;
  try {
    const ttlSeconds = Math.max(1, Math.ceil(ttlMs / 1000));
    await client.set(`rc:${key}`, JSON.stringify(value), 'EX', ttlSeconds);
  } catch (_) {
    // ignore redis write errors — memory cache still helps
  }
}

async function getCached(key) {
  const memoryValue = readMemory(key);
  if (memoryValue !== null) {
    return { value: memoryValue, source: 'memory' };
  }

  const redisValue = await readRedis(key);
  if (redisValue !== null) {
    writeMemory(key, redisValue, 60_000);
    return { value: redisValue, source: 'redis' };
  }

  return null;
}

async function setCached(key, value, ttlMs) {
  writeMemory(key, value, ttlMs);
  await writeRedis(key, value, ttlMs);
}

/**
 * @template T
 * @param {string} key
 * @param {number} ttlMs
 * @param {() => Promise<T>} loader
 * @returns {Promise<{ value: T, cacheHit: boolean, cacheSource: string | null }>}
 */
async function remember(key, ttlMs, loader) {
  const cached = await getCached(key);
  if (cached) {
    return {
      value: cached.value,
      cacheHit: true,
      cacheSource: cached.source,
    };
  }

  const value = await loader();
  await setCached(key, value, ttlMs);
  return {
    value,
    cacheHit: false,
    cacheSource: null,
  };
}

function cacheStats() {
  const now = Date.now();
  let active = 0;
  for (const entry of memoryStore.values()) {
    if (entry.expiresAt > now) active += 1;
  }
  return {
    memoryEntries: active,
    redisConfigured: Boolean(String(process.env.REDIS_URL || '').trim()),
    redisConnected: Boolean(redisClient && redisClient.status === 'ready'),
    ttlsMs: DEFAULT_TTLS,
  };
}

function setCacheHeader(res, cacheHit, cacheSource) {
  if (!res || res.headersSent) return;
  res.setHeader('X-Cache', cacheHit ? 'HIT' : 'MISS');
  if (cacheSource) {
    res.setHeader('X-Cache-Source', cacheSource);
  }
}

module.exports = {
  DEFAULT_TTLS,
  remember,
  cacheStats,
  setCacheHeader,
};
