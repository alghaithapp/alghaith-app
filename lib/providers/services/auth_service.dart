import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/notifications/notification_hub.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/account_snapshot.dart';
import '../../data/repositories/account_repository.dart';
import '../../services/supabase_service.dart';
import '../../models/app_user_view.dart';
import '../../models/app_models.dart';
import '../../models/app_notification.dart';
import '../../models/merchant_models.dart';

class AuthService extends ChangeNotifier {
  // ── Auth state ─────────────────────────────────────────────────
  String? _authPhone;
  String? _customerPhone;
  String? _sessionToken;
  bool _isGuestMode = true;
  bool _hasAdminAccess = false;
  bool _isLoggingIn = false;
  bool _isRestoring = false;
  bool _isHydrating = false;
  bool _isReady = true;
  String? _userRole;
  String? _accountType;
  Map<String, dynamic>? _appUserRecord;

  // ── Cross-domain state (set by AppProvider) ────────────────────
  String _customerName = '';
  String _customerAddress = '';
  double? _customerLatitude;
  double? _customerLongitude;
  String? _customerAvatarBase64;
  Map<String, dynamic>? _merchantStore;
  Map<String, dynamic>? _driverProfile;
  Map<String, dynamic>? _courierProfile;
  List<ListItem> _items = [];
  List<AppNotificationItem> _notifications = [];

  late final NotificationHub _notificationHub =
      NotificationHub(_emitNotification);

  // ── Cross-domain setters (called by AppProvider) ──────────────
  void updateCustomerName(String value) => _customerName = value;
  void updateCustomerAddress(String value) => _customerAddress = value;
  void updateCustomerLatitude(double? value) => _customerLatitude = value;
  void updateCustomerLongitude(double? value) => _customerLongitude = value;
  void updateCustomerAvatarBase64(String? value) =>
      _customerAvatarBase64 = value;
  void updateMerchantStore(Map<String, dynamic>? store) =>
      _merchantStore = store;
  void updateDriverProfile(Map<String, dynamic>? profile) =>
      _driverProfile = profile;
  void updateCourierProfile(Map<String, dynamic>? profile) =>
      _courierProfile = profile;
  void updateItems(List<ListItem> items) => _items = items;
  void updateCustomerPhone(String phone) => _customerPhone = phone;

  // ── Getters ────────────────────────────────────────────────────
  String? get authPhone => _authPhone;
  String? get customerPhone => _customerPhone;
  String? get sessionToken => _sessionToken;
  bool get isGuestMode => _isGuestMode;
  bool get hasAdminAccess => _hasAdminAccess;
  bool get isLoggingIn => _isLoggingIn;
  bool get isRestoring => _isRestoring;
  bool get isHydrating => _isHydrating;
  bool get isReady => _isReady;
  String? get userRole => _userRole;
  String? get accountType => _accountType;
  Map<String, dynamic>? get appUserRecord => _appUserRecord;
  bool get hasPhoneSession =>
      _authPhone != null && _authPhone!.trim().isNotEmpty;
  bool get isAdmin => _userRole == 'admin';
  bool get isMerchant => _userRole == 'merchant';
  bool get isDelivery => _userRole == 'delivery';
  bool get isDriver => _userRole == 'driver';
  bool get isCustomer => _userRole == 'customer';
  bool get hasSelectedRole => _userRole?.trim().isNotEmpty == true;
  bool get hasLockedAccountType =>
      _accountType?.trim().isNotEmpty == true;
  bool get isMarketplaceAccount => _accountType == 'marketplace';
  bool get isDeliveryAccount => _accountType == 'delivery';
  bool get isDriverAccount => _accountType == 'driver';
  AppUserView get appUserView => AppUserView(_appUserRecord);
  String get customerName => _customerName;

  String get _effectiveCustomerPhone {
    final cp = (_customerPhone ?? '').trim();
    if (cp.isNotEmpty) return cp;
    return _authPhone?.trim() ?? '';
  }

