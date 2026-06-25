const logger = require('../lib/logger');
const { expireStalePendingTaxiRequests } = require('../supabase_repo/taxi');

const TAXI_SCHEDULER_INTERVAL_MS = 30 * 1000;
let running = false;

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

function startTaxiScheduler() {
  if (running) return;
  running = true;
  void runTaxiSchedulerTick();
  setInterval(runTaxiSchedulerTick, TAXI_SCHEDULER_INTERVAL_MS);
  logger.info('Taxi scheduler started');
}

module.exports = { startTaxiScheduler, runTaxiSchedulerTick };
