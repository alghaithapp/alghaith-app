import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/repositories/account_repository.dart';
import '../../services/supabase_service.dart';
import '../../models/app_user_view.dart';
import 'core_mixin.dart';

mixin AuthMixin on AppCoreMixin {
  Future<void> setPhoneSession(String phone, {String? sessionToken}) async {
    final normalized = _normalizeStoredPhone(phone);
    if (normalized.isEmpty) return;

    final normalizedToken = _trimmedOrNull(sessionToken) ?? _sessionToken;
    _sessionToken = normalizedToken;
    SupabaseService.setSessionToken(normalizedToken);
    _authPhone = normalized;
    _customerPhone = normalized;
    _isGuestMode = false;
    if (_isPlatformAdminPhone(normalized)) {
      _hasAdminAccess = true;
    }

    _isLoggingIn = true;
    notifyListeners();

    try {
      await AccountRepository.instance.persistSession(
        phone: normalized,
        token: normalizedToken,
      );

      debugPrint('==== LOGIN: local-first restore for $normalized ====');
      await _restoreLocalBackup(normalized);
      _resolveRoleAfterAuth();
      _hydrateCustomerIdentityFromRestoredData();

      if (_userRole == null) {
        debugPrint('LOGIN: no role yet, defaulting after auth resolve.');
      } else {
        debugPrint('LOGIN: ready with role $_userRole (local-first).');
      }
    } catch (error) {
      debugPrint('LOGIN_ERROR: $error');
      _resolveRoleAfterAuth();
      _hydrateCustomerIdentityFromRestoredData();
    } finally {
      _isLoggingIn = false;
      _isRestoring = false;
      _isHydrating = false;
      _isReady = true;
      notifyListeners();
      _notificationHub.onLoginSuccess();
      _notificationHub.onAppBootWelcome(_customerName);
      unawaited(_completeLoginRemoteRestore(normalized));
      unawaited(PushNotificationService.instance.bindToUser(normalized));
    }
  }

  Future<void> _completeLoginRemoteRestore(String phone) async {
    try {
      await _restoreRemoteSessionWithRetry(
        phone,
        attempts: 2,
        deferPostRefresh: true,
      ).timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          debugPrint('LOGIN_REMOTE_RESTORE_TIMEOUT for $phone');
        },
      );
      if (!hasPhoneSession) return;
      _resolveRoleAfterAuth();
      _hydrateCustomerIdentityFromRestoredData();
      notifyListeners();
      await _enrichRemoteSessionInBackground(phone);
    } catch (error) {
      debugPrint('LOGIN_REMOTE_RESTORE_ERROR: $error');
    }
  }

  void _resolveRoleAfterAuth() {
    if (!hasPhoneSession) return;
    _hydrateCustomerIdentityFromRestoredData();
    _inferAccountTypeFromLegacyData();
    _inferRoleFromRestoredData();
    _applyAccountTypeConstraints();
    if (_userRole == null || _userRole!.trim().isEmpty) {
      _userRole = _defaultRoleForAccountType(_accountType) ?? 'customer';
    }
    _accountType ??= _accountTypeForRole(_userRole!);
    _accountType ??= 'marketplace';
    if (_userRole == 'admin') {
      unawaited(
          PushNotificationService.instance.subscribeToTopic('admin_alerts'));
    }
    _isGuestMode = false;
  }

  String? _accountTypeForRole(String role) {
    switch (role) {
      case 'customer':
      case 'merchant':
        return 'marketplace';
      case 'delivery':
        return 'delivery';
      case 'driver':
        return 'driver';
      default:
        return null;
    }
  }

  bool isRoleAllowedForAccount(String role) {
    if (role == 'admin') return _hasAdminAccess;
    final locked = _trimmedOrNull(_accountType);
    if (locked == null) {
      return role == 'customer' ||
          role == 'merchant' ||
          role == 'delivery' ||
          role == 'driver' ||
          (role == 'admin' && _hasAdminAccess);
    }
    switch (locked) {
      case 'marketplace':
      case 'delivery':
        return role == 'customer' || role == 'merchant' || role == 'delivery' || role == 'driver';
      case 'driver':
        return role == 'driver';
      default:
        return false;
    }
  }

  String? _defaultRoleForAccountType(String? accountType) {
    switch (accountType) {
      case 'marketplace':
        return _primaryAccountRole() ?? 'customer';
      case 'delivery':
        return 'delivery';
      case 'driver':
        return 'driver';
      default:
        return null;
    }
  }

  void _inferAccountTypeFromLegacyData() {
    if (_accountType != null) return;

    final fromUser = appUserView.accountType;
    if (fromUser != null) {
      _accountType = fromUser;
      return;
    }

    final storedRole = appUserView.role;
    if (storedRole == 'delivery') {
      _accountType = 'delivery';
      return;
    }
    if (storedRole == 'driver') {
      _accountType = 'driver';
      return;
    }
    if (storedRole == 'customer' || storedRole == 'merchant') {
      _accountType = 'marketplace';
      return;
    }

    final hasMerchant =
        _merchantStore != null && merchantStoreName.trim().isNotEmpty;
    if (hasMerchant || hasCompletedCustomerProfile) {
      _accountType = 'marketplace';
      return;
    }
    if (hasCourierProfile) {
      _accountType = 'delivery';
      return;
    }
    if (_driverProfile != null && _driverProfile!.isNotEmpty) {
      _accountType = 'driver';
    }
  }

  void _applyAccountTypeConstraints() {
    if (_accountType == null) return;

    final allowedRole = _defaultRoleForAccountType(_accountType);
    if (allowedRole == null) return;

    if (!isRoleAllowedForAccount(_userRole ?? '')) {
      _userRole = allowedRole;
      return;
    }

    if (_userRole == null) {
      _userRole = allowedRole;
    }
  }

  String? _primaryAccountRole() {
    final hasMerchant =
        _merchantStore != null && merchantStoreName.trim().isNotEmpty;
    if (hasMerchant) return 'merchant';
    if (hasCompletedCustomerProfile) return 'customer';
    return null;
  }

  void _inferRoleFromRestoredData() {
    if (_userRole != null && _userRole!.trim().isNotEmpty) {
      if (_userRole == 'admin') {
        _userRole = 'customer';
        _hasAdminAccess = true;
      }
      return;
    }

    final storedRole = appUserView.role;
    if (storedRole == 'admin') {
      _userRole = 'customer';
      _hasAdminAccess = true;
      return;
    }

    if (storedRole != null && isRoleAllowedForAccount(storedRole)) {
      _userRole = storedRole;
      return;
    }

    if (_merchantStore != null &&
        (_merchantStore?['name']?.toString().trim().isNotEmpty ?? false)) {
      _userRole = 'merchant';
      return;
    }

    if (_customerName.trim().isNotEmpty) {
      _userRole = 'customer';
      return;
    }

    if (_accountType == 'delivery' || hasCourierProfile) {
      _userRole = 'delivery';
      return;
    }

    if (_accountType == 'driver' &&
        _driverProfile != null &&
        _driverProfile!.isNotEmpty) {
      _userRole = 'driver';
    }
  }

  String? _roleForAppUserSync() {
    final current = _trimmedOrNull(_userRole);
    if (current != null && isRoleAllowedForAccount(current)) {
      return current;
    }
    return _defaultRoleForAccountType(_accountType) ?? _primaryAccountRole();
  }

  Future<void> _persistAccountTypeIfNeeded() async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    final type = _trimmedOrNull(_accountType);
    if (phone == null || type == null) return;
    await SupabaseService.saveAppUser(phone, accountType: type);
  }

  Map<String, dynamic> _customerProfilePayload() {
    final payload = <String, dynamic>{};
    final displayName = _trimmedOrNull(_customerName);
    final address = _trimmedOrNull(_customerAddress);

    if (displayName != null) {
      payload['display_name'] = displayName;
      payload['full_name'] = displayName;
    }
    if (_customerAvatarBase64 != null) {
      payload['avatar_base64'] = _customerAvatarBase64;
    }
    if (address != null) {
      payload['address'] = address;
    }
    return payload;
  }

  Future<void> _syncIdentityRecords() async {
    if (!SupabaseService.isConfigured) return;
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null || _isRestoring) return;

    final nameToSave = _trimmedOrNull(_customerName);
    final roleToSave = _roleForAppUserSync();

    if (nameToSave == null &&
        roleToSave == null &&
        _customerAvatarBase64 == null) {
      debugPrint('Sync skipped: Attempting to save empty identity');
      return;
    }

    await SupabaseService.saveAppUser(
      phone,
      fullName: nameToSave,
      role: roleToSave,
      accountType: _accountType,
      avatarBase64: _customerAvatarBase64,
    );

    final customerPayload = _customerProfilePayload();
    if (customerPayload.isNotEmpty) {
      await SupabaseService.saveCustomerProfile(phone, customerPayload);
    }
  }

  Future<bool> setUserRole(String role) async {
    if (role == 'admin') {
      if (!_hasAdminAccess) return false;
      final previousRole = _userRole;
      _userRole = role;
      if (previousRole != null && previousRole != role) {
        _notificationHub.onRoleSwitched(role, _roleLabelAr(role));
        final unreadCount = unreadNotificationsForRole(role).length;
        if (unreadCount > 0) {
          _queueUnreadPromptForRole(role);
        }
      }
      notifyListeners();
      unawaited(_persistLocalBackup());
      unawaited(
          _runRoleSwitchSideEffects(role: role, previousRole: previousRole));
      return true;
    }

    if (!isRoleAllowedForAccount(role)) {
      debugPrint(
        'ROLE_LOCK: role "$role" blocked for account type "$_accountType"',
      );
      return false;
    }

    if (_accountType == null) {
      final lockedType = _accountTypeForRole(role);
      if (lockedType == null) return false;
      _accountType = lockedType;
    }

    final previousRole = _userRole;

    _userRole = role;
    if (role == 'driver') {
      _normalizeDriverProfileForRole();
    }

    if (previousRole != null && previousRole != role) {
      _notificationHub.onRoleSwitched(role, _roleLabelAr(role));
      final unreadCount = unreadNotificationsForRole(role).length;
      if (unreadCount > 0) {
        _queueUnreadPromptForRole(role);
      }
    }

    notifyListeners();
    unawaited(_persistLocalBackup());

    unawaited(
        _runRoleSwitchSideEffects(role: role, previousRole: previousRole));
    return true;
  }

  Future<void> _runRoleSwitchSideEffects({
    required String role,
    required String? previousRole,
  }) async {
    try {
      if (role == 'admin') {
        unawaited(
            PushNotificationService.instance.subscribeToTopic('admin_alerts'));
      } else if (previousRole == 'admin') {
        unawaited(PushNotificationService.instance
            .unsubscribeFromTopic('admin_alerts'));
      }

      if (previousRole == 'merchant' && role != 'merchant') {
        try {
          await _syncMerchantDataBeforeLeavingMerchantMode();
        } catch (error) {
          debugPrint('MERCHANT_SYNC_BEFORE_ROLE_SWITCH: $error');
        }
      }

      await _syncIdentityRecords();
      await _persistAccountTypeIfNeeded();
      final phone =
          _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
      if (phone != null) {
        await SupabaseService.saveUserState(phone, _buildRemoteState());
      }
      await _persistLocalBackup();

      if (role == 'admin') {
        await refreshAdminReports();
      } else if (role == 'customer') {
        await refreshCustomerCatalog();
        await refreshCustomerOrders();
      } else if (role == 'merchant') {
        try {
          await _ensureMerchantProfileSynced();
          if (_items.isNotEmpty) {
            await _persistMerchantItems();
          }
        } catch (error) {
          debugPrint('MERCHANT_SYNC_ON_ENTER: $error');
        }
        await _refreshMerchantIncomingOrders();
      } else if (role == 'delivery') {
        await refreshCourierOrders();
      } else if (role == 'driver') {
        await refreshTaxiRequests();
        try {
          await refreshCourierOrders();
        } catch (error) {
          debugPrint('DRIVER_DELIVERY_REFRESH: $error');
        }
      } else if (role == 'customer') {
        await refreshTaxiRequests();
      }

      notifyListeners();
    } catch (error) {
      debugPrint('ROLE_SWITCH_BACKGROUND: $error');
    }
  }

  Future<void> activateMerchantRole() async {
    if (_accountType == 'driver') return;
    if (_accountType == null) _accountType = 'marketplace';
    _userRole = 'merchant';
    notifyListeners();
    await _syncIdentityRecords();
    await _persistAccountTypeIfNeeded();
    if (_merchantStore != null && merchantStoreName.isNotEmpty) {
      await _persistMerchantStoreAndState();
      if (_items.isNotEmpty) {
        await _persistMerchantItems();
      }
    } else {
      final phone =
          _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
      if (phone != null) {
        await SupabaseService.saveUserState(phone, _buildRemoteState());
      }
      await _persistLocalBackup();
    }
    await _refreshMerchantIncomingOrders();
  }

  static String _roleLabelAr(String role) {
    switch (role) {
      case 'merchant':
        return 'التاجر';
      case 'customer':
        return 'الزبون';
      case 'delivery':
        return 'مندوب التوصيل';
      case 'driver':
        return 'سائق التكسي';
      case 'admin':
        return 'الإدارة';
      default:
        return role;
    }
  }

  Future<void> deleteAccountPermanently() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null || phone.isEmpty) {
      throw Exception('لا يوجد حساب مسجل حالياً.');
    }
    await PushNotificationService.instance.unbindFromUser(phone: phone);
    await SupabaseService.deleteAccount(phone);
    resetAll();
  }

  void resetAll() {
    _isRestoring = false;
    _isLoggingIn = false;
    _isHydrating = false;
    _isGuestMode = false;
    final previousPhone = _authPhone;

    _authPhone = null;
    _sessionToken = null;
    _userRole = null;
    _accountType = null;
    _hasAdminAccess = false;
    _merchantStore = null;
    _appUserRecord = null;
    _driverType = null;
    _driverProfile = null;
    _courierProfile = null;
    _cart = [];
    _items = [];
    _catalogItems = [];
    _orders = [];
    _merchantIncomingOrders = [];
    _courierPoolOrders = [];
    _courierAssignedOrders = [];
    _adminReports = null;
    _taxiRequests = [];
    _taxiPoolRequests = [];
    _taxiDriverAssignedRequests = [];
    _addresses = [];
    _notifications.clear();
    _customerName = '';
    _customerPhone = '';
    _customerAddress = '';
    _customerLatitude = null;
    _customerLongitude = null;
    _customerAvatarBase64 = null;
    _favoriteItemIds.clear();

    unawaited(
        PushNotificationService.instance.unbindFromUser(phone: previousPhone));
    unawaited(
      AccountRepository.instance.clearSession(phone: previousPhone).then((_) {
        debugPrint('LOGOUT: Local session cleared.');
      }),
    );
    SupabaseService.setSessionToken(null);

    _isReady = true;
    _isLoggingIn = false;
    notifyListeners();
  }
}