  bool get hasCompletedCustomerProfile {
    if (_effectiveCustomerPhone.isEmpty) return false;
    if (_customerName.trim().isNotEmpty) return true;
    if (_merchantStore != null && merchantStoreName.isNotEmpty) return true;
    if (appUserView.fullName != null) return true;
    if (appUserView.email != null) return true;
    return false;
  }

  String get merchantStoreName =>
      (_merchantStore?['name'] as String?)?.trim() ?? '';
  bool get hasCompletedMerchantProfile =>
      _merchantStore != null && merchantStoreName.isNotEmpty;

  bool get hasCourierProfile => _courierProfile != null &&
      (_courierProfile?['name']?.toString().trim().isNotEmpty ?? false);

  bool get hasDriverProfile => _driverProfile != null &&
      (_driverProfile?['name']?.toString().trim().isNotEmpty ?? false);

  // ── Auth methods ────────────────────────────────────────────────

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
      _isHydrating = false;

      _notificationHub.onLoginSuccess();
      _notificationHub.onAppBootWelcome(_customerName);

      // إظهار شاشة التحميل قبل تحميل البيانات من السيرفر
      _isRestoring = true;
      _isReady = false;
      notifyListeners();

      await _completeLoginRemoteRestore(normalized);

      _isRestoring = false;
      _isReady = true;
      notifyListeners();

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
        return role == 'customer' ||
            role == 'merchant' ||
            role == 'delivery' ||
            role == 'driver';
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

