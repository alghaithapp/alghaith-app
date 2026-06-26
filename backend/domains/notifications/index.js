const { startPushScheduler } = require('../../push_scheduler');
const { isPushConfigured } = require('../../push_notifications');
const { startNotificationWorker } = require('../../services/notification_queue');

module.exports = {
  id: 'notifications',
  mountPath: null,
  router: null,
  repository: {
    push: require('../../supabase_repo/push_notifications'),
    outbox: require('../../supabase_repo/notification_outbox'),
  },
  push: {
    events: require('../../push_events'),
    taxiEvents: require('../../push/taxi_push_events'),
    queue: require('../../services/notification_queue'),
  },
  startWorkers() {
    startNotificationWorker();
    if (isPushConfigured()) {
      startPushScheduler();
    }
  },
};