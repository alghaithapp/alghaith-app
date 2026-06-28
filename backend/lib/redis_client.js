const logger = require('./logger');

let redisClient = null;
let initAttempted = false;

function getRedisUrl() {
  return String(process.env.REDIS_URL || '').trim();
}

function isRedisConfigured() {
  return Boolean(getRedisUrl());
}

function getRedisClient() {
  if (initAttempted) return redisClient;
  initAttempted = true;

  const url = getRedisUrl();
  if (!url) return null;

  try {
    const Redis = require('ioredis');
    redisClient = new Redis(url, {
      maxRetriesPerRequest: 1,
      enableReadyCheck: true,
      lazyConnect: true,
    });
    redisClient.on('error', (error) => {
      logger.warn('redis error', { message: error?.message || error });
    });
    redisClient.connect().catch((error) => {
      logger.warn('redis connect failed', { message: error?.message || error });
    });
  } catch (error) {
    logger.warn('redis unavailable', { message: error?.message || error });
    redisClient = null;
  }

  return redisClient;
}

async function withRedis(operation, fallback = null) {
  const client = getRedisClient();
  if (!client) return fallback;
  try {
    return await operation(client);
  } catch (error) {
    logger.warn('redis operation failed', { message: error?.message || error });
    return fallback;
  }
}

async function rememberJson(key, ttlSeconds, loader) {
  const namespacedKey = `cache:${key}`;
  const cached = await withRedis(async (client) => client.get(namespacedKey), null);
  if (cached) {
    try {
      return { value: JSON.parse(cached), cacheHit: true, cacheSource: 'redis' };
    } catch (_) {}
  }

  const value = await loader();
  await withRedis(async (client) => {
    await client.set(namespacedKey, JSON.stringify(value), 'EX', Math.max(1, ttlSeconds));
  });
  return { value, cacheHit: false, cacheSource: null };
}

async function acquireLock(key, ttlMs) {
  const token = `${process.pid}:${Date.now()}:${Math.random().toString(36).slice(2)}`;
  const result = await withRedis(async (client) => (
    client.set(`lock:${key}`, token, 'PX', Math.max(100, ttlMs), 'NX')
  ), null);
  return result === 'OK' ? token : null;
}

async function releaseLock(key, token) {
  if (!token) return;
  await withRedis(async (client) => {
    const script = `
      if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("del", KEYS[1])
      end
      return 0
    `;
    await client.eval(script, 1, `lock:${key}`, token);
  });
}

function redisStats() {
  return {
    configured: isRedisConfigured(),
    connected: Boolean(redisClient && redisClient.status === 'ready'),
  };
}

module.exports = {
  getRedisClient,
  isRedisConfigured,
  withRedis,
  rememberJson,
  acquireLock,
  releaseLock,
  redisStats,
};
