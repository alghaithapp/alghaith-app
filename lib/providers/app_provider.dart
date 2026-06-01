import 'dart:async';

import 'dart:io';
import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../core/utils/phone_utils.dart';
import '../data/models/account_snapshot.dart';
import '../data/repositories/account_repository.dart';
import '../models/app_models.dart';
import '../models/merchant_models.dart';
import '../services/supabase_service.dart';
import '../services/image_storage_service.dart';
import '../utils/merchant_service_labels.dart';

class AppProvider extends ChangeNotifier {
  String? _authPhone;
  String? _sessionToken;
  String? _driverType;
  Map<String, dynamic>? _driverProfile;
  Map<String, dynamic>? _courierProfile;
  String? _userRole; // merchant or customer
  String? _accountType; // marketplace | delivery | driver — يُقفل عند أول تسجيل
  bool _hasAdminAccess = false;
  Map<String, dynamic>? _appUserRecord;
  Map<String, dynamic>? _merchantStore; // بيانات المتجر أو المهنة الحالية
  List<MerchantOffer> _merchantOffers = [];
  List<MerchantReview> _merchantReviews = [];
  List<ListItem> _items = [];
  List<ListItem> _catalogItems = [];
  List<CartItem> _cart = [];
  List<ActiveOrder> _orders = [];
  List<ActiveOrder> _merchantIncomingOrders = [];
  List<ActiveOrder> _courierPoolOrders = [];
  List<ActiveOrder> _courierAssignedOrders = [];
  Map<String, dynamic>? _adminReports;
  List<TaxiRequest> _taxiRequests = [];
  List<String> _addresses = [];
  List<Map<String, String>> _notifications = [];
  final Set<String> _favoriteItemIds = <String>{};
  String _selectedCategory = 'all';
  String? _activeSubCategory;
  final String _lang = 'ar';
  bool _darkMode = false;
  bool _isHydrating = true;
  bool _isReady = false;
  bool _isRestoring = false; 
  bool _isSyncing = false;   
  bool _isLoggingIn = false;
  Timer? _bootWatchdog;
  String _customerName = '';
  String _customerPhone = '';
  String _customerAddress = '';
  String? _customerAvatarBase64;

  AppProvider() {
    _loadSettings();
  }

