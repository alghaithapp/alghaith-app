const logger = require('../lib/logger');
const { expireStalePendingTaxiRequests } = require('../supabase_repo/taxi');
const { expireStaleOnlineDrivers } = require('../domains/taxi/repository/driver_locations');

const TAXI_SCHEDULER_INTERVAL_MS = 30 * 1000;
const STALE_DRIVER_CLEANUP_INTERVAL_MS = 30 * 60 * 1000; // كل 30 دقيقة
let running = false;
let staleDriverCleanupTimer = null;

async function runTaxiSchedulerTick() {
  try {
    const expired = await expireStalePendingTaxiRequests();
    if (expired > 0) {
      logger.info(`Taxi scheduler: auto-cancelled ${expired} stale pending request(s)`);
    }
  } catch (error) {
    logger.error('Taxi scheduler tick failed:', error?.message || error);
  }
}

async function runStaleDriverCleanup() {
  try {
    await expireStaleOnlineDrivers();
    logger.info('Taxi scheduler: stale online drivers cleanup completed');
  } catch (error) {
    logger.error('Taxi scheduler stale driver cleanup failed:', error?.message || error);
  }
}

function startTaxiScheduler() {
  if (running) return;
  running = true;
  void runTaxiSchedulerTick();
  setInterval(runTaxiSchedulerTick, TAXI_SCHEDULER_INTERVAL_MS);

  // تنظيف السائقين الخاملين كل 30 دقيقة
  void runStaleDriverCleanup();
  staleDriverCleanupTimer = setInterval(runStaleDriverCleanup, STALE_DRIVER_CLEANUP_INTERVAL_MS);

  logger.info('Taxi scheduler started');
}

module.exports = { startTaxiScheduler, runTaxiSchedulerTick };
