/**
 * Supabase Repository — Module Index
 *
 * يجمع ويُعيد تصدير جميع الوظائف من الوحدات الفرعية
 * ليحافظ على التوافق مع require('./supabase_repo') الموجود في server.js والملفات الأخرى.
 */

const common = require('./common');
const users = require('./users');
const customer_data = require('./customer_data');
const merchants = require('./merchants');
const orders = require('./orders');
const couriers_drivers = require('./couriers_drivers');
const admin = require('./admin');
const push_notifications = require('./push_notifications');
const taxi = require('./taxi');
const admin_roles = require('./admin_roles');

module.exports = {
  // Common / Config
  ...common,

  // Users & State
  ...users,

  // Customer Data (profiles, addresses, favorites)
  ...customer_data,

  // Merchants, Products, Reviews, Marketplace
  ...merchants,

  // Orders & Delivery
  ...orders,

  // Couriers & Drivers helpers
  ...couriers_drivers,

  // Admin
  ...admin,

  // Push notifications
  ...push_notifications,

  // Taxi
  ...taxi,

  // Admin Roles
  ...admin_roles,

};