  /// رفع صورة (رابط عام أو Base64 احتياط) ثم إرجاع المرجع للحفظ.
  Future<String?> uploadImage(File file, {String bucket = 'uploads'}) async {
    _isSyncing = true;
    notifyListeners();
    try {
      final imageRef =
          await ImageStorageService.uploadImageFile(file, bucket: bucket);
      if (imageRef != null) {
        debugPrint(
          'UPLOAD_SUCCESS: Image stored as ${imageRef.length > 80 ? 'base64' : imageRef}',
        );
      } else {
        debugPrint('UPLOAD_ERROR: All upload strategies failed');
      }
      return imageRef;
    } catch (e) {
      debugPrint('UPLOAD_ERROR: $e');
      return null;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  String get lang => _lang;
  bool get hasSelectedLanguage => true;
  String? get userRole => _userRole;
  String? get accountType => _accountType;
  bool get hasLockedAccountType => _accountType?.trim().isNotEmpty == true;
  bool get isMarketplaceAccount => _accountType == 'marketplace';
  bool get isDeliveryAccount => _accountType == 'delivery';
  bool get isDriverAccount => _accountType == 'driver';
  bool get hasAdminAccess => _hasAdminAccess;
  String? get authPhone => _authPhone;
  String? get sessionToken => _sessionToken;
  bool get isLoggingIn => _isLoggingIn;
  bool get hasPhoneSession => _authPhone != null && _authPhone!.isNotEmpty;
  String? get customerAvatarBase64 =>
      ImageStorageService.normalizeImageRef(_customerAvatarBase64);
  String? get customerAvatarUrl => customerAvatarBase64;

  String? get merchantProfileImageBase64 {
    final store = _merchantStore;
    if (store == null) return null;
    final value = store['profileImageBase64'] ?? store['profile_image_base64'];
    final text = value?.toString().trim();
    return text != null && text.isNotEmpty ? text : null;
  }

  List<String> get merchantWorkSampleImagesBase64 {
    final store = _merchantStore;
    if (store == null) return const [];
    final value =
        store['workSampleImagesBase64'] ?? store['work_sample_images_base64'];
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
  bool get hasSelectedRole => _userRole?.trim().isNotEmpty == true;
  bool get hasCompletedCustomerProfile =>
      _customerName.trim().isNotEmpty && _customerPhone.trim().isNotEmpty;
  Map<String, dynamic>? get appUserRecord => _appUserRecord;
  Map<String, dynamic>? get merchantStore => _merchantStore;
  List<MerchantOffer> get merchantOffers =>
      List<MerchantOffer>.unmodifiable(_merchantOffers);
  List<MerchantReview> get merchantReviews =>
      List<MerchantReview>.unmodifiable(_merchantReviews);
  bool get darkMode => _darkMode;
  bool get isReady => _isReady;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  String get customerAddress => _customerAddress;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;
  bool get isMerchant => _userRole == 'merchant';
  bool get isDelivery => _userRole == 'delivery';
  bool get isDriver => _userRole == 'driver';
  bool get isCustomer => _userRole == 'customer';
  bool get isAdmin => _userRole == 'admin';
  bool get isRestoring => _isRestoring;
  bool get hasCompletedMerchantProfile =>
      _merchantStore != null && merchantStoreName.isNotEmpty;
  bool get isMerchantStoreOpen => (_merchantStore?['isOpen'] as bool?) ?? true;
  String get merchantStoreName =>
      (_merchantStore?['name'] as String?)?.trim() ?? '';
  String get merchantCategoryId =>
      (_merchantStore?['category'] as String?)?.trim() ?? '';
  List<String> get merchantServiceIds {
    final serviceIds = _merchantStore?['serviceIds'];
    if (serviceIds is List) {
      final parsed = serviceIds
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    final categoryId = merchantCategoryId;
    return categoryId.isNotEmpty ? [categoryId] : const [];
  }

  String get merchantActiveServiceId =>
      (_merchantStore?['activeServiceId'] as String?)?.trim() ??
      (merchantServiceIds.isNotEmpty ? merchantServiceIds.first : '');

  bool get merchantHasMultipleServices => merchantServiceIds.length > 1;

  MerchantServiceLabels get merchantActiveLabels =>
      merchantServiceLabels(merchantActiveServiceId);
  MerchantServiceLabels get merchantLabels => merchantActiveLabels;
  String get merchantDescription =>
      (_merchantStore?['description'] as String?)?.trim() ?? '';
  String get merchantCoverImage =>
      (_merchantStore?['coverImage'] as String?)?.trim() ??
      (_merchantStore?['cover_image_url'] as String?)?.trim() ??
      (_merchantStore?['coverImageBase64'] as String?)?.trim() ??
      '';
  String get merchantLogoImage =>
      (_merchantStore?['logoImage'] as String?)?.trim() ??
      (_merchantStore?['logo_image_url'] as String?)?.trim() ??
      (_merchantStore?['logoImageBase64'] as String?)?.trim() ??
      '';
  String get merchantPhone =>
      (_merchantStore?['phone'] as String?)?.trim() ?? '';
  String get merchantWhatsApp =>
      (_merchantStore?['whatsapp'] as String?)?.trim() ?? merchantPhone;
  String get merchantAddress =>
      (_merchantStore?['address'] as String?)?.trim() ?? '';
  String get merchantOpenTime =>
      (_merchantStore?['openTime'] as String?)?.trim() ?? '';
  String get merchantCloseTime =>
      (_merchantStore?['closeTime'] as String?)?.trim() ?? '';
  int get merchantDeliveryFee => merchantActiveServiceId == 'professionals'
      ? 0
      : merchantActiveServiceId == 'restaurant'
          ? 0
          : (_merchantStore?['deliveryFee'] as int?) ?? 0;
  String get merchantDeliveryAreas =>
      (_merchantStore?['deliveryAreas'] as String?)?.trim() ?? '';
  double get merchantRating =>
      (_merchantStore?['rating'] as num?)?.toDouble() ?? 0.0;
  String? get merchantProfileImageUrl =>
      _merchantStore?['profileImageUrl'] as String?;
  List<String> get merchantWorkSampleUrls {
    if (merchantActiveServiceId == 'restaurant') {
      return const [];
    }
    final images = _merchantStore?['workSampleUrls'];
    if (images is List) {
      return images
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String? get merchantProfessionalCategoryId =>
      (_merchantStore?['professionalCategoryId'] as String?) ??
      (_merchantStore?['professionalInfo'] is Map
          ? (_merchantStore?['professionalInfo'] as Map)['professionId']
              ?.toString()
          : null);

  bool get merchantCatalogSeeded => false;
  String? get driverType => _driverType;
  Map<String, dynamic>? get driverProfile => _driverProfile;
  bool get hasDriverProfile => _driverProfile != null;
  Map<String, dynamic>? get courierProfile => _courierProfile;
  bool get hasCourierProfile =>
      (_courierProfile?['name']?.toString().trim().isNotEmpty ?? false);
  String get deliveryCourierName {
    final name = _courierProfile?['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    if (_customerName.trim().isNotEmpty) return _customerName.trim();
    return 'مندوب التوصيل';
  }

  String get courierPhone {
    final phone = _courierProfile?['phone']?.toString().trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return _authPhone ?? _customerPhone;
  }

  bool get isCourierAvailable =>
      _courierProfile?['available'] as bool? ?? true;

  bool get driverAcceptsTaxi => _userRole == 'driver' || _driverServiceEnabled('taxi');
  bool get driverAcceptsDelivery => false;
  bool get driverAcceptsBoth => false;
  String get driverServiceModeLabelAr => 'سائق تكسي';
  String get driverServiceModeLabelEn => 'Taxi Driver';

  void setLanguage(String l) {
    // الإعداد مخصص للعربية فقط حاليًا
  }

  Future<void> _loadSettings() async {
    try {
      final accountRepo = AccountRepository.instance;
      final stored = await accountRepo.readStoredSession();
      if (stored != null) {
        _sessionToken = stored.token;
        SupabaseService.setSessionToken(stored.token);
        _authPhone = PhoneUtils.normalize(stored.phone);
        final restoredLocally = await _restoreLocalBackup(_authPhone!);
        if (restoredLocally && !_isReady) {
          _isHydrating = false;
          _isReady = true;
          notifyListeners();
        }

        _isRestoring = true;
        await _restoreRemoteSession(_authPhone!);
      }
    } catch (error) {
      debugPrint('CRITICAL: Initial load failed: $error');
    } finally {
      _bootWatchdog?.cancel();
      _bootWatchdog = null;
      _isRestoring = false;
      _isHydrating = false;
      _isReady = true;
      notifyListeners();
    }
  }

  List<String> _decodeStringList(dynamic value,
      {List<String> fallback = const []}) {
    if (value is List) {
      final parsed = value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }
    return List<String>.from(fallback);
  }

  /// توحيد رقم الهاتف للصيغة الدولية لضمان استرجاع البيانات القديمة (+964...)
  String _normalizeStoredPhone(String phone) => PhoneUtils.normalize(phone);

  AccountSnapshot _buildLocalBackupSnapshot() {
    return AccountSnapshot(
      userRole: _userRole,
      accountType: _accountType,
      customerName: _customerName,
      customerPhone: _customerPhone,
      customerAddress: _customerAddress,
      customerAvatarRef: _customerAvatarBase64,
      darkMode: _darkMode,
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
    );
  }

  void _applyLocalBackupSnapshot(Map<String, dynamic> snapshot) {
    _userRole = _trimmedOrNull(snapshot['userRole']?.toString()) ?? _userRole;
    _accountType = _trimmedOrNull(snapshot['accountType']?.toString()) ??
        _accountType;
    _customerName =
        _trimmedOrNull(snapshot['customerName']?.toString()) ?? _customerName;
    _customerPhone =
        _trimmedOrNull(snapshot['customerPhone']?.toString()) ?? _customerPhone;
    _customerAddress = _trimmedOrNull(snapshot['customerAddress']?.toString()) ??
        _customerAddress;
    _customerAvatarBase64 = _trimmedOrNull(
            snapshot['customerAvatarBase64']?.toString() ??
                snapshot['customerAvatarUrl']?.toString()) ??
        _customerAvatarBase64;
    _darkMode = snapshot['darkMode'] as bool? ?? _darkMode;
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
      _merchantReviews = reviews
          .whereType<Map>()
          .map((item) =>
              MerchantReview.fromMap(Map<String, dynamic>.from(item)))
          .toList();
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

  Future<void> _restoreRemoteSession(String phone) async {
    final normalizedPhone = _normalizeStoredPhone(phone);
    if (normalizedPhone.isEmpty || !AppConfig.isBackendConfigured) return;

    debugPrint('RESTORE: Loading data for $normalizedPhone');

    try {
      final bundle =
          await AccountRepository.instance.fetchRemoteAccount(normalizedPhone);

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
        _customerName = _trimmedOrNull(appUser['full_name']?.toString()) ??
            _customerName;
        _userRole = _trimmedOrNull(appUser['role']?.toString()) ?? _userRole;
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
        _customerAvatarBase64 =
            _trimmedOrNull(customerProfile['avatar_base64']?.toString() ??
                    customerProfile['avatar_url']?.toString()) ??
                _customerAvatarBase64;
      }

      if (merchantProfile != null) {
        _applyMerchantStoreSnapshot(_mapMerchantProfileRow(merchantProfile));
        if (_userRole == null) {
          _userRole = 'merchant';
        }
      }

      if (userState != null) {
        _applyRemoteState(userState);
      }

      // احتياط: إذا فشل جدول merchant_profiles استخدم merchantStore من app_state
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

      if (remoteProducts.isNotEmpty && _userRole == 'merchant') {
        _items = remoteProducts
            .map((row) => _listItemFromProductRow(row))
            .toList();
      }
      _applyFavoriteSelections();
      _inferAccountTypeFromLegacyData();
      _inferRoleFromRestoredData();
      _applyAccountTypeConstraints();

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

      await _persistLocalBackup();
      notifyListeners();
    } catch (e) {
      debugPrint('RESTORE_ERROR: $e');
    }
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
        return role == 'customer' || role == 'merchant';
      case 'delivery':
        return role == 'delivery';
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

    final fromUser = _trimmedOrNull(
      _appUserRecord?['account_type']?.toString() ??
          _appUserRecord?['accountType']?.toString(),
    );
    if (fromUser != null) {
      _accountType = fromUser;
      return;
    }

    final storedRole = _trimmedOrNull(_appUserRecord?['role']?.toString());
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
    if (_userRole != null && _userRole!.trim().isNotEmpty) return;

    final storedRole = _trimmedOrNull(_appUserRecord?['role']?.toString());
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

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
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

    // حماية قصوى: لا تسمح أبداً برفع بيانات الهوية إذا كانت فارغة في الذاكرة حالياً
    // هذا يمنع مسح البيانات القديمة في السحابة بالخطأ
    final nameToSave = _trimmedOrNull(_customerName);
    final roleToSave = _roleForAppUserSync();
    
    if (nameToSave == null && roleToSave == null && _customerAvatarBase64 == null) {
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

  void _applyFavoriteSelections() {
    final target = isCustomer ? _catalogItems : _items;
    if (target.isEmpty) return;
    for (final item in target) {
      item.isFavorite = _favoriteItemIds.contains(item.id);
    }
  }

  Future<void> refreshCustomerCatalog() async {
    if (!SupabaseService.isConfigured) return;
    try {
      final rows = await SupabaseService.loadCatalog();
      _catalogItems = rows.map(_listItemFromCatalogRow).toList();
      _applyFavoriteSelections();
      notifyListeners();
    } catch (error) {
      debugPrint('CATALOG_LOAD_ERROR: $error');
    }
  }

  Future<void> refreshMerchantIncomingOrders() => _refreshMerchantIncomingOrders();

  Future<void> _refreshMerchantIncomingOrders() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      _merchantIncomingOrders =
          await SupabaseService.loadMerchantIncomingOrders(phone);
      notifyListeners();
    } catch (error) {
      debugPrint('MERCHANT_ORDERS_LOAD_ERROR: $error');
    }
  }

  Future<void> refreshCustomerOrders() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      _orders = await SupabaseService.loadCustomerOrders(phone);
      notifyListeners();
    } catch (error) {
      debugPrint('CUSTOMER_ORDERS_LOAD_ERROR: $error');
    }
  }

  Future<void> refreshCourierOrders() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      final results = await Future.wait([
        SupabaseService.loadDeliveryPool(phone),
        SupabaseService.loadCourierOrders(phone),
      ]);
      _courierPoolOrders = results[0];
      _courierAssignedOrders = results[1];
      notifyListeners();
    } catch (error) {
      debugPrint('COURIER_ORDERS_LOAD_ERROR: $error');
    }
  }

  Future<void> _persistCustomerOrder(ActiveOrder order) async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null) return;
    await SupabaseService.saveCustomerOrder(phone, order);
  }

  /// تحويل الحالة الحالية إلى JSON للحفظ (فقط للإعدادات غير الحساسة)
  Map<String, dynamic> _buildRemoteState() {
    return {
      'darkMode': _darkMode,
      'driverType': _driverType,
      'driverProfile': _driverProfile,
      'courierProfile': _courierProfile,
      'accountType': _accountType,
      'customerPhone': _customerPhone,
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
      if (_merchantStore != null) 'merchantStore': _merchantStore,
      'merchantProfileComplete': hasCompletedMerchantProfile,
    };
  }

  Map<String, dynamic> _mapMerchantProfileRow(Map<String, dynamic> row) {
    return {
      'name': row['store_name']?.toString() ?? '',
      'description': row['description']?.toString() ?? '',
      'category': row['primary_service_id']?.toString() ?? 'restaurant',
      'phone': row['phone']?.toString() ?? '',
      'whatsapp': row['whatsapp']?.toString() ?? '',
      'address': row['address']?.toString() ?? '',
      'openTime': row['open_time']?.toString() ?? '',
      'closeTime': row['close_time']?.toString() ?? '',
      'deliveryFee': row['delivery_fee'] is num
          ? (row['delivery_fee'] as num).toInt()
          : 0,
      'deliveryAreas': row['delivery_areas']?.toString() ?? '',
      'isOpen': row['is_open'] as bool? ?? true,
      'serviceIds': _decodeStringList(row['service_ids']),
      'activeServiceId': row['active_service_id']?.toString(),
      'professionalCategoryId': row['professional_category_id']?.toString(),
      'professionalInfo': row['professional_info'],
      'profileImageBase64': row['profile_image_base64']?.toString(),
      'coverImage': row['cover_image_url']?.toString(),
      'coverImageBase64': row['cover_image_url']?.toString(),
      'logoImage': row['logo_image_url']?.toString(),
      'logoImageBase64': row['logo_image_url']?.toString(),
      'workSampleImagesBase64': row['work_sample_images_base64'],
      ...row,
    };
  }

  void _applyMerchantStoreSnapshot(Map<String, dynamic> snapshot) {
    if (snapshot.isEmpty) return;
    _merchantStore = Map<String, dynamic>.from(snapshot);
  }

  /// تطبيق الحالة المسترجعة من السحابة
  void _applyRemoteState(Map<String, dynamic> state) {
    _darkMode = state['darkMode'] as bool? ?? _darkMode;
    _driverType = state['driverType'] as String? ?? _driverType;
    final driverProfile = state['driverProfile'];
    if (driverProfile is Map) {
      _driverProfile = Map<String, dynamic>.from(driverProfile);
    }
    final courierProfile = state['courierProfile'];
    if (courierProfile is Map) {
      _courierProfile = Map<String, dynamic>.from(courierProfile);
    }
    _accountType = _trimmedOrNull(
          state['accountType']?.toString() ??
              state['account_type']?.toString(),
        ) ??
        _accountType;
    _hasAdminAccess = state['adminAccess'] == true;
    _customerPhone =
        _trimmedOrNull(state['customerPhone']?.toString()) ?? _customerPhone;
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
          .map((item) =>
              MerchantReview.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    final storedMerchant = state['merchantStore'];
    if (storedMerchant is Map &&
        (_merchantStore == null || merchantStoreName.isEmpty)) {
      _applyMerchantStoreSnapshot(Map<String, dynamic>.from(storedMerchant));
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

  Future<void> setDarkMode(bool enabled) async {
    _darkMode = enabled;
    notifyListeners();
    await _syncRemoteState();
  }

  Future<void> toggleDarkMode() => setDarkMode(!_darkMode);

  Future<void> updateCustomerProfile({
    String? name,
    String? phone,
    String? address,
    String? avatarBase64,
  }) async {
    if (name != null && name.trim().isNotEmpty) _customerName = name.trim();
    if (phone != null && phone.trim().isNotEmpty) _customerPhone = _normalizeStoredPhone(phone);
    if (address != null && address.trim().isNotEmpty) _customerAddress = address.trim();
    if (avatarBase64 != null) {
      _customerAvatarBase64 =
          ImageStorageService.normalizeImageRef(avatarBase64);
    }

    notifyListeners();
    await _persistLocalBackup();

    if (_authPhone != null && _authPhone!.isNotEmpty) {
      try {
        final phoneId = _normalizeStoredPhone(_authPhone!);
        debugPrint('RESTORE_LOG: Force saving profile for $phoneId');

        await SupabaseService.saveAppUser(
          phoneId,
          fullName: _customerName,
          avatarBase64: _customerAvatarBase64,
          role: _userRole,
        );

        await SupabaseService.saveCustomerProfile(phoneId, {
          'display_name': _customerName,
          'address': _customerAddress,
          ...ImageStorageService.customerAvatarFields(_customerAvatarBase64),
        });
        await SupabaseService.saveUserState(phoneId, _buildRemoteState());
        await _persistLocalBackup();

        debugPrint('RESTORE_LOG: Profile saved successfully.');
      } catch (error) {
        debugPrint('RESTORE_LOG: Failed to save profile: $error');
        rethrow;
      }
    }
  }

  Future<void> setPhoneSession(String phone, {String? sessionToken}) async {
    // توحيد الرقم فوراً قبل أي عملية أخرى
    final normalized = _normalizeStoredPhone(phone);
    if (normalized.isEmpty) return;
    final normalizedToken = _trimmedOrNull(sessionToken) ?? _sessionToken;
    _sessionToken = normalizedToken;
    SupabaseService.setSessionToken(normalizedToken);

    _isLoggingIn = true;
    _isRestoring = true;
    notifyListeners();

    _authPhone = normalized;
    _customerPhone = normalized;

    await AccountRepository.instance.persistSession(
      phone: normalized,
      token: normalizedToken,
    );

    try {
      debugPrint('==== FULL RESTORATION STARTED for $normalized ====');
      // انتظار جلب كل شيء حرفياً من السحابة قبل الانتقال للخطوة التالية
      await _restoreRemoteSession(normalized);
      
      // حماية: إذا لم يجد دوراً، لا تسمح بالمزامنة التلقائية فوراً
      if (_userRole == null) {
          debugPrint('Restoration warning: No role found in DB.');
      } else {
          debugPrint('Restoration success: User is $_userRole');
      }
    } catch (error) {
      debugPrint('Restoration flow error: $error');
    } finally {
      _isLoggingIn = false;
      _isRestoring = false; 
      _isHydrating = false;
      _isReady = true;
      await _persistLocalBackup();
      notifyListeners();
    }
  }

  Future<void> _persistMerchantOffers() async {
    if (_authPhone == null || _authPhone!.isEmpty) return;
    await SupabaseService.saveUserState(_authPhone!, _buildRemoteState());
  }

  Future<void> _persistMerchantReviews() async {
    if (_authPhone == null || _authPhone!.isEmpty) return;
    await SupabaseService.saveUserState(_authPhone!, _buildRemoteState());
  }

  Future<void> _persistMerchantStore() async {
    if (_merchantStore == null || _isRestoring || _isLoggingIn) return;
    
    // منع الحفظ التلقائي إذا كان اسم المتجر فارغاً (لمنع الكتابة فوق البيانات القديمة)
    if ((_merchantStore?['name']?.toString() ?? '').isEmpty) {
        return;
    }

    try {
      final phone = _normalizeStoredPhone(_authPhone ?? merchantPhone);
      if (phone.isNotEmpty) {
        await SupabaseService.saveMerchantProfile(phone, {
          'store_name': _merchantStore?['name'],
          'description': _merchantStore?['description'],
          'primary_service_id': _merchantStore?['category'],
          'whatsapp': _normalizeStoredPhone(_merchantStore?['whatsapp']?.toString() ?? ''),
          'address': _merchantStore?['address'],
          'open_time': _merchantStore?['openTime'] ?? _merchantStore?['open_time'],
          'close_time': _merchantStore?['closeTime'] ?? _merchantStore?['close_time'],
          'delivery_areas': _merchantStore?['deliveryAreas'] ?? _merchantStore?['delivery_areas'],
          'delivery_fee': _merchantStore?['deliveryFee'] ?? _merchantStore?['delivery_fee'],
          'is_open': _merchantStore?['isOpen'] ?? _merchantStore?['is_open'],
          'service_ids': _merchantStore?['serviceIds'] ?? _merchantStore?['service_ids'],
          'active_service_id': _merchantStore?['activeServiceId'],
          'professional_category_id': _merchantStore?['professionalCategoryId'],
          'professional_info': _merchantStore?['professionalInfo'],
          'work_sample_images_base64':
              _merchantStore?['workSampleImagesBase64'] ??
                  _merchantStore?['work_sample_images_base64'],
          ...ImageStorageService.merchantImageFields(
            profileRef: _merchantStore?['profileImageBase64']?.toString() ??
                _merchantStore?['profile_image_base64']?.toString(),
            coverRef: _merchantStore?['coverImageBase64']?.toString() ??
                _merchantStore?['cover_image_url']?.toString() ??
                _merchantStore?['coverImage']?.toString(),
            logoRef: _merchantStore?['logoImageBase64']?.toString() ??
                _merchantStore?['logo_image_url']?.toString() ??
                _merchantStore?['logoImage']?.toString(),
            workSamples: merchantWorkSampleImagesBase64,
          ),
        });
      }
    } catch (error) {
      debugPrint('Merchant store sync failed: $error');
      rethrow;
    }
  }

  Future<void> _persistMerchantStoreAndState() async {
    await _persistMerchantStore();
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone != null) {
      await SupabaseService.saveUserState(phone, _buildRemoteState());
    }
    await _persistLocalBackup();
  }

  Future<void> _persistMerchantItems() async {
    final phone = _normalizeStoredPhone(_authPhone ?? merchantPhone);
    if (phone.isNotEmpty) {
      for (final item in _items) {
        await SupabaseService.saveMerchantProduct(
            phone, _productRowFromListItem(item));
      }
    }
  }

  Future<void> addMerchantOffer(MerchantOffer offer) async {
    _merchantOffers.insert(0, offer);
    await _persistMerchantOffers();
    notifyListeners();
  }

  Future<void> updateMerchantOffer(MerchantOffer updatedOffer) async {
    final index =
        _merchantOffers.indexWhere((offer) => offer.id == updatedOffer.id);
    if (index == -1) return;
    _merchantOffers[index] = updatedOffer;
    await _persistMerchantOffers();
    notifyListeners();
  }

  Future<void> toggleMerchantOfferActive(String offerId) async {
    final index = _merchantOffers.indexWhere((offer) => offer.id == offerId);
    if (index == -1) return;
    _merchantOffers[index] = _merchantOffers[index]
        .copyWith(isActive: !_merchantOffers[index].isActive);
    await _persistMerchantOffers();
    notifyListeners();
  }

  Future<void> deleteMerchantOffer(String offerId) async {
    _merchantOffers.removeWhere((offer) => offer.id == offerId);
    await _persistMerchantOffers();
    notifyListeners();
  }

  Future<void> replyMerchantReview(String reviewId, String reply) async {
    final index =
        _merchantReviews.indexWhere((review) => review.id == reviewId);
    if (index == -1) return;
    _merchantReviews[index] = _merchantReviews[index].copyWith(
      reply: reply.trim(),
    );
    await _persistMerchantReviews();
    notifyListeners();
  }

  void setDriverType(String type) {
    _driverType = type == 'delivery' ? 'delivery' : 'taxi';
    notifyListeners();
  }

  void _normalizeDriverProfileForRole() {
    if (_userRole != 'driver' || _driverProfile == null) return;
    _driverType = 'taxi';
    _driverProfile = {
      ..._driverProfile!,
      'type': 'taxi',
      'services': {'taxi': true, 'delivery': false},
    };
  }

  bool _driverServiceEnabled(String service) {
    final services = _driverProfile?['services'];
    if (services is Map) {
      final value = services[service];
      if (value is bool) {
        return value;
      }
    }

    switch (_driverType) {
      case 'delivery':
        return service == 'delivery';
      case 'both':
        return true;
      case 'taxi':
      default:
        return service == 'taxi';
    }
  }

  Future<void> setDriverProfile(Map<String, dynamic> profile) async {
    final normalized = Map<String, dynamic>.from(profile);
    normalized['type'] = 'taxi';
    normalized['services'] = {'taxi': true, 'delivery': false};
    _driverType = 'taxi';

    _driverProfile = {
      ...?_driverProfile,
      ...normalized,
    };
    if (_authPhone != null && _authPhone!.isNotEmpty) {
      await SupabaseService.saveUserState(_authPhone!, _buildRemoteState());
    }
    notifyListeners();
  }

  Future<void> setCourierProfile(Map<String, dynamic> profile) async {
    _courierProfile = {
      ...?_courierProfile,
      ...profile,
    };
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone != null) {
      await SupabaseService.saveUserState(phone, _buildRemoteState());
    }
    await _persistLocalBackup();
    notifyListeners();
  }

  Future<void> setCourierAvailability(bool available) async {
    await setCourierProfile({'available': available});
  }

  Future<void> setDriverAvailability(bool available) async {
    await setDriverProfile({'available': available});
  }

  Future<void> setDriverServiceEnabled(String service, bool enabled) async {
    if (service != 'taxi') return;
    await setDriverProfile({
      'type': 'taxi',
      'services': {'taxi': enabled, 'delivery': false},
    });
  }

  Future<void> setMerchantStore(Map<String, dynamic> storeData) async {
    final serviceIds = (storeData['serviceIds'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList() ??
        <String>[];
    final category = (storeData['category'] as String?)?.trim() ??
        (serviceIds.isNotEmpty ? serviceIds.first : '');
    final normalizedServiceIds = serviceIds.isNotEmpty
        ? serviceIds
        : (category.isNotEmpty ? <String>[category] : <String>[]);
    final activeServiceId = (storeData['activeServiceId'] as String?)?.trim() ??
        (normalizedServiceIds.isNotEmpty ? normalizedServiceIds.first : '');
    _merchantStore = {
      'name': (storeData['name'] as String?)?.trim() ?? '',
      'description': (storeData['description'] as String?)?.trim() ?? '',
      'category': category,
      'image': (storeData['image'] as String?)?.trim() ?? '',
      'coverImage': (storeData['coverImage'] as String?)?.trim() ?? '',
      'logoImage': (storeData['logoImage'] as String?)?.trim() ?? '',
      'coverImageBase64':
          (storeData['coverImageBase64'] as String?)?.trim() ?? '',
      'logoImageBase64':
          (storeData['logoImageBase64'] as String?)?.trim() ?? '',
      'profileImageBase64':
          (storeData['profileImageBase64'] as String?)?.trim() ??
              (storeData['logoImageBase64'] as String?)?.trim() ??
              (storeData['logoImage'] as String?)?.trim() ??
              '',
      'phone': (storeData['phone'] as String?)?.trim() ?? '',
      'whatsapp': (storeData['whatsapp'] as String?)?.trim() ?? '',
      'address': (storeData['address'] as String?)?.trim() ?? '',
      'openTime': (storeData['openTime'] as String?)?.trim() ?? '',
      'closeTime': (storeData['closeTime'] as String?)?.trim() ?? '',
      'isOpen': true,
      'deliveryFee': storeData['deliveryFee'] is num
          ? (storeData['deliveryFee'] as num).toInt()
          : 0,
      'deliveryAreas': (storeData['deliveryAreas'] as String?)?.trim() ?? '',
      'rating': storeData['rating'] is num
          ? (storeData['rating'] as num).toDouble()
          : 0.0,
      'serviceIds': normalizedServiceIds,
      'activeServiceId': activeServiceId,
      if (storeData['professionalCategoryId'] != null)
        'professionalCategoryId': storeData['professionalCategoryId'],
      if (storeData['professionalInfo'] is Map &&
          (storeData['professionalInfo'] as Map)['professionId'] != null)
        'professionalCategoryId':
            (storeData['professionalInfo'] as Map)['professionId'],
      ...storeData,
    };
    notifyListeners();
    await _persistMerchantStoreAndState();
  }

  void updateMerchantStore(Map<String, dynamic> updates) {
    if (_merchantStore == null) return;
    _merchantStore = {
      ..._merchantStore!,
      ...updates,
    };
    notifyListeners();
    unawaited(_persistMerchantStoreAndState());
  }

  void toggleMerchantOpenStatus() {
    if (_merchantStore == null) return;
    _merchantStore!['isOpen'] = !isMerchantStoreOpen;
    notifyListeners();
    unawaited(_persistMerchantStoreAndState());
  }

  Future<void> setMerchantActiveService(String serviceId) async {
    if (_merchantStore == null) return;
    if (!merchantServiceIds.contains(serviceId)) return;
    _merchantStore!['activeServiceId'] = serviceId;
    notifyListeners();
    unawaited(_persistMerchantStoreAndState());
  }

  List<ListItem> get merchantItems {
    return _items
        .where((item) => item.category == merchantActiveServiceId)
        .toList();
  }

  List<ListItem> get merchantFeaturedItems {
    return merchantItems.take(3).toList();
  }

  int get merchantProductCount => merchantItems.length;
  int get merchantOrdersCount => _merchantIncomingOrders.length;
  int get merchantPendingOrdersCount => _merchantIncomingOrders
      .where((o) => o.statusKey == 'pending')
      .length;
  int get merchantActiveOrdersCount => _merchantIncomingOrders
      .where((o) =>
          o.statusKey == 'accepted' ||
          o.statusKey == 'preparing' ||
          o.statusKey == 'delivering')
      .length;
  int get merchantCompletedOrdersCount => _merchantIncomingOrders
      .where((o) => o.statusKey == 'completed')
      .length;

  Map<String, dynamic> _productRowFromListItem(ListItem item) {
    return {
      'id': item.id,
      'name_ar': item.nameAr,
      'name_en': item.nameEn,
      'description_ar': item.descriptionAr,
      'description_en': item.descriptionEn,
      'price': item.price,
      'rating': item.rating ?? 4.8,
      'category': item.category,
      'sub_category': item.subCategory,
      'category_label_ar': item.categoryLabelAr,
      'category_label_en': item.categoryLabelEn,
      ...ImageStorageService.productImageFields(
        item.imageBase64,
        fallbackAsset: item.image,
      ),
      'is_favorite': item.isFavorite,
      'avg_price_label_ar': item.avgPriceLabelAr,
      'avg_price_label_en': item.avgPriceLabelEn,
      'action_label_ar': item.actionLabelAr,
      'action_label_en': item.actionLabelEn,
      'address': item.address,
      'bedrooms': item.bedrooms,
      'bathrooms': item.bathrooms,
      'area_square_meter': item.areaSquareMeter,
      'floor_count': item.floorCount,
      'listing_mode': item.listingMode,
      'prep_minutes': item.prepMinutes,
      'is_available': item.isAvailable,
    };
  }

  ListItem _listItemFromCatalogRow(Map<String, dynamic> row) {
    return _listItemFromProductRow(row).copyWith(
      merchantPhone:
          row['merchant_phone']?.toString() ?? row['phone']?.toString(),
      merchantStoreName: row['merchant_store_name']?.toString() ?? '',
    );
  }

  ListItem _listItemFromProductRow(Map<String, dynamic> row) {
    return ListItem(
      id: row['id']?.toString() ?? '',
      nameAr: row['name_ar']?.toString() ?? '',
      nameEn: row['name_en']?.toString() ?? '',
      descriptionAr: row['description_ar']?.toString() ?? '',
      descriptionEn: row['description_en']?.toString() ?? '',
      price: (row['price'] as num?)?.toInt() ?? 0,
      rating: (row['rating'] as num?)?.toDouble(),
      category: row['category']?.toString() ?? 'restaurant',
      subCategory: row['sub_category']?.toString(),
      categoryLabelAr: row['category_label_ar']?.toString() ?? '',
      categoryLabelEn: row['category_label_en']?.toString() ?? '',
      image: row['image']?.toString() ?? '',
      imageBase64: ImageStorageService.resolveDisplayImage(
        imageBase64: row['image_base64']?.toString(),
        image: row['image']?.toString(),
      ),
      isFavorite: row['is_favorite'] as bool? ?? false,
      avgPriceLabelAr: row['avg_price_label_ar']?.toString() ?? '',
      avgPriceLabelEn: row['avg_price_label_en']?.toString() ?? '',
      actionLabelAr: row['action_label_ar']?.toString() ?? '',
      actionLabelEn: row['action_label_en']?.toString() ?? '',
      address: row['address']?.toString(),
      bedrooms: (row['bedrooms'] as num?)?.toInt(),
      bathrooms: (row['bathrooms'] as num?)?.toInt(),
      areaSquareMeter: (row['area_square_meter'] as num?)?.toInt(),
      floorCount: (row['floor_count'] as num?)?.toInt(),
      listingMode: row['listing_mode']?.toString(),
      prepMinutes: (row['prep_minutes'] as num?)?.toInt(),
      isAvailable: row['is_available'] as bool? ?? true,
    );
  }

  List<ListItem> get items => isCustomer ? _catalogItems : _items;
  List<ActiveOrder> get merchantIncomingOrders =>
      List<ActiveOrder>.unmodifiable(_merchantIncomingOrders);
  List<CartItem> get cart => _cart;
  List<ActiveOrder> get orders => _orders;
  List<TaxiRequest> get taxiRequests => _taxiRequests;
  List<String> get addresses => List<String>.unmodifiable(_addresses);
  List<Map<String, String>> get notifications =>
      List<Map<String, String>>.unmodifiable(_notifications);
  String get selectedCategory => _selectedCategory;
  String? get activeSubCategory => _activeSubCategory;

  void setCategory(String category) {
    _selectedCategory = category;
    if (category != 'all') {
      _activeSubCategory = null;
    }
    notifyListeners();
  }

  void resetHome() {
    _selectedCategory = 'all';
    _activeSubCategory = null;
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final target = isCustomer ? _catalogItems : _items;
    final index = target.indexWhere((item) => item.id == id);
    if (index != -1) {
      target[index].isFavorite = !target[index].isFavorite;
      if (target[index].isFavorite) {
        _favoriteItemIds.add(id);
      } else {
        _favoriteItemIds.remove(id);
      }
      if (_authPhone != null && _authPhone!.isNotEmpty) {
        unawaited(SupabaseService.saveCustomerFavorite(
          _authPhone!,
          id,
          isFavorite: target[index].isFavorite,
        ));
      }
      notifyListeners();
    }
  }

  bool addToCart(ListItem item) {
    final merchantPhone = _trimmedOrNull(item.merchantPhone);
    if (_cart.isNotEmpty && merchantPhone != null) {
      final existingMerchant = _trimmedOrNull(_cart.first.merchantPhone);
      if (existingMerchant != null && existingMerchant != merchantPhone) {
        return false;
      }
    }

    final index = _cart.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _cart[index].count++;
    } else {
      _cart.add(CartItem(
        id: item.id,
        nameAr: item.nameAr,
        nameEn: item.nameEn,
        price: item.price,
        count: 1,
        image: item.imageBase64 ?? item.image,
        category: item.category,
        merchantPhone: item.merchantPhone,
        merchantStoreName: item.merchantStoreName,
      ));
    }
    notifyListeners();
    return true;
  }

  bool get cartHasMultipleMerchants {
    final merchants = _cart
        .map((item) => _trimmedOrNull(item.merchantPhone))
        .whereType<String>()
        .toSet();
    return merchants.length > 1;
  }

  bool addStoreProductToCart(
    Map<String, dynamic> product,
    Map<String, dynamic> profile,
  ) {
    final row = Map<String, dynamic>.from(product)
      ..['merchant_phone'] = profile['phone']?.toString()
      ..['merchant_store_name'] = profile['store_name']?.toString() ?? '';
    return addToCart(_listItemFromCatalogRow(row));
  }

  void incrementCartItem(String id) {
    final index = _cart.indexWhere((i) => i.id == id);
    if (index != -1) {
      _cart[index].count++;
      notifyListeners();
    }
  }

  void decrementCartItem(String id) {
    final index = _cart.indexWhere((i) => i.id == id);
    if (index != -1) {
      if (_cart[index].count > 1) {
        _cart[index].count--;
      } else {
        _cart.removeAt(index);
      }
      notifyListeners();
    }
  }

  void removeFromCart(String id) {
    _cart.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  int get cartTotal =>
      _cart.fold(0, (sum, item) => sum + (item.price * item.count));

  int get cartCount => _cart.fold(0, (sum, item) => sum + item.count);

  Future<void> addAddress(String address) async {
    final value = address.trim();
    if (value.isEmpty) return;
    if (_addresses.contains(value)) return;
    
    _addresses.insert(0, value);
    notifyListeners();

    // حفظ فوري ومباشر في سوبابيس لضمان عدم الضياع
    if (_authPhone != null && _authPhone!.isNotEmpty) {
      try {
        await SupabaseService.saveCustomerAddress(
          _authPhone!,
          value,
          sortOrder: 0,
        );
        await _persistLocalBackup();
        debugPrint('DB_SUCCESS: New address pushed to cloud.');
      } catch (error) {
        debugPrint('DB_ERROR: Failed to save address: $error');
      }
    }
  }

  Future<void> removeAddress(int index) async {
    if (index < 0 || index >= _addresses.length) return;
    final removed = _addresses.removeAt(index);
    notifyListeners();

    if (_authPhone != null && _authPhone!.isNotEmpty) {
      try {
        await SupabaseService.deleteCustomerAddress(_authPhone!, removed);
        await _persistLocalBackup();
        debugPrint('DB_SUCCESS: Address removed from cloud.');
      } catch (error) {
        debugPrint('DB_ERROR: Failed to delete address: $error');
      }
    }
  }

  void addNotification(String title, String body) {
    _notifications.insert(0, {'title': title, 'body': body});
    notifyListeners();
  }

  int get totalSales => _merchantIncomingOrders
      .where((o) => o.statusKey == 'accepted' || o.statusKey == 'delivering')
      .fold(0, (sum, item) => sum + item.price);

  int get productCount => _items.length;

  void updateOrderStatus(
    String orderId,
    String newStatusKey,
    String statusAr,
    String statusEn,
  ) {
    final list = isMerchant ? _merchantIncomingOrders : _orders;
    final index = list.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = list[index];
    final updated = ActiveOrder(
      id: order.id,
      orderNumber: order.orderNumber,
      dateAr: order.dateAr,
      dateEn: order.dateEn,
      customerNameAr: order.customerNameAr,
      customerNameEn: order.customerNameEn,
      customerPhone: order.customerPhone,
      addressAr: order.addressAr,
      addressEn: order.addressEn,
      noteAr: order.noteAr,
      noteEn: order.noteEn,
      paymentMethodAr: order.paymentMethodAr,
      paymentMethodEn: order.paymentMethodEn,
      statusKey: newStatusKey,
      statusAr: statusAr,
      statusEn: statusEn,
      price: order.price,
      itemsCount: order.itemsCount,
      itemsNameAr: order.itemsNameAr,
      itemsNameEn: order.itemsNameEn,
      lineItems: order.lineItems,
      image: order.image,
      iconName: order.iconName,
      deliveryStatusKey: order.deliveryStatusKey,
      deliveryStatusAr: order.deliveryStatusAr,
      deliveryStatusEn: order.deliveryStatusEn,
      assignedCourierName: order.assignedCourierName,
      isRestaurantOrder: order.isRestaurantOrder,
      merchantPhone: order.merchantPhone,
      merchantStoreName: order.merchantStoreName,
      requiresDelivery: order.requiresDelivery,
      codConfirmed: order.codConfirmed,
    );
    list[index] = updated;
    if (isMerchant) {
      final phone = _trimmedOrNull(_authPhone);
      if (phone != null) {
        unawaited(SupabaseService.updateIncomingOrderStatus(
          phone,
          orderId,
          statusKey: newStatusKey,
          statusAr: statusAr,
          statusEn: statusEn,
        ).then((_) => _refreshMerchantIncomingOrders()));
      }
    } else {
      unawaited(_persistCustomerOrder(updated));
    }
    notifyListeners();
  }

  void addProduct(ListItem item) {
    _items.insert(0, item);
    final phone = _normalizeStoredPhone(_authPhone ?? merchantPhone);
    if (phone.isNotEmpty) {
      unawaited(
        SupabaseService.saveMerchantProduct(
          phone,
          _productRowFromListItem(item),
        ),
      );
    }
    notifyListeners();
  }

  void updateProduct(ListItem updatedItem) {
    final index = _items.indexWhere((item) => item.id == updatedItem.id);
    if (index == -1) return;
    _items[index] = updatedItem;
    unawaited(_persistMerchantItems());
    notifyListeners();
  }

  void deleteProduct(String id) {
    _items.removeWhere((item) => item.id == id);
    if (_authPhone != null && _authPhone!.isNotEmpty) {
      unawaited(SupabaseService.deleteMerchantProduct(id, phone: _authPhone));
    }
    unawaited(_persistMerchantItems());
    notifyListeners();
  }

  Future<int> checkout() async {
    if (_cart.isEmpty) return 0;

    final grouped = <String, List<CartItem>>{};
    for (final item in _cart) {
      final key = _trimmedOrNull(item.merchantPhone) ?? 'unknown';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    var createdCount = 0;
    for (final entry in grouped.entries) {
      final items = entry.value;
      if (items.isEmpty) continue;

      final isRestaurantOrder =
          items.any((item) => item.category == 'restaurant');
      final subtotal =
          items.fold(0, (sum, item) => sum + (item.price * item.count));
      final merchantPhone =
          entry.key == 'unknown' ? null : entry.key;
      final merchantStoreName = items.first.merchantStoreName;

      String finalAddressAr = _addresses.isNotEmpty
          ? _addresses.first
          : (_customerAddress.isNotEmpty
              ? _customerAddress
              : 'لم يتم تحديد الموقع');
      String finalAddressEn = _addresses.isNotEmpty
          ? _addresses.first
          : (_customerAddress.isNotEmpty
              ? _customerAddress
              : 'Location not set');

      final newOrder = ActiveOrder(
        id: '${DateTime.now().millisecondsSinceEpoch}-${createdCount + 1}',
        orderNumber:
            'ORD-${DateTime.now().millisecondsSinceEpoch}-${createdCount + 1}',
        dateAr: 'الآن',
        dateEn: 'Just now',
        customerNameAr:
            _customerName.trim().isNotEmpty ? _customerName : 'زبون الغيث',
        customerNameEn: _customerName.trim().isNotEmpty
            ? _customerName
            : 'Al-Ghaith Customer',
        customerPhone: _customerPhone,
        addressAr: finalAddressAr,
        addressEn: finalAddressEn,
        noteAr: '',
        noteEn: '',
        paymentMethodAr: 'نقداً عند الاستلام',
        paymentMethodEn: 'Cash on Delivery',
        statusKey: 'pending',
        statusAr: 'بانتظار الموافقة',
        statusEn: 'Pending Approval',
        price: subtotal,
        itemsCount: items.length,
        itemsNameAr: items.map((e) => e.nameAr).join(' ، '),
        itemsNameEn: items.map((e) => e.nameEn).join(', '),
        lineItems: items
            .map((item) => OrderLineItem(
                  nameAr: item.nameAr,
                  nameEn: item.nameEn,
                  quantity: item.count,
                  price: item.price,
                  image: item.image,
                ))
            .toList(),
        isRestaurantOrder:
            items.any((item) => item.category == 'restaurant'),
        requiresDelivery: true,
        codConfirmed: false,
        deliveryStatusKey: null,
        deliveryStatusAr: null,
        deliveryStatusEn: null,
        merchantPhone: merchantPhone,
        merchantStoreName: merchantStoreName,
      );
      _orders.insert(0, newOrder);
      unawaited(_persistCustomerOrder(newOrder));
      createdCount++;
    }

    _cart.clear();
    notifyListeners();
    return createdCount;
  }

  void loadInitialData(List<ListItem> initialItems) {
    _items = initialItems;
    _applyFavoriteSelections();
    unawaited(_persistMerchantItems());
    notifyListeners();
  }

  Future<bool> setUserRole(String role) async {
    if (role == 'admin') {
      if (!_hasAdminAccess) return false;
      _userRole = role;
      notifyListeners();
      final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
      if (phone != null) {
        await SupabaseService.saveUserState(phone, _buildRemoteState());
      }
      await _persistLocalBackup();
      await refreshAdminReports();
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

    _userRole = role;
    if (role == 'driver') {
      _normalizeDriverProfileForRole();
    }
    notifyListeners();

    await _syncIdentityRecords();
    await _persistAccountTypeIfNeeded();
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone != null) {
      await SupabaseService.saveUserState(phone, _buildRemoteState());
    }
    await _persistLocalBackup();

    if (role == 'customer') {
      await refreshCustomerCatalog();
      await refreshCustomerOrders();
    } else if (role == 'merchant') {
      await _refreshMerchantIncomingOrders();
    } else if (role == 'delivery') {
      await refreshCourierOrders();
    }
    return true;
  }

  /// بعد إكمال إعداد التاجر — تأكد من حفظ الدور + المتجر في السحابة.
  Future<void> activateMerchantRole() async {
    if (_accountType != null && _accountType != 'marketplace') return;
    if (_accountType == null) _accountType = 'marketplace';
    _userRole = 'merchant';
    notifyListeners();
    await _syncIdentityRecords();
    await _persistAccountTypeIfNeeded();
    if (_merchantStore != null && merchantStoreName.isNotEmpty) {
      await _persistMerchantStoreAndState();
    } else {
      final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
      if (phone != null) {
        await SupabaseService.saveUserState(phone, _buildRemoteState());
      }
      await _persistLocalBackup();
    }
    await _refreshMerchantIncomingOrders();
  }

  void resetAll() {
    _isRestoring = true;
    final previousPhone = _authPhone;
    
    // مسح البيانات من الذاكرة فقط
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
    _cart.clear();
    _items.clear();
    _catalogItems.clear();
    _orders.clear();
    _merchantIncomingOrders.clear();
    _courierPoolOrders.clear();
    _courierAssignedOrders.clear();
    _adminReports = null;
    _taxiRequests.clear();
    _addresses.clear();
    _notifications.clear();
    _customerName = '';
    _customerPhone = '';
    _customerAddress = '';
    _customerAvatarBase64 = null;
    _favoriteItemIds.clear();

    unawaited(
      AccountRepository.instance.clearSession(phone: previousPhone).then((_) {
        debugPrint('LOGOUT: Local session cleared.');
      }),
    );
    SupabaseService.setSessionToken(null);

    // العودة لوضع البداية
    _isReady = true; 
    _isLoggingIn = false;
    // نترك _isRestoring = true لفترة لضمان عدم حدوث مزامنة بالخطأ أثناء الانتقال لشاشة الدخول
    Future.delayed(const Duration(seconds: 1), () {
      _isRestoring = false;
      notifyListeners();
    });
  }

  List<TaxiRequest> get visibleTaxiRequests => List<TaxiRequest>.unmodifiable(
        _taxiRequests,
      );

  List<TaxiRequest> get visibleTaxiIncomingRequests =>
      List<TaxiRequest>.unmodifiable(_taxiRequests.where((request) {
        return request.statusKey == 'pending' || request.statusKey == 'new';
      }));

  List<TaxiRequest> get visibleTaxiActiveRequests =>
      List<TaxiRequest>.unmodifiable(_taxiRequests.where((request) {
        return const {
          'accepted',
          'on_way',
          'arrived',
          'picked_up',
          'in_progress',
        }.contains(request.statusKey);
      }));

  List<TaxiRequest> get visibleTaxiCompletedRequests =>
      List<TaxiRequest>.unmodifiable(_taxiRequests.where((request) {
        return const {'completed', 'done', 'finished'}
            .contains(request.statusKey);
      }));

  List<ActiveOrder> get deliveryIncomingOrders =>
      List<ActiveOrder>.unmodifiable(_courierPoolOrders);

  List<ActiveOrder> get deliveryActiveOrders =>
      List<ActiveOrder>.unmodifiable(_courierAssignedOrders.where((order) {
        return const {
          'accepted',
          'picked_up',
          'on_way',
          'delivering',
        }.contains(order.deliveryStatusKey);
      }));

  List<ActiveOrder> get deliveryCompletedOrders =>
      List<ActiveOrder>.unmodifiable(_courierAssignedOrders.where((order) {
        return const {'delivered', 'completed', 'done'}
            .contains(order.deliveryStatusKey);
      }));

  int get courierTotalEarnings => deliveryCompletedOrders.fold<int>(
        0,
        (sum, order) => sum + order.price,
      );

  int get courierCompletedCount => deliveryCompletedOrders.length;

  Map<String, dynamic>? get adminReports => _adminReports;

  List<ListItem> searchCatalogItems(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return List<ListItem>.unmodifiable(_catalogItems);
    }
    return _catalogItems.where((item) {
      return item.nameAr.toLowerCase().contains(normalized) ||
          item.nameEn.toLowerCase().contains(normalized) ||
          item.category.toLowerCase().contains(normalized) ||
          (item.merchantStoreName ?? '').toLowerCase().contains(normalized);
    }).toList();
  }

  Future<void> refreshAdminReports() async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null) return;
    try {
      _adminReports = await SupabaseService.loadAdminReports(phone);
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_REPORTS_ERROR: $error');
    }
  }

  List<ActiveOrder> get visibleDeliveryIncomingOrders => deliveryIncomingOrders;
  List<ActiveOrder> get visibleDeliveryActiveOrders => deliveryActiveOrders;
  List<ActiveOrder> get visibleDeliveryCompletedOrders =>
      deliveryCompletedOrders;

  void addTaxiRequest(TaxiRequest request) {
    _taxiRequests.insert(0, request);
    notifyListeners();
  }

  TaxiRequest? _updateTaxiRequest(
    String requestId,
    String statusKey,
    String statusAr,
    String statusEn, {
    String? assignedDriverName,
    String? vehicleType,
  }) {
    final index =
        _taxiRequests.indexWhere((request) => request.id == requestId);
    if (index == -1) return null;
    final request = _taxiRequests[index];
    final updated = TaxiRequest(
      id: request.id,
      requestNumber: request.requestNumber,
      requestedAtAr: request.requestedAtAr,
      requestedAtEn: request.requestedAtEn,
      customerNameAr: request.customerNameAr,
      customerNameEn: request.customerNameEn,
      customerPhone: request.customerPhone,
      pickupAddressAr: request.pickupAddressAr,
      pickupAddressEn: request.pickupAddressEn,
      dropoffAddressAr: request.dropoffAddressAr,
      dropoffAddressEn: request.dropoffAddressEn,
      rideTypeId: request.rideTypeId,
      rideTypeAr: request.rideTypeAr,
      rideTypeEn: request.rideTypeEn,
      fare: request.fare,
      statusKey: statusKey,
      statusAr: statusAr,
      statusEn: statusEn,
      noteAr: request.noteAr,
      noteEn: request.noteEn,
      paymentMethodAr: request.paymentMethodAr,
      paymentMethodEn: request.paymentMethodEn,
      assignedDriverName: assignedDriverName ?? request.assignedDriverName,
      vehicleType: vehicleType ?? request.vehicleType,
    );
    _taxiRequests[index] = updated;
    notifyListeners();
    return updated;
  }

  void acceptTaxiRequest(String requestId) => _updateTaxiRequest(
        requestId,
        'accepted',
        'تم القبول',
        'Accepted',
      );

  void rejectTaxiRequest(String requestId) => _updateTaxiRequest(
        requestId,
        'rejected',
        'تم الرفض',
        'Rejected',
      );

  void markTaxiOnWay(String requestId) => _updateTaxiRequest(
        requestId,
        'on_way',
        'في الطريق',
        'On the way',
      );

  void markTaxiArrived(String requestId) => _updateTaxiRequest(
        requestId,
        'arrived',
        'وصل السائق',
        'Driver arrived',
      );

  void markTaxiPickedUp(String requestId) => _updateTaxiRequest(
        requestId,
        'picked_up',
        'تمت الركوب',
        'Picked up',
      );

  void completeTaxiRequest(String requestId) => _updateTaxiRequest(
        requestId,
        'completed',
        'مكتمل',
        'Completed',
      );

  Future<void> acceptDeliveryOrder(String orderId) async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null) return;
    try {
      await SupabaseService.acceptDeliveryOrder(
        phone,
        orderId,
        courierName: deliveryCourierName,
      );
      await refreshCourierOrders();
    } catch (error) {
      debugPrint('ACCEPT_DELIVERY_ERROR: $error');
    }
  }

