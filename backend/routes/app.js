const express = require('express');
const router = express.Router();
const {
  getAppUpdatePolicy,
  getHomeCategoriesConfig,
} = require('../supabase_repo');

router.get('/update-policy', async (_req, res) => {
  try {
    const policy = await getAppUpdatePolicy();
    return res.json({
      ...policy,
      minBuildNumber: 1,
      forceUpdate: false,
    });
  } catch (error) {
    console.error('app update policy error:', error);
    return res.status(500).json({
      message: error?.message || 'Failed to load app update policy.',
    });
  }
});

router.get('/home-categories', async (_req, res) => {
  try {
    const config = await getHomeCategoriesConfig();
    return res.json(config);
  } catch (error) {
    console.error('home categories config error:', error);
    return res.status(500).json({
      message: error?.message || 'Failed to load home categories config.',
    });
  }
});

module.exports = router;
