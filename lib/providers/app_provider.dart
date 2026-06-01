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
  String? _userRole; // merchant or customer
  Map<String, dynamic>? _appUserRecord;
  Map<String, dynamic>? _merchantStore; // بيانات المتجر أو المهنة الحالية
  List<MerchantOffer> _merchantOffers = [];
  List<MerchantReview> _merchantReviews = [];
  List<ListItem> _items = [];
  List<CartItem> _cart = [];
  List<ActiveOrder> _orders = [];
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
  String get deliveryCourierName => 'مندوبي التوصيل';

  bool get driverAcceptsTaxi => _driverServiceEnabled('taxi');
  bool get driverAcceptsDelivery => _driverServiceEnabled('delivery');
  bool get driverAcceptsBoth => driverAcceptsTaxi && driverAcceptsDelivery;
  String get driverServiceModeLabelAr {
    if (driverAcceptsBoth) return 'سائق تكسي ومندوب توصيل';
    if (driverAcceptsDelivery) return 'مندوب توصيل';
    return 'سائق تكسي';
  }

  String get driverServiceModeLabelEn {
    if (driverAcceptsBoth) return 'Taxi Driver & Delivery Courier';
    if (driverAcceptsDelivery) return 'Delivery Courier';
    return 'Taxi Driver';
  }

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
      customerName: _customerName,
      customerPhone: _customerPhone,
      customerAddress: _customerAddress,
      customerAvatarRef: _customerAvatarBase64,
      darkMode: _darkMode,
      driverType: _driverType,
      driverProfile: _driverProfile,
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
        _merchantStore = {
          'name': merchantProfile['store_name']?.toString() ?? '',
          'category':
              merchantProfile['primary_service_id']?.toString() ?? 'restaurant',
          'phone': merchantProfile['phone']?.toString() ?? normalizedPhone,
          'isOpen': merchantProfile['is_open'] as bool? ?? true,
          'serviceIds': _decodeStringList(merchantProfile['service_ids']),
          'activeServiceId': merchantProfile['active_service_id']?.toString(),
          'profileImageBase64':
              merchantProfile['profile_image_base64']?.toString(),
          'coverImage': merchantProfile['cover_image_url']?.toString(),
          'coverImageBase64': merchantProfile['cover_image_url']?.toString(),
          'logoImage': merchantProfile['logo_image_url']?.toString(),
          'logoImageBase64': merchantProfile['logo_image_url']?.toString(),
          'workSampleImagesBase64':
              merchantProfile['work_sample_images_base64'],
          ...merchantProfile,
        };
        if (_userRole == null) {
          _userRole = 'merchant';
        }
      }

      if (userState != null) {
        _applyRemoteState(userState);
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

      if (remoteProducts.isNotEmpty) {
        _items = remoteProducts
            .map((row) => _listItemFromProductRow(row))
            .toList();
      }
      _applyFavoriteSelections();
      _inferRoleFromRestoredData();

      await _persistLocalBackup();
      notifyListeners();
    } catch (e) {
      debugPrint('RESTORE_ERROR: $e');
    }
  }

  void _inferRoleFromRestoredData() {
    if (_userRole != null && _userRole!.trim().isNotEmpty) return;

    final stateRole = _trimmedOrNull(_appUserRecord?['role']?.toString());
    if (stateRole != null) {
      _userRole = stateRole;
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

    if (_driverProfile != null && _driverProfile!.isNotEmpty) {
      _userRole = _trimmedOrNull(_driverType) == 'delivery' ? 'delivery' : 'driver';
    }
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
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
    final roleToSave = _trimmedOrNull(_userRole);
    
    if (nameToSave == null && roleToSave == null && _customerAvatarBase64 == null) {
      debugPrint('Sync skipped: Attempting to save empty identity');
      return; 
    }

    await SupabaseService.saveAppUser(
      phone,
      fullName: nameToSave,
      role: roleToSave,
      avatarBase64: _customerAvatarBase64,
    );

    final customerPayload = _customerProfilePayload();
    if (customerPayload.isNotEmpty) {
      await SupabaseService.saveCustomerProfile(phone, customerPayload);
    }
  }

  void _applyFavoriteSelections() {
    if (_items.isEmpty) return;
    for (final item in _items) {
      item.isFavorite = _favoriteItemIds.contains(item.id);
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
    };
  }

  /// تطبيق الحالة المسترجعة من السحابة
  void _applyRemoteState(Map<String, dynamic> state) {
    _darkMode = state['darkMode'] as bool? ?? _darkMode;
    _driverType = state['driverType'] as String? ?? _driverType;
    final driverProfile = state['driverProfile'];
    if (driverProfile is Map) {
      _driverProfile = Map<String, dynamic>.from(driverProfile);
    }
    _customerPhone =
        _trimmedOrNull(state['customerPhone']?.toString()) ?? _customerPhone;
    _userRole = _trimmedOrNull(state['userRole']?.toString()) ?? _userRole;
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
    }
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
    _driverType = type;
    notifyListeners();
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
    _driverProfile = {
      ...?_driverProfile,
      ...profile,
    };
    if (profile['type'] is String) {
      _driverType = profile['type'] as String;
    }
    if (_authPhone != null && _authPhone!.isNotEmpty) {
      await SupabaseService.saveUserState(_authPhone!, _buildRemoteState());
    }
    notifyListeners();
  }

  Future<void> setDriverAvailability(bool available) async {
    await setDriverProfile({'available': available});
  }

  Future<void> setDriverServiceEnabled(String service, bool enabled) async {
    final currentServices =
        Map<String, bool>.from(_driverProfile?['services'] as Map? ?? {});
    currentServices[service] = enabled;

    final updatedType =
        currentServices['taxi'] == true && currentServices['delivery'] == true
            ? 'both'
            : currentServices['delivery'] == true
                ? 'delivery'
                : 'taxi';

    await setDriverProfile({
      'type': updatedType,
      'services': currentServices,
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
    await _persistMerchantStore();
  }

  void updateMerchantStore(Map<String, dynamic> updates) {
    if (_merchantStore == null) return;
    _merchantStore = {
      ..._merchantStore!,
      ...updates,
    };
    notifyListeners();
    unawaited(_persistMerchantStore());
  }

  void toggleMerchantOpenStatus() {
    if (_merchantStore == null) return;
    _merchantStore!['isOpen'] = !isMerchantStoreOpen;
    notifyListeners();
    unawaited(_persistMerchantStore());
  }

  Future<void> setMerchantActiveService(String serviceId) async {
    if (_merchantStore == null) return;
    if (!merchantServiceIds.contains(serviceId)) return;
    _merchantStore!['activeServiceId'] = serviceId;
    notifyListeners();
    unawaited(_persistMerchantStore());
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
  int get merchantOrdersCount => _orders.length;
  int get merchantPendingOrdersCount =>
      _orders.where((o) => o.statusKey == 'pending').length;
  int get merchantActiveOrdersCount => _orders
      .where((o) =>
          o.statusKey == 'accepted' ||
          o.statusKey == 'preparing' ||
          o.statusKey == 'delivering')
      .length;
  int get merchantCompletedOrdersCount =>
      _orders.where((o) => o.statusKey == 'completed').length;

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

  List<ListItem> get items => _items;
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
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      _items[index].isFavorite = !_items[index].isFavorite;
      if (_items[index].isFavorite) {
        _favoriteItemIds.add(id);
      } else {
        _favoriteItemIds.remove(id);
      }
      if (_authPhone != null && _authPhone!.isNotEmpty) {
        unawaited(SupabaseService.saveCustomerFavorite(
          _authPhone!,
          id,
          isFavorite: _items[index].isFavorite,
        ));
      }
      notifyListeners();
    }
  }

  void addToCart(ListItem item) {
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
        image: item.image,
        category: item.category,
      ));
    }
    notifyListeners();
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

  int get totalSales => _orders
      .where((o) => o.statusKey == 'accepted' || o.statusKey == 'delivering')
      .fold(0, (sum, item) => sum + item.price);

  int get productCount => _items.length;

  void updateOrderStatus(
    String orderId,
    String newStatusKey,
    String statusAr,
    String statusEn,
  ) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = _orders[index];
    _orders[index] = ActiveOrder(
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
    );
    unawaited(_persistCustomerOrder(_orders[index]));
    notifyListeners();
  }

  void addProduct(ListItem item) {
    _items.insert(0, item);
    unawaited(_persistMerchantItems());
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

  void checkout() {
    if (_cart.isEmpty) return;
    final isRestaurantOrder =
        _cart.any((item) => item.category == 'restaurant');
    
    // تحديد العنوان المستخدم: المحفوظ أولاً، ثم المدخل، ثم افتراضي ذكي
    String finalAddressAr = _addresses.isNotEmpty 
        ? _addresses.first 
        : (_customerAddress.isNotEmpty ? _customerAddress : 'لم يتم تحديد الموقع');
    
    String finalAddressEn = _addresses.isNotEmpty 
        ? _addresses.first 
        : (_customerAddress.isNotEmpty ? _customerAddress : 'Location not set');

    final newOrder = ActiveOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderNumber: 'ORD-${DateTime.now().millisecond}${DateTime.now().second}',
      dateAr: 'الآن',
      dateEn: 'Just now',
      customerNameAr: _customerName.trim().isNotEmpty ? _customerName : 'زبون الغيث',
      customerNameEn: _customerName.trim().isNotEmpty ? _customerName : 'Al-Ghaith Customer',
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
      price: cartTotal,
      itemsCount: _cart.length,
      itemsNameAr: _cart.map((e) => e.nameAr).join(' ، '), // إصلاح الفاصلة المشوهة
      itemsNameEn: _cart.map((e) => e.nameEn).join(', '),
      lineItems: _cart
          .map((item) => OrderLineItem(
                nameAr: item.nameAr,
                nameEn: item.nameEn,
                quantity: item.count,
                price: item.price,
                image: item.image,
              ))
          .toList(),
      isRestaurantOrder: isRestaurantOrder,
      deliveryStatusKey: isRestaurantOrder ? 'waiting' : null,
      deliveryStatusAr: isRestaurantOrder ? 'بانتظار قبول المندوب' : null,
      deliveryStatusEn: isRestaurantOrder ? 'Waiting for courier' : null,
    );
    _orders.insert(0, newOrder);
    _cart.clear();
    unawaited(_persistCustomerOrder(newOrder));
    notifyListeners();
  }

  void loadInitialData(List<ListItem> initialItems) {
    _items = initialItems;
    _applyFavoriteSelections();
    unawaited(_persistMerchantItems());
    notifyListeners();
  }

  Future<void> setUserRole(String role) async {
    _userRole = role;
    notifyListeners();

    await _syncIdentityRecords();
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone != null) {
      await SupabaseService.saveUserState(phone, _buildRemoteState());
    }
    await _persistLocalBackup();
  }

  void resetAll() {
    _isRestoring = true;
    final previousPhone = _authPhone;
    
    // مسح البيانات من الذاكرة فقط
    _authPhone = null;
    _sessionToken = null;
    _userRole = null;
    _merchantStore = null;
    _appUserRecord = null;
    _driverType = null;
    _driverProfile = null;
    _cart.clear();
    _items.clear();
    _orders.clear();
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
      List<ActiveOrder>.unmodifiable(_orders.where((order) {
        if (!order.isRestaurantOrder) return false;
        return order.deliveryStatusKey == null ||
            order.deliveryStatusKey == 'waiting' ||
            order.deliveryStatusKey == 'pending';
      }));

  List<ActiveOrder> get deliveryActiveOrders =>
      List<ActiveOrder>.unmodifiable(_orders.where((order) {
        if (!order.isRestaurantOrder) return false;
        return const {
          'accepted',
          'delivering',
          'picked_up',
          'on_way',
        }.contains(order.deliveryStatusKey);
      }));

  List<ActiveOrder> get deliveryCompletedOrders =>
      List<ActiveOrder>.unmodifiable(_orders.where((order) {
        if (!order.isRestaurantOrder) return false;
        return const {'completed', 'delivered', 'done'}
            .contains(order.deliveryStatusKey);
      }));

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

  void acceptDeliveryOrder(String orderId) {
    _updateDeliveryOrder(orderId, 'accepted', 'تم القبول', 'Accepted');
  }

  void rejectDeliveryOrder(String orderId) {
    _updateDeliveryOrder(orderId, 'rejected', 'تم الرفض', 'Rejected');
  }

  void markDeliveryPickedUp(String orderId) {
    _updateDeliveryOrder(orderId, 'delivering', 'تم الاستلام', 'Picked up');
  }

  void markDeliveryCompleted(String orderId) {
    _updateDeliveryOrder(orderId, 'completed', 'مكتمل', 'Completed');
  }

  void _updateDeliveryOrder(
    String orderId,
    String newDeliveryStatusKey,
    String newDeliveryStatusAr,
    String newDeliveryStatusEn,
  ) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return;
    final order = _orders[index];
    _orders[index] = ActiveOrder(
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
      statusKey: order.statusKey,
      statusAr: order.statusAr,
      statusEn: order.statusEn,
      price: order.price,
      itemsCount: order.itemsCount,
      itemsNameAr: order.itemsNameAr,
      itemsNameEn: order.itemsNameEn,
      lineItems: order.lineItems,
      image: order.image,
      iconName: order.iconName,
      deliveryStatusKey: newDeliveryStatusKey,
      deliveryStatusAr: newDeliveryStatusAr,
      deliveryStatusEn: newDeliveryStatusEn,
      assignedCourierName: order.assignedCourierName,
      isRestaurantOrder: order.isRestaurantOrder,
    );
    unawaited(_persistCustomerOrder(_orders[index]));
    notifyListeners();
  }
}