  Future<void> rejectDeliveryOrder(String orderId) async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null) return;
    try {
      await SupabaseService.rejectDeliveryOrder(phone, orderId);
      _courierPoolOrders.removeWhere((order) => order.id == orderId);
      notifyListeners();
      await refreshCourierOrders();
    } catch (error) {
      debugPrint('REJECT_DELIVERY_ERROR: $error');
    }
  }

  Future<void> markDeliveryPickedUp(String orderId) async {
    await _updateCourierDeliveryStatus(
      orderId,
      'picked_up',
      'تم استلام الطلب من المتجر',
      'Order picked up from store',
    );
  }

  Future<void> markDeliveryOnTheWay(String orderId) async {
    await _updateCourierDeliveryStatus(
      orderId,
      'on_way',
      'في الطريق للزبون',
      'On the way to customer',
    );
  }

  Future<void> markDeliveryCompleted(String orderId) async {
    await _updateCourierDeliveryStatus(
      orderId,
      'delivered',
      'تم التسليم — دفع نقداً',
      'Delivered — cash collected',
    );
  }

  Future<void> _updateCourierDeliveryStatus(
    String orderId,
    String deliveryStatusKey,
    String deliveryStatusAr,
    String deliveryStatusEn,
  ) async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null) return;
    try {
      await SupabaseService.updateDeliveryOrderStatus(
        phone,
        orderId,
        deliveryStatusKey: deliveryStatusKey,
        deliveryStatusAr: deliveryStatusAr,
        deliveryStatusEn: deliveryStatusEn,
      );
      await refreshCourierOrders();
    } catch (error) {
      debugPrint('UPDATE_DELIVERY_STATUS_ERROR: $error');
    }
  }
}
