/// Keys allowed in remote `app_state` — UI and preferences only.
class AppStatePolicy {
  AppStatePolicy._();

  static const forbiddenKeys = {
    'orders',
    'items',
    'merchantStore',
    'driverProfile',
    'courierProfile',
    'merchantOffers',
    'merchantReviews',
    'merchantProfileComplete',
    'adminAccess',
    'accountType',
    'userRole',
    'user_role',
    'customerPhone',
    'customerName',
    'customerAddress',
    'customerLatitude',
    'customerLongitude',
    'customerAvatarBase64',
    'customerAvatarUrl',
    'profileComplete',
  };

  static const allowedKeys = {
    'darkMode',
    'inAppAlertsEnabled',
    'notificationsEnabled',
    'lastMainTab',
    'homeCategoryFilter',
    'catalogSearchHistory',
    'drafts',
    'syncHints',
    'skippedCustomerSetup',
    'driverType',
    'taxiFavoritePlaces',
    'adminRole',
    'admin_role',
    'lang',
    'accountSuspended',
    'suspendedAt',
  };

  /// Strips business keys and keeps UI-only keys before `/db/user-state`.
  static Map<String, dynamic> stripForRemotePersist(
    Map<String, dynamic> state,
  ) {
    if (state.isEmpty) return {};
    final out = <String, dynamic>{};
    for (final key in allowedKeys) {
      if (state.containsKey(key)) {
        out[key] = state[key];
      }
    }
    return out;
  }
}