    final hasMerchant = _merchantStore != null && merchantStoreName.trim().isNotEmpty;
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
    final hasMerchant = _merchantStore != null && merchantStoreName.trim().isNotEmpty;
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
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
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
        final adminRefresh = _onAdminReportsRefresh;
        if (adminRefresh != null) await adminRefresh();
      } else if (role == 'customer') {
        if (_onRefreshCustomerCatalog != null) {
          await _onRefreshCustomerCatalog!();
        }
        if (_onRefreshCustomerOrders != null) {
          await _onRefreshCustomerOrders!();
        }
      } else if (role == 'merchant') {
        try {
          if (_onEnsureMerchantProfileSynced != null) {
            await _onEnsureMerchantProfileSynced!();
          }
          if (_items.isNotEmpty && _onPersistMerchantItems != null) {
            await _onPersistMerchantItems!();
          }
        } catch (error) {
          debugPrint('MERCHANT_SYNC_ON_ENTER: $error');
        }
        if (_onRefreshMerchantIncomingOrders != null) {
          await _onRefreshMerchantIncomingOrders!();
        }
      } else if (role == 'delivery') {
        if (_onRefreshCourierOrders != null) {
          await _onRefreshCourierOrders!();
        }
      } else if (role == 'driver') {
        if (_onRefreshTaxiRequests != null) {
          await _onRefreshTaxiRequests!();
        }
        try {
          if (_onRefreshCourierOrders != null) {
            await _onRefreshCourierOrders!();
          }
        } catch (error) {
          debugPrint('DRIVER_DELIVERY_REFRESH: $error');
        }
      }

      notifyListeners();
    } catch (error) {
      debugPrint('ROLE_SWITCH_BACKGROUND: $error');
    }
  }

  // ── Role-switch callbacks (set by AppProvider) ──────────────────
  Future<void> Function()? _onRefreshCustomerCatalog;
  Future<void> Function()? _onRefreshCustomerOrders;
  Future<void> Function()? _onEnsureMerchantProfileSynced;
  Future<void> Function()? _onPersistMerchantItems;
  Future<void> Function()? _onRefreshMerchantIncomingOrders;
  Future<void> Function()? _onRefreshCourierOrders;
  Future<void> Function()? _onRefreshTaxiRequests;
  Future<void> Function()? _onAdminReportsRefresh;

  void setOnRefreshCustomerCatalog(Future<void> Function() cb) =>
      _onRefreshCustomerCatalog = cb;
  void setOnRefreshCustomerOrders(Future<void> Function() cb) =>
      _onRefreshCustomerOrders = cb;
  void setOnEnsureMerchantProfileSynced(Future<void> Function() cb) =>
      _onEnsureMerchantProfileSynced = cb;
  void setOnPersistMerchantItems(Future<void> Function() cb) =>
      _onPersistMerchantItems = cb;
  void setOnRefreshMerchantIncomingOrders(Future<void> Function() cb) =>
      _onRefreshMerchantIncomingOrders = cb;
  void setOnRefreshCourierOrders(Future<void> Function() cb) =>
      _onRefreshCourierOrders = cb;
  void setOnRefreshTaxiRequests(Future<void> Function() cb) =>
      _onRefreshTaxiRequests = cb;
  void setOnAdminReportsRefresh(Future<void> Function() cb) =>
      _onAdminReportsRefresh = cb;

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
        if (_onPersistMerchantItems != null) {
          await _onPersistMerchantItems!();
        }
      }
    } else {
      final phone =
          _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
      if (phone != null) {
        await SupabaseService.saveUserState(phone, _buildRemoteState());
      }
      await _persistLocalBackup();
    }
    if (_onRefreshMerchantIncomingOrders != null) {
      await _onRefreshMerchantIncomingOrders!();
    }
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
    unawaited(AccountRepository.instance.clearSnapshot(phone));
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

  // ── Remote restore ─────────────────────────────────────────────
  Future<void> _restoreLocalBackup(String phone) async {
    try {
      final snapshot =
          await AccountRepository.instance.readLocalSnapshot(phone);
      if (snapshot == null) return;

      _userRole = snapshot.userRole ?? _userRole;
      _hasAdminAccess = snapshot.hasAdminAccess;
      _accountType = snapshot.accountType ?? _accountType;
      _customerName = snapshot.customerName.isNotEmpty
          ? snapshot.customerName
          : _customerName;
      _customerPhone = snapshot.customerPhone.isNotEmpty
          ? snapshot.customerPhone
          : _customerPhone;
      _customerAddress = snapshot.customerAddress.isNotEmpty
          ? snapshot.customerAddress
          : _customerAddress;

      _customerLatitude =
          snapshot.customerLatitude ?? _customerLatitude;
      _customerLongitude =
          snapshot.customerLongitude ?? _customerLongitude;
      _customerAvatarBase64 =
          snapshot.customerAvatarRef ?? _customerAvatarBase64;

      // استعادة البيانات الموسعة عبر callbacks
      if (snapshot.merchantStore != null && _onApplyMerchantStore != null) {
        _onApplyMerchantStore!(snapshot.merchantStore!);
      }
      if (snapshot.driverProfile != null && _onApplyDriverProfile != null) {
        _onApplyDriverProfile!(snapshot.driverProfile!);
      }
      if (snapshot.courierProfile != null && _onApplyCourierProfile != null) {
        _onApplyCourierProfile!(snapshot.courierProfile!);
      }
      if (snapshot.items.isNotEmpty && _onApplyLocalBackupItems != null) {
        _onApplyLocalBackupItems!(snapshot.items);
      }
      if (snapshot.orders.isNotEmpty && _onApplyLocalBackupOrders != null) {
        _onApplyLocalBackupOrders!(snapshot.orders);
      }
      if (snapshot.merchantOffers.isNotEmpty && _onApplyLocalBackupOffers != null) {
        _onApplyLocalBackupOffers!(snapshot.merchantOffers);
      }

      return;
    } catch (error) {
      debugPrint('LOCAL_BACKUP_RESTORE_ERROR: $error');
    }
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

  bool _hasMeaningfulRemoteIdentity() {
    return _appUserRecord != null ||
        hasCompletedMerchantProfile ||
        hasCompletedCustomerProfile;
  }

  Future<void> _restoreRemoteSession(
    String phone, {
    bool deferPostRefresh = false,
    bool persistAfterRestore = true,
  }) async {
    final normalizedPhone = _normalizeStoredPhone(phone);
    if (normalizedPhone.isEmpty) return;
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
        _customerLatitude =
            (customerProfile['latitude'] as num?)?.toDouble() ??
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
        final hasLocalStore =
            _merchantStore != null && merchantStoreName.isNotEmpty;
        final remoteStoreName =
            (merchantProfile['store_name'] as String?)?.trim() ?? '';
        if (!hasLocalStore || remoteStoreName.isNotEmpty) {
          if (_onApplyMerchantSnapshot != null) {
            _onApplyMerchantSnapshot!(merchantProfile);
          }
          if (_userRole == null) {
            _userRole = 'merchant';
          }
        }
      }

      if (userState != null) {
        if (_onApplyRemoteState != null) {
          _onApplyRemoteState!(userState);
        }
      }

      // استهلاك حزمة البيانات الإضافية من السيرفر
      if (bundle.orders.isNotEmpty && _onApplyRemoteOrders != null) {
        _onApplyRemoteOrders!(bundle.orders);
      }
      if (bundle.addresses.isNotEmpty && _onApplyRemoteAddresses != null) {
        _onApplyRemoteAddresses!(bundle.addresses);
      }
      if (bundle.products.isNotEmpty && _onApplyRemoteProducts != null) {
        _onApplyRemoteProducts!(bundle.products);
      }

      _inferAccountTypeFromLegacyData();
      _inferRoleFromRestoredData();
      _applyAccountTypeConstraints();
      _hydrateCustomerIdentityFromRestoredData();

      notifyListeners();

      if (!deferPostRefresh) {
        await _enrichRemoteSessionInBackground(phone);
      }

      if (persistAfterRestore) {
        await _persistLocalBackup();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('RESTORE_ERROR: $e');
    }
  }

  // ── Callbacks for persistence cross-domain operations ──────────
  void Function(Map<String, dynamic> snapshot)? _onApplyMerchantSnapshot;
  void Function(Map<String, dynamic> state)? _onApplyRemoteState;
  Future<void> Function()? _onPersistMerchantStoreAndState;
  Future<void> Function()? _onSyncMerchantDataBeforeLeavingMerchantMode;

  void setOnApplyMerchantSnapshot(
          void Function(Map<String, dynamic> snapshot) cb) =>
      _onApplyMerchantSnapshot = cb;
  void setOnApplyRemoteState(
          void Function(Map<String, dynamic> state) cb) =>
      _onApplyRemoteState = cb;
  void setOnPersistMerchantStoreAndState(
          Future<void> Function() cb) =>
      _onPersistMerchantStoreAndState = cb;
  void setOnSyncMerchantDataBeforeLeavingMerchantMode(
          Future<void> Function() cb) =>
      _onSyncMerchantDataBeforeLeavingMerchantMode = cb;

  Future<void> _persistMerchantStoreAndState() async {
    if (_onPersistMerchantStoreAndState != null) {
      await _onPersistMerchantStoreAndState!();
    }
  }

  Future<void> _syncMerchantDataBeforeLeavingMerchantMode() async {
    if (_onSyncMerchantDataBeforeLeavingMerchantMode != null) {
      await _onSyncMerchantDataBeforeLeavingMerchantMode!();
    }
  }

  void _hydrateCustomerIdentityFromRestoredData() {
    if ((_customerPhone ?? '').trim().isEmpty && _authPhone != null) {
      _customerPhone = _authPhone!;
    }
    if (_customerName.trim().isNotEmpty) return;

    _customerName = appUserView.fullName ??
        appUserView.email ??
        (hasCompletedMerchantProfile ? merchantStoreName : null) ??
        _customerName;
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
        if (_onRefreshCustomerCatalog != null) {
          await _onRefreshCustomerCatalog!();
        }
        if (_onRefreshCustomerOrders != null) {
          await _onRefreshCustomerOrders!();
        }
      }
      if (isMerchant && _onRefreshMerchantIncomingOrders != null) {
        await _onRefreshMerchantIncomingOrders!();
      }
      if (isDelivery && _onRefreshCourierOrders != null) {
        await _onRefreshCourierOrders!();
      }
      if ((isDriver || isCustomer) && _onRefreshTaxiRequests != null) {
        await _onRefreshTaxiRequests!();
      }
      await _persistLocalBackup();
      notifyListeners();
    } catch (error) {
      debugPrint('ENRICH_SESSION_ERROR: $error');
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

  AccountSnapshot _buildLocalBackupSnapshot() {
    Map<String, dynamic>? merchantStore;
    Map<String, dynamic>? driverProfile;
    Map<String, dynamic>? courierProfile;
    List<ListItem> items = const [];
    List<ActiveOrder> orders = const [];
    List<MerchantOffer> merchantOffers = const [];

    if (_onCollectLocalBackupData != null) {
      final extra = _onCollectLocalBackupData!();
      merchantStore = extra['merchantStore'] as Map<String, dynamic>?;
      driverProfile = extra['driverProfile'] as Map<String, dynamic>?;
      courierProfile = extra['courierProfile'] as Map<String, dynamic>?;
      if (extra['items'] is List) items = extra['items'] as List<ListItem>;
      if (extra['orders'] is List) orders = extra['orders'] as List<ActiveOrder>;
      if (extra['merchantOffers'] is List) merchantOffers = extra['merchantOffers'] as List<MerchantOffer>;
    }

    return AccountSnapshot(
      userRole: _userRole,
      hasAdminAccess: _hasAdminAccess,
      accountType: _accountType,
      customerName: _customerName,
      customerPhone: _customerPhone ?? '',
      customerAddress: _customerAddress,
      customerLatitude: _customerLatitude,
      customerLongitude: _customerLongitude,
      customerAvatarRef: _customerAvatarBase64,
      merchantStore: merchantStore ?? _buildMerchantStoreFallback(),
      driverProfile: driverProfile,
      courierProfile: courierProfile,
      items: items,
      orders: orders,
      merchantOffers: merchantOffers,
    );
  }

  Map<String, dynamic>? _buildMerchantStoreFallback() {
    if (_merchantStore != null) return _merchantStore;
    return null;
  }

  /// إشارة لجمع بيانات النسخ الاحتياطي من جميع الخدمات
  Map<String, dynamic> Function()? _onCollectLocalBackupData;
  void setOnCollectLocalBackupData(Map<String, dynamic> Function() cb) =>
      _onCollectLocalBackupData = cb;

  // Callbacks لاستعادة البيانات من النسخة المحلية
  void Function(Map<String, dynamic>)? _onApplyMerchantStore;
  void Function(Map<String, dynamic>)? _onApplyDriverProfile;
  void Function(Map<String, dynamic>)? _onApplyCourierProfile;
  void Function(List<ListItem>)? _onApplyLocalBackupItems;
  void Function(List<ActiveOrder>)? _onApplyLocalBackupOrders;
  void Function(List<MerchantOffer>)? _onApplyLocalBackupOffers;

  void setOnApplyMerchantStore(void Function(Map<String, dynamic>) cb) =>
      _onApplyMerchantStore = cb;
  void setOnApplyDriverProfile(void Function(Map<String, dynamic>) cb) =>
      _onApplyDriverProfile = cb;
  void setOnApplyCourierProfile(void Function(Map<String, dynamic>) cb) =>
      _onApplyCourierProfile = cb;
  void setOnApplyLocalBackupItems(void Function(List<ListItem>) cb) =>
      _onApplyLocalBackupItems = cb;
  void setOnApplyLocalBackupOrders(void Function(List<ActiveOrder>) cb) =>
      _onApplyLocalBackupOrders = cb;
  void setOnApplyLocalBackupOffers(void Function(List<MerchantOffer>) cb) =>
      _onApplyLocalBackupOffers = cb;

  // Callbacks لاستقبال بيانات الحزمة البعيدة
  void Function(List<ActiveOrder>)? _onApplyRemoteOrders;
  void Function(List<String>)? _onApplyRemoteAddresses;
  void setOnApplyRemoteOrders(void Function(List<ActiveOrder>) cb) =>
      _onApplyRemoteOrders = cb;
  void setOnApplyRemoteAddresses(void Function(List<String>) cb) =>
      _onApplyRemoteAddresses = cb;

  void Function(List<Map<String, dynamic>>)? _onApplyRemoteProducts;
  void setOnApplyRemoteProducts(void Function(List<Map<String, dynamic>>) cb) =>
      _onApplyRemoteProducts = cb;

  Map<String, dynamic> _buildRemoteState() {
    return {
      'adminAccess': _hasAdminAccess,
      'accountType': _accountType,
      'customerPhone': _customerPhone,
      'customerLatitude': _customerLatitude,
      'customerLongitude': _customerLongitude,
      'userRole': _userRole,
      'customerName': _customerName,
      'customerAvatarBase64': _customerAvatarBase64,
      'customerAvatarUrl': _customerAvatarBase64,
      'profileComplete': hasCompletedCustomerProfile,
    };
  }

  void _normalizeDriverProfileForRole() {
    if (_userRole != 'driver' || _driverProfile == null) return;
    final currentServices = _driverProfile?['services'];
    final deliveryEnabled =
        currentServices is Map && currentServices['delivery'] == true;
    _driverProfile = {
      ..._driverProfile!,
      'type': 'taxi',
      'services': {'taxi': true, 'delivery': deliveryEnabled},
    };
  }

  // ── Notification helpers ──────────────────────────────────────
  String _emitNotification({
    required String title,
    required String body,
    required String audience,
    String? orderNumber,
    NotificationCategory category = NotificationCategory.system,
    NotificationPriority priority = NotificationPriority.normal,
    String? eventKey,
  }) {
    return _addNotification(
      title,
      body,
      audience: audience,
      orderNumber: orderNumber,
      category: category,
      priority: priority,
      eventKey: eventKey,
    );
  }

  String _addNotification(
    String title,
    String body, {
    required String audience,
    String? orderNumber,
    NotificationCategory category = NotificationCategory.system,
    NotificationPriority priority = NotificationPriority.normal,
    String? eventKey,
  }) {
    if (eventKey != null) {
      final byKey = _notifications.indexWhere(
        (n) => n.eventKey == eventKey && n.audience == audience,
      );
      if (byKey >= 0) return _notifications[byKey].id;
    }
    final existing = _notifications.indexWhere(
      (n) =>
          n.audience == audience &&
          n.title == title &&
          n.body == body &&
          (orderNumber == null || n.orderNumber == orderNumber),
    );
    if (existing >= 0) return _notifications[existing].id;

    final item = AppNotificationItem(
      id: _generateUuid(),
      title: title,
      body: body,
      audience: audience,
      read: false,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      orderNumber: orderNumber,
      category: category,
      priority: priority,
      eventKey: eventKey,
    );
    _notifications.insert(0, item);
    if (_notifications.length > 200) {
      _notifications.removeRange(200, _notifications.length);
    }
    notifyListeners();
    return item.id;
  }

  List<AppNotificationItem> unreadNotificationsForRole(String role) {
    return _notifications
        .where((n) => n.audience == role && !n.read)
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  void _queueUnreadPromptForRole(String role) {
    if (unreadNotificationsForRole(role).isEmpty) return;
  }

  // ── Utility methods ─────────────────────────────────────────────
  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _normalizeStoredPhone(String phone) => PhoneUtils.normalize(phone);

  static const Set<String> _platformAdminPhoneCores = {'7744009992'};

  bool _isPlatformAdminPhone(String? phone) {
    final digits = PhoneUtils.digitsOnly(phone ?? '');
    if (digits.isEmpty) return false;
    final core =
        digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
    return _platformAdminPhoneCores.contains(core);
  }

  static String _generateUuid() {
    final rng = math.Random.secure();
    const hex = '0123456789abcdef';
    String seg(int len) =>
        List.generate(len, (_) => hex[rng.nextInt(16)]).join();
    return '${seg(8)}-${seg(4)}-4${seg(3)}-${hex[8 + rng.nextInt(4)]}${seg(3)}-${seg(12)}';
  }
}
