import 'dart:async';
import 'dart:convert';

import 'dart:io'; // إضافة مكتبة الملفات
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../models/merchant_models.dart';
import '../services/supabase_service.dart';
import '../services/cloudflare_service.dart'; // إضافة خدمة كلود فلير
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
  bool _isLoggingIn = false; // حالة تتبع عملية الدخول الصارمة
  Timer? _syncTimer;         
  String _customerName = '';
  String _customerPhone = '';
  String _customerAddress = '';
  String? _customerAvatarBase64;

  AppProvider() {
    unawaited(_loadSettings());
  }

  String _backupKeyForPhone(String phone) =>
      'session_backup_${_normalizeStoredPhone(phone)}';

  Future<void> _persistLocalBackup() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null) return;

    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'authPhone': phone,
      'sessionToken': _sessionToken,
      'userRole': _userRole,
      'customerName': _customerName,
      'customerPhone': _customerPhone,
      'customerAddress': _customerAddress,
      'customerAvatarBase64': _customerAvatarBase64,
      'addresses': _addresses,
      'darkMode': _darkMode,
      'driverType': _driverType,
      'selectedCategory': _selectedCategory,
      'activeSubCategory': _activeSubCategory,
      'merchantStore': _merchantStore,
    };

    await prefs.setString(_backupKeyForPhone(phone), jsonEncode(payload));
  }

  Future<bool> _restoreLocalBackup(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_backupKeyForPhone(phone));
    if (raw == null || raw.isEmpty) return false;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final data = Map<String, dynamic>.from(decoded);

      _authPhone = _trimmedOrNull(data['authPhone']?.toString()) ?? _authPhone;
      _sessionToken =
          _trimmedOrNull(data['sessionToken']?.toString()) ?? _sessionToken;
      _userRole = _trimmedOrNull(data['userRole']?.toString()) ?? _userRole;
      _customerName =
          _trimmedOrNull(data['customerName']?.toString()) ?? _customerName;
      _customerPhone =
          _trimmedOrNull(data['customerPhone']?.toString()) ?? _customerPhone;
      _customerAddress =
          _trimmedOrNull(data['customerAddress']?.toString()) ?? _customerAddress;
      _customerAvatarBase64 =
          _trimmedOrNull(data['customerAvatarBase64']?.toString()) ??
              _customerAvatarBase64;

      final restoredAddresses = data['addresses'];
      if (restoredAddresses is List && restoredAddresses.isNotEmpty) {
        _addresses = restoredAddresses
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList();
      }

      _darkMode = data['darkMode'] as bool? ?? _darkMode;
      _driverType = data['driverType'] as String? ?? _driverType;
      _selectedCategory =
          data['selectedCategory'] as String? ?? _selectedCategory;
      _activeSubCategory =
          data['activeSubCategory'] as String? ?? _activeSubCategory;

      final merchantStore = data['merchantStore'];
      if (merchantStore is Map && merchantStore.isNotEmpty) {
        _merchantStore = Map<String, dynamic>.from(merchantStore);
      }

      return true;
    } catch (error) {
      debugPrint('Local backup restore failed: $error');
      return false;
    }
  }

  bool get isLoggingIn => _isLoggingIn;

  /// دالة ذكية لرفع الصورة لكلود فلير وتحديث الرابط
  Future<String?> uploadImage(File file) async {
    _isSyncing = true;
    notifyListeners();
    try {
      final url = await CloudflareService.uploadFile(file);
      return url;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    // لا تسمح أبداً بالمزامنة إذا كان المستخدم قد سجل خروجه أو في وضع الاستعادة
    if (_isHydrating || _isRestoring || _isLoggingIn || _authPhone == null) {
      return;
    }
    _scheduleSync();
  }

  /// جدولة المزامنة مع السحابة بشكل ذكي
  void _scheduleSync() {
    // لا تقم بالمزامنة في الحالات التالية:
    // 1. أثناء التحميل الأولي (Hydrating)
    // 2. أثناء استعادة البيانات بعد الدخول (Restoring)
    // 3. إذا لم يكن هناك رقم هاتف مسجل
    // 4. إذا كانت الخدمة غير مفعلة
    if (_isHydrating ||
        _isRestoring ||
        !hasPhoneSession ||
        !SupabaseService.isConfigured) {
      return;
    }

    // إلغاء أي موقت سابق لضمان استقرار الحالة (Debounce)
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), () {
      _syncRemoteState();
    });
  }

  String get lang => _lang;
  bool get hasSelectedLanguage => true;
  String? get userRole => _userRole;
  String? get authPhone => _authPhone;
  String? get sessionToken => _sessionToken;
  bool get hasPhoneSession => _authPhone != null && _authPhone!.isNotEmpty;
  bool get hasSelectedRole => _userRole?.trim().isNotEmpty == true;
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
  String? get customerAvatarBase64 => _customerAvatarBase64;
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
      (_merchantStore?['coverImageBase64'] as String?)?.trim() ??
      (_merchantStore?['coverImage'] as String?)?.trim() ??
      '';
  String get merchantLogoImage =>
      (_merchantStore?['logoImageBase64'] as String?)?.trim() ??
      (_merchantStore?['logoImage'] as String?)?.trim() ??
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
  String? get merchantProfileImageBase64 =>
      _merchantStore?['profileImageBase64'] as String?;
  List<String> get merchantWorkSampleImagesBase64 {
    if (merchantActiveServiceId == 'restaurant') {
      return const [];
    }
    final images = _merchantStore?['workSampleImagesBase64'];
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
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('auth_session_token');
      final normalizedToken = _trimmedOrNull(savedToken);
      if (normalizedToken != null) {
        _sessionToken = normalizedToken;
        SupabaseService.setSessionToken(normalizedToken);
      }
      final savedPhone = prefs.getString('auth_phone');
      if (savedPhone != null && savedPhone.trim().isNotEmpty) {
        _authPhone = _normalizeStoredPhone(savedPhone);
        
        // إجبار التطبيق على الانتظار حتى استعادة البيانات بالكامل
        _isRestoring = true;
        await _restoreRemoteSession(_authPhone!);
      }
    } catch (error) {
      debugPrint('CRITICAL: Initial load failed: $error');
    } finally {
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

  /// توحيد تنسيق رقم الهاتف ليصبح دائماً +9647... لضمان مطابقة الهوية في كل مكان
  String _normalizeStoredPhone(String phone) {
    final raw = phone.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (raw.isEmpty) return '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    
    // إذا بدأ بـ 07... نحوله لـ +9647...
    if (digits.startsWith('0') && digits.length >= 11) {
      return '+964${digits.substring(1)}';
    }
    // إذا بدأ بـ 9647... نضيف علامة +
    if (digits.startsWith('964') && digits.length >= 12) {
      return '+$digits';
    }
    // إذا كان 7... (10 أرقام) نضيف المقدمة
    if (digits.length == 10 && digits.startsWith('7')) {
      return '+964$digits';
    }
    
    return raw.startsWith('+') ? raw : '+$digits';
  }

  Future<void> _restoreRemoteSession(String phone) async {
    final normalizedPhone = _normalizeStoredPhone(phone);
    if (normalizedPhone.isEmpty || !SupabaseService.isConfigured) return;

    debugPrint('RESTORE_LOG: Starting ultra-fast parallel recovery for: $normalizedPhone');

    // تنفيذ طلبات الجلب بالتوازي (Parallel) لتقليل الوقت
    try {
      final results = await Future.wait([
        SupabaseService.loadAppUser(normalizedPhone),
        SupabaseService.loadCustomerProfile(normalizedPhone),
        SupabaseService.loadMerchantProfile(normalizedPhone),
        SupabaseService.loadCustomerAddresses(normalizedPhone),
        SupabaseService.loadCustomerFavoriteIds(normalizedPhone),
        SupabaseService.loadUserState(normalizedPhone),
      ]).timeout(const Duration(seconds: 18));

      final appUser = results[0] as Map<String, dynamic>?;
      final customerProfile = results[1] as Map<String, dynamic>?;
      final merchantProfile = results[2] as Map<String, dynamic>?;
      final addresses = results[3] as List<String>?;
      final favoriteIds = results[4] as List<String>?;
      final userState = results[5] as Map<String, dynamic>?;

      // تطبيق بيانات الهوية
      if (appUser != null) {
        _appUserRecord = appUser;
        _customerName = _trimmedOrNull(appUser['full_name']?.toString()) ?? _customerName;
        _userRole = _trimmedOrNull(appUser['role']?.toString()) ?? _userRole;
        _customerAvatarBase64 = _trimmedOrNull(appUser['avatar_base64']?.toString()) ?? _customerAvatarBase64;
      }

      if (customerProfile != null) {
        _customerName = _trimmedOrNull(customerProfile['display_name']?.toString()) ?? _customerName;
        _customerAddress = _trimmedOrNull(customerProfile['address']?.toString()) ?? _customerAddress;
      }

      if (userState != null && userState.isNotEmpty) {
        _applyRemoteState(userState);
      }

      // تطبيق بيانات المتجر
      if (merchantProfile != null) {
        _merchantStore = {
          'name': merchantProfile['store_name']?.toString() ?? '',
          'description': merchantProfile['description']?.toString() ?? '',
          'category': merchantProfile['primary_service_id']?.toString() ?? 'restaurant',
          'phone': merchantProfile['phone']?.toString() ?? normalizedPhone,
          'whatsapp': merchantProfile['whatsapp']?.toString() ?? '',
          'address': merchantProfile['address']?.toString() ?? '',
          'openTime': merchantProfile['open_time']?.toString() ?? '',
          'closeTime': merchantProfile['close_time']?.toString() ?? '',
          'deliveryFee': (merchantProfile['delivery_fee'] as num?)?.toInt() ?? 0,
          'isOpen': merchantProfile['is_open'] as bool? ?? true,
          'profileImageBase64': merchantProfile['profile_image_base64']?.toString(),
          'coverImage': merchantProfile['cover_image_url']?.toString() ?? '',
          'logoImage': merchantProfile['logo_image_url']?.toString() ?? '',
          'serviceIds': _decodeStringList(merchantProfile['service_ids']),
          'activeServiceId': merchantProfile['active_service_id']?.toString(),
          'deliveryAreas': merchantProfile['delivery_areas']?.toString() ?? '',
          'professionalCategoryId':
              merchantProfile['professional_category_id']?.toString(),
          'professionalInfo': merchantProfile['professional_info'],
          'workSampleImagesBase64': _decodeStringList(
            merchantProfile['work_sample_images_base64'],
          ),
        };
        _userRole = 'merchant';
        
        // جلب المنتجات بشكل مستقل لزيادة السرعة
        unawaited(SupabaseService.loadMerchantProducts(normalizedPhone).then((products) {
          if (products.isNotEmpty) {
            _items = products.map(_listItemFromProductRow).toList();
            _applyFavoriteSelections();
            notifyListeners();
          }
        }));
      }

      if (addresses != null && addresses.isNotEmpty) _addresses = List<String>.from(addresses);
      
      if (favoriteIds != null && favoriteIds.isNotEmpty) {
        _favoriteItemIds.clear();
        _favoriteItemIds.addAll(favoriteIds);
        _applyFavoriteSelections();
      }

      final hasCustomerFootprint =
          customerProfile != null ||
          appUser != null ||
          (addresses != null && addresses.isNotEmpty) ||
          (favoriteIds != null && favoriteIds.isNotEmpty);

      if ((_userRole == null || _userRole!.trim().isEmpty) &&
          merchantProfile == null &&
          hasCustomerFootprint) {
        _userRole = 'customer';
      }

      if (!hasCustomerFootprint &&
          merchantProfile == null &&
          (_userRole == null || _userRole!.trim().isEmpty)) {
        await _restoreLocalBackup(normalizedPhone);
      }

      await _persistLocalBackup();

      // جلب الطلبات في الخلفية دون تأخير فتح الواجهة
      unawaited(
        SupabaseService.loadCustomerOrders(normalizedPhone)
            .timeout(const Duration(seconds: 18))
            .then((orders) {
          if (orders.isNotEmpty) {
            _orders = List<ActiveOrder>.from(orders);
            notifyListeners();
          }
        }).catchError((error) {
          debugPrint('RESTORE_LOG: Orders recovery skipped: $error');
        }),
      );

      debugPrint('RESTORE_LOG: Parallel restoration complete.');
    } catch (e) {
      debugPrint('RESTORE_LOG: Parallel recovery failed: $e');
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
      'customerPhone': _customerPhone,
      'selectedCategory': _selectedCategory,
      'activeSubCategory': _activeSubCategory,
      // لا يتم حفظ العناوين هنا لمنع تضارب البيانات مع الجداول المخصصة
    };
  }

  /// تطبيق الحالة المسترجعة من السحابة
  void _applyRemoteState(Map<String, dynamic> state) {
    _darkMode = state['darkMode'] as bool? ?? _darkMode;
    _driverType = state['driverType'] as String? ?? _driverType;
    _customerPhone =
        _trimmedOrNull(state['customerPhone']?.toString()) ?? _customerPhone;
    _selectedCategory = state['selectedCategory'] as String? ?? _selectedCategory;
    _activeSubCategory = state['activeSubCategory'] as String? ?? _activeSubCategory;
  }

  Future<void> _syncRemoteState() async {
    if (!SupabaseService.isConfigured) return;
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null || _isRestoring || _isSyncing || _isLoggingIn) return;

    // حماية قصوى: لا تقم أبداً بمزامنة حالة فارغة إذا كان المستخدم تاجراً
    // هذا يمنع مسح بيانات المتجر والمنتجات من السحابة بالخطأ
    if (_userRole == 'merchant' && (_merchantStore == null || _items.isEmpty)) {
      debugPrint('SYNC_GUARD: Blocked empty sync for merchant to prevent data loss.');
      return;
    }

    _isSyncing = true;
    try {
      await _syncIdentityRecords();
      await SupabaseService.saveUserState(phone, _buildRemoteState());
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    _darkMode = enabled;
    notifyListeners();
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
    if (avatarBase64 != null) _customerAvatarBase64 = avatarBase64;

    notifyListeners();
    await _persistLocalBackup();

    // حفظ فوري ومباشر للسحابة دون انتظار المزامنة التلقائية
    if (_authPhone != null && _authPhone!.isNotEmpty) {
      try {
        final phoneId = _normalizeStoredPhone(_authPhone!);
        debugPrint('RESTORE_LOG: Force saving profile for $phoneId');
        
        // 1. تحديث الجدول الأساسي
        await SupabaseService.saveAppUser(
          phoneId,
          fullName: _customerName,
          avatarBase64: _customerAvatarBase64,
          role: _userRole,
        );

        // 2. تحديث جدول الزبون
        await SupabaseService.saveCustomerProfile(phoneId, {
          'display_name': _customerName,
          'avatar_base64': _customerAvatarBase64,
          'address': _customerAddress,
        });
        await SupabaseService.saveUserState(phoneId, _buildRemoteState());
        await _persistLocalBackup();
        
        debugPrint('RESTORE_LOG: Profile saved successfully.');
      } catch (error) {
        debugPrint('RESTORE_LOG: Failed to save profile: $error');
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
    _syncTimer?.cancel();
    notifyListeners();
    
    _authPhone = normalized;
    _customerPhone = normalized;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_phone', normalized);
    if (normalizedToken != null) {
      await prefs.setString('auth_session_token', normalizedToken);
    } else {
      await prefs.remove('auth_session_token');
    }
    
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
          'profile_image_base64': _merchantStore?['profileImageBase64'] ?? _merchantStore?['profile_image_base64'],
          'cover_image_url': _merchantStore?['coverImageBase64'] ?? _merchantStore?['coverImage'],
          'logo_image_url': _merchantStore?['logoImageBase64'] ?? _merchantStore?['logoImage'],
          'service_ids': _merchantStore?['serviceIds'] ?? _merchantStore?['service_ids'],
          'active_service_id': _merchantStore?['activeServiceId'],
          'professional_category_id': _merchantStore?['professionalCategoryId'],
          'professional_info': _merchantStore?['professionalInfo'],
          'work_sample_images_base64': _merchantStore?['workSampleImagesBase64'],
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
      'image': item.image,
      'image_base64': item.imageBase64,
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
      imageBase64: row['image_base64']?.toString(),
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
    if (_authPhone != null && _authPhone!.isNotEmpty) {
      await _syncIdentityRecords();
    }
    await _persistLocalBackup();
    notifyListeners();
  }

  void resetAll() {
    _isRestoring = true; // قفل المزامنة فوراً ومنع أي رفع بيانات
    _syncTimer?.cancel();
    
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

    // مسح رقم الهاتف من التخزين الدائم
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('auth_phone');
      prefs.remove('auth_session_token');
      debugPrint('LOGOUT: Local session cleared.');
    });
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
