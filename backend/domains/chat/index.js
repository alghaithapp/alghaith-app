module.exports = {
  id: 'chat',
  mountPath: '/db/chat',
  router: require('../../routes/chat'),
  repository: {
    chat: require('../../supabase_repo/chat'),
  },
};
