module.exports = {
  id: 'voice',
  mountPath: '/db/voice',
  router: require('../../routes/voice'),
  repository: {
    callLogs: require('../../supabase_repo/call_logs'),
    chat: require('../../supabase_repo/chat'),
    merchants: require('../../supabase_repo/merchants'),
  },
  services: {
    zego: require('../../services/zego'),
    zegoToken: require('../../services/zego_token04'),
    workingHours: require('../../services/merchant_working_hours'),
  },
};
