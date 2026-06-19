import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/storage/catalog_cache.dart';
import '../../core/storage/home_categories_cache.dart';
import '../../data/models/account_snapshot.dart';
import '../../data/repositories/account_repository.dart';
import '../../services/supabase_service.dart';
import '../../models/app_models.dart';
import '../../models/app_notification.dart';
import '../../models/merchant_models.dart';
import '../../utils/merchant_profile_fields.dart';
import '../../utils/courier_profile_fields.dart';
import '../../utils/driver_profile_fields.dart';
import 'core_mixin.dart';

mixin PersistenceMixin on AppCoreMixin {
  // ── Boot & Init ──────────────────────────────────────────────
  Future<void> _loadSettings() async {
    await _restoreHomeCategoriesFromCache();
    unawaited(refreshHomeCategoriesConfig());

    unawaited(_restoreCatalogFromCache());

    String? restoredPhone;
    try {
      final accountRepo = AccountRepository.instance;
      final stored = await accountRepo.readStoredSession();
      if (stored != null) {
        _sessionToken = stored.token;
        SupabaseService.setSessionToken(stored.token);
        _authPhone = PhoneUtils.normalize(stored.phone);
        restoredPhone = _authPhone;
        _isRestoring = true;
        notifyListeners();
        await _restoreLocalBackup(_authPhone!);
        _resolveRoleAfterAuth();
        _finalizeBootState();
        _startRemoteRestore(restoredPhone!);
      }
    } catch (error) {
      debugPrint('CRITICAL: Initial load failed: $error');
    } finally {
      _bootWatchdog?.cancel();
      _bootWatchdog = null;
      if (!_isLoggingIn && !_isReady) {
        _resolveRoleAfterAuth();
        _finalizeBootState();
      }
    }
  }

  void _finalizeBootState() {
    _isRestoring = false;
    _isHydrating = false;
    _isReady = true;
    if (!hasPhoneSession && !_isGuestMode) {
      _isGuestMode = true;
      _userRole = 'customer';
    }
    if (hasPhoneSession && _authPhone != null && _authPhone!.isNotEmpty) {
      unawaited(PushNotificationService.instance.bindToUser(_authPhone!));
    }
    notifyListeners();
  }

  void _forceBootReady() {
    if (_isReady) return;
    debugPrint('BOOT_WATCHDOG: forcing ready state after timeout');
    _resolveRoleAfterAuth();
    _finalizeBootState();
  }

  void _startRemoteRestore(String phone) {
    unawaited(() async {
      try {
        await _restoreRemoteSessionWithRetry(phone).timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            debugPrint('BOOT_REMOTE_RESTORE_TIMEOUT for $phone');
          },
        );
      } catch (error) {
        debugPrint('BOOT_REMOTE_RESTORE_ERROR: $error');
      }
      if (!hasPhoneSession) return;
      final activePhone = _trimmedOrNull(_authPhone);
      if (activePhone == null || _normalizeStoredPhone(activePhone) != phone) {
        return;
      }
      _resolveRoleAfterAuth();
      notifyListeners();
    }());
  }

  bool _hasMeaningfulRemoteIdentity() {
    return _appUserRecord != null ||
        hasCompletedMerchantProfile ||
        hasCompletedCustomerProfile;
  }

  Future<void> _restoreRemoteSessionWithRetry(
    String phone, {
    int attempts = 3,
    bool deferPostRefresh = false,
  }) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      await _restoreRemoteSession(
        phone,
        deferPostRefresh: deferPostRefresh,
        persistAfterRestore: !deferPostRefresh,
      );
      if (_hasMeaningfulRemoteIdentity()) return;
      if (attempt < attempts - 1) {
        await Future<void>.delayed(Duration(seconds: 1 + attempt));
      }
    }
  }

  Future<void> _enrichRemoteSessionInBackground(String phone) async {
    final normalizedPhone = _normalizeStoredPhone(phone);
    if (normalizedPhone.isEmpty || !hasPhoneSession) return;
    final activePhone = _trimmedOrNull(_authPhone);
    if (activePhone == null ||
        _normalizeStoredPhone(activePhone) != normalizedPhone) {
      return;
    }

    try {
      if (isCustomer) {
        await refreshCustomerCatalog();
        await refreshCustomerOrders();
      }
      if (isMerchant) {
        await _refreshMerchantIncomingOrders();
      }
      if (isDelivery) {
        await refreshCourierOrders();
      }
      if (isDriver || isCustomer) {
        await refreshTaxiRequests();
      }
      await _persistLocalBackup();
      notifyListeners();
    } catch (error) {
      debugPrint('ENRICH_SESSION_ERROR: $error');
    }
  }

  Future<void> refreshAccountFromCloud() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null) return;
    await _restoreRemoteSession(phone);
    notifyListeners();
  }

  // ── Remote session ───────────────────────────────────────────
  Future<void> _restoreRemoteSession(
    String phone, {
    bool deferPostRefresh = false,
    bool persistAfterRestore = true,
  }) async {
    final normalizedPhone = _normalizeStoredPhone(phone);
    if (normalizedPhone.isEmpty || !AppConfig.isBackendConfigured) return;
    final activePhone = _trimmedOrNull(_authPhone);
    if (activePhone != null &&
        _normalizeStoredPhone(activePhone) != normalizedPhone) {
      return;
    }

    debugPrint('RESTORE: Loading data for $normalizedPhone');

    try {
      final bundle =
          await AccountRepository.instance.fetchRemoteAccount(normalizedPhone);
      final latestPhone = _trimmedOrNull(_authPhone);
      if (latestPhone == null ||
          _normalizeStoredPhone(latestPhone) != normalizedPhone) {
        return;
      }

      final appUser = bundle.appUser;
      final customerProfile = bundle.customerProfile;
      final merchantProfile = bundle.merchantProfile;
      final userState = bundle.userState;
      final remoteAddresses = bundle.addresses;
      final remoteFavoriteIds = bundle.favoriteIds;
      final remoteOrders = bundle.orders;
      final remoteProducts = bundle.products;

      if (appUser != null) {
        _appUserRecord = appUser;
        _customerName =
            _trimmedOrNull(appUser['full_name']?.toString()) ?? _customerName;

        final remoteRole = _trimmedOrNull(appUser['role']?.toString());
        if (remoteRole == 'admin') {
          _userRole = 'customer';
          _hasAdminAccess = true;
        } else {
          _userRole = remoteRole ?? _userRole;
        }

        _accountType = _trimmedOrNull(
              appUser['account_type']?.toString() ??
                  appUser['accountType']?.toString(),
            ) ??
            _accountType;
        _customerAvatarBase64 = _trimmedOrNull(
              appUser['avatar_base64']?.toString() ??
                  appUser['customer_avatar_base64']?.toString() ??
                  appUser['avatar_url']?.toString(),
            ) ??
            _customerAvatarBase64;
      }

      if (customerProfile != null) {
        _customerName =
            _trimmedOrNull(customerProfile['display_name']?.toString()) ??
                _customerName;
        _customerAddress =
            _trimmedOrNull(customerProfile['address']?.toString()) ??
                _customerAddress;
        _customerLatitude = (customerProfile['latitude'] as num?)?.toDouble() ??
            (customerProfile['lat'] as num?)?.toDouble() ??
            _customerLatitude;
        _customerLongitude =
            (customerProfile['longitude'] as num?)?.toDouble() ??
                (customerProfile['lng'] as num?)?.toDouble() ??
                _customerLongitude;
        _customerAvatarBase64 = _trimmedOrNull(
                customerProfile['avatar_base64']?.toString() ??
                    customerProfile['avatar_url']?.toString()) ??
            _customerAvatarBase64;
      }

      if (merchantProfile != null) {
        // حماية: لا نستبدل بيانات المتجر المحلية ببيانات فارغة أو قديمة من السحابة
        final hasLocalStore = _merchantStore != null && merchantStoreName.isNotEmpty;
        final remoteStoreName = (merchantProfile['store_name'] as String?)?.trim() ?? '';
        if (!hasLocalStore || remoteStoreName.isNotEmpty) {
          _applyMerchantStoreSnapshot(_mapMerchantProfileRow(merchantProfile));
          if (_userRole == null) {
            _userRole = 'merchant';
          }
        }
      }

      if (userState != null) {
        _applyRemoteState(userState);
      }

      if (_merchantStore == null || merchantStoreName.isEmpty) {
        final backup = userState?['merchantStore'];
        if (backup is Map) {
          _applyMerchantStoreSnapshot(Map<String, dynamic>.from(backup));
        }
      }

      if (remoteAddresses.isNotEmpty) {
        _addresses = List<String>.from(remoteAddresses);
      }

      if (remoteFavoriteIds.isNotEmpty) {
        _favoriteItemIds
          ..clear()
          ..addAll(remoteFavoriteIds);
      }

      if (remoteOrders.isNotEmpty) {
        _orders = List<ActiveOrder>.from(remoteOrders);
      }

      if (remoteProducts.isNotEmpty &&
          (_userRole == 'merchant' || _items.isEmpty)) {
        _items =
            remoteProducts.map((row) => _listItemFromProductRow(row)).toList();
      }
      _applyFavoriteSelections();
      _inferAccountTypeFromLegacyData();
      _inferRoleFromRestoredData();
      _applyAccountTypeConstraints();
      _hydrateCustomerIdentityFromRestoredData();

      if (!deferPostRefresh) {
        try {
          if (isCustomer) {
            await refreshCustomerCatalog();
            await refreshCustomerOrders();
          }
          if (isMerchant) {
            await _refreshMerchantIncomingOrders();
          }
          if (isDelivery) {
            await refreshCourierOrders();
          }
          if (isDriver || isCustomer) {
            await refreshTaxiRequests();
          }
        } catch (error) {
          debugPrint('RESTORE_POST_REFRESH_ERROR: $error');
        }
      }

      if (persistAfterRestore) {
        await _persistLocalBackup();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('RESTORE_ERROR: $e');
    }
  }

  // ── Local backup ─────────────────────────────────────────────
  AccountSnapshot _buildLocalBackupSnapshot() {
    return AccountSnapshot(
      userRole: _userRole,
      hasAdminAccess: _hasAdminAccess,
      accountType: _accountType,
      customerName: _customerName,
      customerPhone: _customerPhone,
      customerAddress: _customerAddress,
      customerLatitude: _customerLatitude,
      customerLongitude: _customerLongitude,
      customerAvatarRef: _customerAvatarBase64,
      darkMode: _darkMode,
      inAppAlertsEnabled: _inAppAlertsEnabled,
      driverType: _driverType,
      driverProfile: _driverProfile,
      courierProfile: _courierProfile,
      merchantStore: _merchantStore,
      merchantOffers: _merchantOffers,
      merchantReviews: _merchantReviews,
      items: _items,
      orders: _orders,
      addresses: _addresses,
      favoriteItemIds: _favoriteItemIds.toList(),
      selectedCategory: _selectedCategory,
      activeSubCategory: _activeSubCategory,
      pendingOrderStatusSyncQueue: _pendingOrderStatusSyncQueue,
      notifications: List<AppNotificationItem>.from(_notifications),
    );
  }

  void _applyLocalBackupSnapshot(Map<String, dynamic> snapshot) {
    _userRole = _trimmedOrNull(snapshot['userRole']?.toString()) ?? _userRole;
    _hasAdminAccess = snapshot['adminAccess'] as bool? ?? _hasAdminAccess;
    _accountType =
        _trimmedOrNull(snapshot['accountType']?.toString()) ?? _accountType;
    _customerName =
        _trimmedOrNull(snapshot['customerName']?.toString()) ?? _customerName;
    _customerPhone =
        _trimmedOrNull(snapshot['customerPhone']?.toString()) ?? _customerPhone;
    _customerAddress =
        _trimmedOrNull(snapshot['customerAddress']?.toString()) ??
            _customerAddress;
    final customerLat = snapshot['customerLatitude'];
    if (customerLat is num) {
      _customerLatitude = customerLat.toDouble();
    }
    final customerLng = snapshot['customerLongitude'];
    if (customerLng is num) {
      _customerLongitude = customerLng.toDouble();
    }
    _customerAvatarBase64 = _trimmedOrNull(
            snapshot['customerAvatarBase64']?.toString() ??
                snapshot['customerAvatarUrl']?.toString()) ??
        _customerAvatarBase64;
    _darkMode = snapshot['darkMode'] as bool? ?? _darkMode;
    _inAppAlertsEnabled =
        snapshot['inAppAlertsEnabled'] as bool? ?? _inAppAlertsEnabled;
    _driverType = snapshot['driverType'] as String? ?? _driverType;
    final driverProfile = snapshot['driverProfile'];
    if (driverProfile is Map) {
      _driverProfile = Map<String, dynamic>.from(driverProfile);
    }
    final courierProfile = snapshot['courierProfile'];
    if (courierProfile is Map) {
      _courierProfile = Map<String, dynamic>.from(courierProfile);
    }

    final merchantStore = snapshot['merchantStore'];
    if (merchantStore is Map) {
      _merchantStore = Map<String, dynamic>.from(merchantStore);
    }

    final offers = snapshot['merchantOffers'];
    if (offers is List) {
      _merchantOffers = offers
          .whereType<Map>()
          .map((item) => MerchantOffer.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    final reviews = snapshot['merchantReviews'];
    if (reviews is List) {
      final parsed = reviews
          .whereType<Map>()
          .map(
              (item) => MerchantReview.fromMap(Map<String, dynamic>.from(item)))
          .toList();
      if (parsed.length > _merchantReviews.length) {
        for (final review in parsed.skip(_merchantReviews.length)) {
          _notificationHub.onNewMerchantReview(
            review.customerName,
            review.stars,
          );
        }
      }
      _merchantReviews = parsed;
    }

    final items = snapshot['items'];
    if (items is List && items.isNotEmpty) {
      _items = items
          .whereType<Map>()
          .map((item) => ListItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    final orders = snapshot['orders'];
    if (orders is List && orders.isNotEmpty) {
      _orders = orders
          .whereType<Map>()
          .map((item) => ActiveOrder.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    final addresses = snapshot['addresses'];
    if (addresses is List) {
      _addresses = addresses.map((item) => item.toString()).toList();
    }

    final favoriteIds = snapshot['favoriteItemIds'];
    if (favoriteIds is List) {
      _favoriteItemIds
        ..clear()
        ..addAll(favoriteIds.map((item) => item.toString()));
      _applyFavoriteSelections();
    }

    _selectedCategory =
        snapshot['selectedCategory'] as String? ?? _selectedCategory;
    _activeSubCategory =
        snapshot['activeSubCategory'] as String? ?? _activeSubCategory;
    final pendingQueue = snapshot['pendingOrderStatusSyncQueue'];
    if (pendingQueue is List) {
      _pendingOrderStatusSyncQueue = pendingQueue
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    _applyNotificationsFromState(snapshot['notifications']);
  }

  Future<bool> _restoreLocalBackup(String phone) async {
    try {
      final snapshot =
          await AccountRepository.instance.readLocalSnapshot(phone);
      if (snapshot == null) return false;
      _applyLocalBackupSnapshot(snapshot.toJson());
      return _userRole != null ||
          _customerName.isNotEmpty ||
          _merchantStore != null ||
          _items.isNotEmpty ||
          _addresses.isNotEmpty;
    } catch (error) {
      debugPrint('LOCAL_BACKUP_RESTORE_ERROR: $error');
      return false;
    }
  }

  Future<void> _persistLocalBackup() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null) return;
    try {
      await AccountRepository.instance.writeLocalSnapshot(
        phone,
        _buildLocalBackupSnapshot(),
      );
    } catch (error) {
      debugPrint('LOCAL_BACKUP_SAVE_ERROR: $error');
    }
  }

  // ── Remote state ─────────────────────────────────────────────
  Map<String, dynamic> _buildRemoteState() {
    return {
      'adminAccess': _hasAdminAccess,
      'darkMode': _darkMode,
      'inAppAlertsEnabled': _inAppAlertsEnabled,
      'driverType': _driverType,
      'driverProfile': _driverProfile,
      'courierProfile': _courierProfile,
      'accountType': _accountType,
      'customerPhone': _customerPhone,
      'customerLatitude': _customerLatitude,
      'customerLongitude': _customerLongitude,
      'userRole': _userRole,
      'customerName': _customerName,
      'customerAvatarBase64': _customerAvatarBase64,
      'customerAvatarUrl': _customerAvatarBase64,
      'profileComplete': hasCompletedCustomerProfile,
      'selectedCategory': _selectedCategory,
      'activeSubCategory': _activeSubCategory,
      'merchantOffers': _merchantOffers.map((offer) => offer.toMap()).toList(),
      'merchantReviews':
          _merchantReviews.map((review) => review.toMap()).toList(),
      'items': _items.map((item) => item.toMap()).toList(),
      'pendingOrderStatusSyncQueue': _pendingOrderStatusSyncQueue,
      if (_merchantStore != null) 'merchantStore': _merchantStore,
      'merchantProfileComplete': hasCompletedMerchantProfile,
      'notifications': _notifications.map((n) => n.toMap()).toList(),
    };
  }

  void _applyRemoteState(Map<String, dynamic> state) {
    final previousCourierProfile = _courierProfile == null
        ? null
        : Map<String, dynamic>.from(_courierProfile!);
    final wasCourierApproved =
        CourierProfileFields.isApproved(previousCourierProfile);
    final wasCourierRejected =
        CourierProfileFields.isRejected(previousCourierProfile);
    final previousRejectionMessage =
        CourierProfileFields.rejectionMessage(previousCourierProfile);

    _darkMode = state['darkMode'] as bool? ?? _darkMode;
    _inAppAlertsEnabled = state['inAppAlertsEnabled'] as bool? ??
        state['notificationsEnabled'] as bool? ??
        _inAppAlertsEnabled;
    _driverType = state['driverType'] as String? ?? _driverType;
    final previousDriverProfile = _driverProfile == null
        ? null
        : Map<String, dynamic>.from(_driverProfile!);
    final wasDriverApproved =
        DriverProfileFields.isApproved(previousDriverProfile);
    final wasDriverRejected =
        DriverProfileFields.isRejected(previousDriverProfile);
    final previousDriverRejectionMessage =
        DriverProfileFields.rejectionMessage(previousDriverProfile);

    final driverProfile = state['driverProfile'];
    if (driverProfile is Map) {
      _driverProfile = Map<String, dynamic>.from(driverProfile);
      _notifyDriverApprovalTransition(
        wasApproved: wasDriverApproved,
        wasRejected: wasDriverRejected,
        previousRejectionMessage: previousDriverRejectionMessage,
      );
    }
    final courierProfile = state['courierProfile'];
    if (courierProfile is Map) {
      _courierProfile = Map<String, dynamic>.from(courierProfile);
      _notifyCourierApprovalTransition(
        wasApproved: wasCourierApproved,
        wasRejected: wasCourierRejected,
        previousRejectionMessage: previousRejectionMessage,
      );
    }
    _accountType = _trimmedOrNull(
          state['accountType']?.toString() ?? state['account_type']?.toString(),
        ) ??
        _accountType;
    _hasAdminAccess = state['adminAccess'] as bool? ?? _hasAdminAccess;
    _customerPhone =
        _trimmedOrNull(state['customerPhone']?.toString()) ?? _customerPhone;
    _customerLatitude =
        (state['customerLatitude'] as num?)?.toDouble() ?? _customerLatitude;
    _customerLongitude =
        (state['customerLongitude'] as num?)?.toDouble() ?? _customerLongitude;
    _userRole = _trimmedOrNull(state['userRole']?.toString()) ?? _userRole;
    _normalizeDriverProfileForRole();
    if (_customerName.trim().isEmpty) {
      _customerName =
          _trimmedOrNull(state['customerName']?.toString()) ?? _customerName;
    }
    _customerAvatarBase64 = _trimmedOrNull(
          state['customerAvatarBase64']?.toString() ??
              state['customerAvatarUrl']?.toString(),
        ) ??
        _customerAvatarBase64;
    _selectedCategory =
        state['selectedCategory'] as String? ?? _selectedCategory;
    _activeSubCategory =
        state['activeSubCategory'] as String? ?? _activeSubCategory;

    _applyNotificationsFromState(state['notifications']);

    final offers = state['merchantOffers'];
    if (offers is List) {
      _merchantOffers = offers
          .whereType<Map>()
          .map((item) => MerchantOffer.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    final reviews = state['merchantReviews'];
    if (reviews is List) {
      _merchantReviews = reviews
          .whereType<Map>()
          .map(
              (item) => MerchantReview.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    final items = state['items'];
    if (items is List && (_items.isEmpty || _userRole == 'merchant')) {
      _items = items
          .whereType<Map>()
          .map((item) => ListItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    final storedMerchant = state['merchantStore'];
    if (storedMerchant is Map &&
        (_merchantStore == null || merchantStoreName.isEmpty)) {
      _applyMerchantStoreSnapshot(Map<String, dynamic>.from(storedMerchant));
    }
    final statusQueue = state['pendingOrderStatusSyncQueue'];
    if (statusQueue is List) {
      _pendingOrderStatusSyncQueue = statusQueue
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
  }

  Future<void> _syncRemoteState() async {
    if (!SupabaseService.isConfigured) return;
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null || _isRestoring || _isSyncing || _isLoggingIn) return;

    _isSyncing = true;
    try {
      await _syncIdentityRecords();

      final canSyncRemoteState = _userRole != 'merchant' ||
          (_merchantStore != null &&
              (_merchantStore?['name']?.toString().trim().isNotEmpty ?? false));
      if (canSyncRemoteState) {
        await SupabaseService.saveUserState(phone, _buildRemoteState());
      } else {
        debugPrint(
          'SYNC_GUARD: Skipped empty merchant user-state sync to prevent data loss.',
        );
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
      unawaited(_persistLocalBackup());
    }
  }

  Future<void> _persistRemoteStateLight() async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null) return;
    try {
      await SupabaseService.saveUserState(phone, _buildRemoteState());
    } catch (error) {
      debugPrint('NOTIFICATION_STATE_SYNC: $error');
    }
  }

  Future<void> _restoreCatalogFromCache() async {
    try {
      final cached = await CatalogCache.readCatalog();
      if (cached != null && cached.isNotEmpty) {
        _catalogItems = cached.map(_listItemFromCatalogRow).toList();
        _applyFavoriteSelections();
        notifyListeners();
        debugPrint(
            'CACHE: Global catalog restored (${_catalogItems.length} items)');
      }
    } catch (e) {
      debugPrint('CACHE_RESTORE_ERROR: $e');
    }
  }

  Future<void> _restoreHomeCategoriesFromCache() async {
    final cached = await HomeCategoriesCache.read();
    if (cached == null || cached.isEmpty) return;
    _homeCategoryOverrides = cached;
  }

  Future<void> refreshHomeCategoriesConfig() async {
    if (!SupabaseService.isConfigured) return;
    final loadGeneration = _homeCategoriesSaveGeneration;
    try {
      final overrides = await SupabaseService.loadHomeCategoriesConfig();
      if (loadGeneration != _homeCategoriesSaveGeneration) return;
      _homeCategoryOverrides = overrides;
      await HomeCategoriesCache.write(overrides);
      notifyListeners();
    } catch (error) {
      debugPrint('HOME_CATEGORIES_CONFIG_ERROR: $error');
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    _darkMode = enabled;
    notifyListeners();
    await _syncRemoteState();
  }

  Future<void> toggleDarkMode() => setDarkMode(!_darkMode);

  Future<void> setInAppAlertsEnabled(bool enabled) async {
    _inAppAlertsEnabled = enabled;
    if (!enabled) {
      _pendingUnreadPromptRole = null;
    }
    notifyListeners();
    await _syncRemoteState();
  }
}
