import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/catalog/marketplace_catalog.dart';
import '../core/catalog/marketplace_stats.dart';
import '../core/checkout/cart_promo.dart';
import '../core/notifications/notification_hub.dart';
import '../core/notifications/push_notification_inbox.dart';
import '../core/notifications/push_notification_service.dart';
import '../core/config/app_config.dart';
import '../core/utils/phone_utils.dart';
import '../data/models/account_snapshot.dart';
import '../data/repositories/account_repository.dart';
import '../models/app_models.dart';
import '../models/app_notification.dart';
import '../models/app_user_view.dart';
import '../models/home_category_platform_override.dart';
import '../models/merchant_models.dart';
import '../models/merchant_store_view.dart';
import '../services/supabase_service.dart';
import '../services/image_storage_service.dart';
import '../utils/merchant_service_labels.dart';
import '../utils/platform_key.dart';
import '../models/merchant_product_section.dart';
import '../utils/merchant_product_sections.dart';
import '../utils/courier_profile_fields.dart';
import '../utils/driver_profile_fields.dart';
import '../utils/merchant_profile_fields.dart';

class AppProvider extends ChangeNotifier {
  static const Duration _pendingApprovalTimeout = Duration(minutes: 20);
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
  MarketplaceStatsSnapshot? _marketplaceStats;
  bool _marketplaceStatsLoading = false;
  List<CartItem> _cart = [];
  CartPromoDefinition? _appliedCartPromo;
  List<ActiveOrder> _orders = [];
  List<ActiveOrder> _merchantIncomingOrders = [];
  List<ActiveOrder> _courierPoolOrders = [];
  List<ActiveOrder> _courierAssignedOrders = [];
  Map<String, dynamic>? _adminReports;
  List<TaxiRequest> _taxiRequests = [];
  List<String> _addresses = [];
  final List<AppNotificationItem> _notifications = [];
  late final NotificationHub _notificationHub =
      NotificationHub(_emitNotification);
  List<ActiveOrder> _courierPoolSnapshot = [];
  List<ActiveOrder> _courierAssignedSnapshot = [];
  Map<String, TaxiRequest> _taxiSnapshot = {};
  int _lastCartActivityMs = 0;
  final Set<String> _customerTimerEmitted = {};
  String? _pendingUnreadPromptRole;
  List<Map<String, dynamic>> _pendingOrderStatusSyncQueue = [];
  final Set<String> _favoriteItemIds = <String>{};
  String _selectedCategory = 'all';
  String? _activeSubCategory;
  final String _lang = 'ar';
  bool _darkMode = false;

  /// يتحكم بالنوافذ والبانرات المنبثقة فقط (قائمة الإشعارات تبقى تعمل).
  bool _inAppAlertsEnabled = true;
  bool _isHydrating = true;
  bool _isReady = false;
  bool _isRestoring = false;
  bool _isSyncing = false;
  bool _isLoggingIn = false;
  bool _isGuestMode = false;
  Timer? _bootWatchdog;
  String _customerName = '';
  String _customerPhone = '';
  String _customerAddress = '';
  double? _customerLatitude;
  double? _customerLongitude;
  String? _customerAvatarBase64;

  AppProvider() {
    PushNotificationInbox.onCourierStatusPush = handleCourierStatusPush;
    _bootWatchdog = Timer(const Duration(seconds: 20), _forceBootReady);
    _loadSettings();
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
  String get _effectiveCustomerPhone {
    final customerPhone = _customerPhone.trim();
    if (customerPhone.isNotEmpty) return customerPhone;
    return _authPhone?.trim() ?? '';
  }

  AppUserView get appUserView => AppUserView(_appUserRecord);

  bool get hasCompletedCustomerProfile {
    if (_effectiveCustomerPhone.isEmpty) return false;
    if (_customerName.trim().isNotEmpty) return true;
    if (hasCompletedMerchantProfile) return true;

    if (appUserView.fullName != null) return true;
    if (appUserView.email != null) return true;

    return false;
  }
  Map<String, dynamic>? get appUserRecord => _appUserRecord;
  Map<String, dynamic>? get merchantStore => _merchantStore;
  List<MerchantOffer> get merchantOffers =>
      List<MerchantOffer>.unmodifiable(_merchantOffers);
  List<MerchantReview> get merchantReviews =>
      List<MerchantReview>.unmodifiable(_merchantReviews);
  bool get darkMode => _darkMode;
  bool get inAppAlertsEnabled => _inAppAlertsEnabled;
  bool get isReady => _isReady;
  bool get isHydrating => _isHydrating;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  String get customerAddress => _customerAddress;
  double? get customerLatitude => _customerLatitude;
  double? get customerLongitude => _customerLongitude;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;
  bool get isMerchant => _userRole == 'merchant';
  bool get isDelivery => _userRole == 'delivery';
  bool get isDriver => _userRole == 'driver';
  bool get isCustomer => _userRole == 'customer';
  bool get isAdmin => _userRole == 'admin';
  bool get isRestoring => _isRestoring;
  bool get hasCompletedMerchantProfile =>
      _merchantStore != null && merchantStoreName.isNotEmpty;
  bool get isMerchantApproved =>
      MerchantProfileFields.isApproved(_merchantStore);
  bool get canUseMerchantAccount =>
      hasCompletedMerchantProfile && isMerchantApproved;
  /// عرض مُنمذج وآمن لبيانات المتجر (قراءة فقط).
  MerchantStoreView get merchantStoreView => MerchantStoreView(_merchantStore);
  bool get isMerchantStoreOpen => merchantStoreView.isOpen;
  bool get isBazaarApproved => merchantStoreView.isBazaarMember;
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
    final serviceIdsSnake = _merchantStore?['service_ids'];
    if (serviceIdsSnake is List) {
      final parsed = serviceIdsSnake
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    final categoryId = merchantCategoryId;
    if (categoryId.isNotEmpty) return [categoryId];
    final primary =
        (_merchantStore?['primary_service_id'] as String?)?.trim() ?? '';
    if (primary.isNotEmpty) return [primary];
    return const ['product'];
  }

  String get merchantActiveServiceId {
    final ids = merchantServiceIds;
    final activeCamel =
        (_merchantStore?['activeServiceId'] as String?)?.trim() ?? '';
    final activeSnake =
        (_merchantStore?['active_service_id'] as String?)?.trim() ?? '';
    final preferred = activeCamel.isNotEmpty ? activeCamel : activeSnake;
    if (preferred.isNotEmpty && ids.contains(preferred)) return preferred;
    // Legacy profiles may still have activeServiceId=restaurant while selling products.
    if (preferred == 'restaurant' &&
        ids.isNotEmpty &&
        !ids.contains('restaurant')) {
      return ids.first;
    }
    if (ids.isNotEmpty) return ids.first;
    final category = merchantCategoryId;
    if (category.isNotEmpty) return category;
    return 'product';
  }

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
  String get merchantWhatsApp {
    final explicit = (_merchantStore?['whatsapp'] as String?)?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    return merchantPhone;
  }
  bool get merchantShowPhoneToCustomers =>
      MerchantProfileFields.showPhoneToCustomers(_merchantStore);
  bool get merchantShowWhatsAppToCustomers =>
      MerchantProfileFields.showWhatsAppToCustomers(_merchantStore);
  String get merchantAddress =>
      MerchantProfileFields.addressFromMap(_merchantStore);
  double? get merchantLatitude =>
      _toDoubleValue(_merchantStore?['latitude']) ??
      _toDoubleValue(_merchantStore?['lat']);
  double? get merchantLongitude =>
      _toDoubleValue(_merchantStore?['longitude']) ??
      _toDoubleValue(_merchantStore?['lng']);
  bool requiresMerchantLocationForService(String serviceId) =>
      serviceId == 'restaurant' || serviceId == 'product';
  bool canPublishForService(String serviceId) =>
      !requiresMerchantLocationForService(serviceId) ||
      (merchantLatitude != null && merchantLongitude != null);
  void assertCanPublishForService(String serviceId) {
    if (canPublishForService(serviceId)) return;
    throw StateError(
      'يرجى تحديد موقع المتجر على الخريطة قبل نشر المنتجات.',
    );
  }

  String get merchantOpenTime =>
      MerchantProfileFields.timeFromMap(_merchantStore, isOpen: true);
  String get merchantCloseTime =>
      MerchantProfileFields.timeFromMap(_merchantStore, isOpen: false);
  int get merchantDeliveryFee => merchantActiveServiceId == 'professionals'
      ? 0
      : merchantActiveServiceId == 'restaurant'
          ? 0
          : merchantStoreView.deliveryFee;
  String get merchantDeliveryAreas =>
      (_merchantStore?['deliveryAreas'] as String?)?.trim() ?? '';
  double get merchantRating =>
      (_merchantStore?['rating'] as num?)?.toDouble() ?? 0.0;
  List<MerchantProductSection> get merchantProductSections =>
      MerchantProductSections.parseFromStore(_merchantStore);
  String? merchantProductSectionName(String? sectionId) =>
      MerchantProductSections.nameForId(merchantProductSections, sectionId);
  String? get merchantProfileImageUrl =>
      _merchantStore?['profileImageUrl'] as String?;

  double? _toDoubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool _isOrderActiveStatus(String statusKey) {
    return statusKey != 'completed' &&
        statusKey != 'cancelled' &&
        statusKey != 'rejected';
  }

  DateTime? _parseOrderCreatedAt(ActiveOrder order) {
    final raw = order.createdAt?.trim();
    if (raw != null && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toLocal();
    }
    // Fallback for legacy orders whose id starts with a Unix-ms timestamp
    final idPrefix = order.id.split('-').first;
    final ts = int.tryParse(idPrefix);
    if (ts == null || ts < 1000000000000) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
  }

  DateTime? parseOrderCreatedAtForSort(ActiveOrder order) =>
      _parseOrderCreatedAt(order);

  int? pendingApprovalRemainingSeconds(ActiveOrder order) {
    if (order.statusKey != 'pending') return null;
    final createdAt = _parseOrderCreatedAt(order);
    if (createdAt == null) return null;
    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    final remaining = _pendingApprovalTimeout.inSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  String? pendingApprovalRemainingLabelAr(ActiveOrder order) {
    final remaining = pendingApprovalRemainingSeconds(order);
    if (remaining == null) return null;
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    return 'المهلة المتبقية: $minutes:$seconds';
  }

  DateTime? _parseTimeOfDay(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final now = DateTime.now();
    return DateTime(
        now.year, now.month, now.day, h.clamp(0, 23), m.clamp(0, 59));
  }

  bool _isMerchantOpenNow({
    required bool? isOpenFlag,
    required String? openTime,
    required String? closeTime,
  }) {
    if (isOpenFlag == false) return false;
    final open = _parseTimeOfDay(openTime ?? '');
    final close = _parseTimeOfDay(closeTime ?? '');
    if (open == null || close == null) return true;
    final now = DateTime.now();
    if (close.isAfter(open)) {
      return now.isAfter(open) && now.isBefore(close);
    }
    final closeNextDay = close.add(const Duration(days: 1));
    if (now.isAfter(open)) return now.isBefore(closeNextDay);
    final nowNextDay = now.add(const Duration(days: 1));
    return nowNextDay.isBefore(closeNextDay);
  }

  static String _generateUuid() {
    final rng = math.Random.secure();
    const hex = '0123456789abcdef';
    String seg(int len) =>
        List.generate(len, (_) => hex[rng.nextInt(16)]).join();
    return '${seg(8)}-${seg(4)}-4${seg(3)}-${hex[8 + rng.nextInt(4)]}${seg(3)}-${seg(12)}';
  }

  String orderElapsedLabelAr(ActiveOrder order) {
    final createdAt = _parseOrderCreatedAt(order);
    if (createdAt == null) return 'الوقت غير متاح';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'منذ أقل من دقيقة';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

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
  bool get hasDriverProfile => DriverProfileFields.isComplete(_driverProfile);
  bool get isDriverApproved => DriverProfileFields.isApproved(_driverProfile);
  Map<String, dynamic>? get courierProfile => _courierProfile;
  bool get hasCourierProfile =>
      CourierProfileFields.isComplete(_courierProfile);
  bool get isCourierApproved =>
      CourierProfileFields.isApproved(_courierProfile);
  bool get canUseCourierAccount =>
      hasCourierProfile && isCourierApproved;
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
      MerchantProfileFields.boolValue(_courierProfile?['available'], fallback: true);

  bool get isGuestMode => _isGuestMode;

  void setGuestMode() {
    _isGuestMode = true;
    _userRole = 'customer';
    _authPhone = null;
    _sessionToken = null;
    SupabaseService.setSessionToken(null);
    _isHydrating = false;
    _isReady = true;
    notifyListeners();
  }

  bool get driverAcceptsTaxi =>
      _userRole == 'driver' || _driverServiceEnabled('taxi');
  bool get driverAcceptsDelivery => false;
  bool get driverAcceptsBoth => false;
  String get driverServiceModeLabelAr => 'سائق تكسي';
  String get driverServiceModeLabelEn => 'Taxi Driver';

  void setLanguage(String l) {
    // الإعداد مخصص للعربية فقط حاليًا
  }

  Future<void> _loadSettings() async {
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
      await _persistLocalBackup();
      notifyListeners();
    } catch (error) {
      debugPrint('ENRICH_SESSION_ERROR: $error');
    }
  }

  void _hydrateCustomerIdentityFromRestoredData() {
    if (_customerPhone.trim().isEmpty && _authPhone != null) {
      _customerPhone = _authPhone!;
    }
    if (_customerName.trim().isNotEmpty) return;

    _customerName = appUserView.fullName ??
        appUserView.email ??
        (hasCompletedMerchantProfile ? merchantStoreName : null) ??
        _customerName;
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

  String? _normalizeTimeForDb(dynamic value) =>
      MerchantProfileFields.normalizeTimeForPersistence(value);

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

  Future<void> _restoreRemoteSession(
    String phone, {
    bool deferPostRefresh = false,
    bool persistAfterRestore = true,
  }) async {
    final normalizedPhone = _normalizeStoredPhone(phone);
    if (normalizedPhone.isEmpty || !AppConfig.isBackendConfigured) return;
    final activePhone = _trimmedOrNull(_authPhone);
    if (activePhone != null && _normalizeStoredPhone(activePhone) != normalizedPhone) {
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
      // حساب موحّد: الزبون والتاجر والمندوب يتبادلون بحرية.
      // التسجيل الناقص (مثل ملف المندوب) يُكمَّل تلقائياً عبر توجيه الشاشات.
      case 'marketplace':
      case 'delivery':
        return role == 'customer' || role == 'merchant' || role == 'delivery';
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
      if (rows.isNotEmpty) {
        _catalogItems = rows
            .map(_listItemFromCatalogRow)
            .where((item) =>
                item.category != 'used' || item.isApproved) // تصفية المستعمل غير الموافق عليه
            .toList();
      } else {
        _catalogItems = _buildLocalCatalogFallback();
      }
      _applyFavoriteSelections();
      notifyListeners();
    } catch (error) {
      debugPrint('CATALOG_LOAD_ERROR: $error');
      _catalogItems = _buildLocalCatalogFallback();
      _applyFavoriteSelections();
      notifyListeners();
    }
  }

  Future<void> refreshMarketplaceStats({bool force = false}) async {
    if (!SupabaseService.isConfigured) return;
    if (_marketplaceStatsLoading) return;
    if (!force &&
        _marketplaceStats != null &&
        _marketplaceStats!.updatedAt != null &&
        DateTime.now().difference(_marketplaceStats!.updatedAt!) <
            const Duration(minutes: 3)) {
      return;
    }
    _marketplaceStatsLoading = true;
    notifyListeners();
    try {
      final row = await SupabaseService.loadMarketplaceStats();
      _marketplaceStats = MarketplaceStatsSnapshot.fromMap(row);
    } catch (error) {
      debugPrint('MARKETPLACE_STATS_ERROR: $error');
    } finally {
      _marketplaceStatsLoading = false;
      notifyListeners();
    }
  }

  ListItem catalogItemFromRow(Map<String, dynamic> row) {
    final item = _listItemFromCatalogRow(row);
    return item.copyWith(isFavorite: _favoriteItemIds.contains(item.id));
  }

  List<ListItem> _buildLocalCatalogFallback() {
    if (_items.isEmpty) return <ListItem>[];
    final fallbackPhone = _normalizeStoredPhone(
      _authPhone ?? _customerPhone ?? merchantPhone,
    );
    final fallbackStoreName = merchantStoreName;
    final fallbackLat = merchantLatitude;
    final fallbackLng = merchantLongitude;
    final fallbackOpenTime = merchantOpenTime;
    final fallbackCloseTime = merchantCloseTime;
    final fallbackIsOpen = isMerchantStoreOpen;
    return _items
        .where((item) => item.isAvailable)
        .map((item) => item.copyWith(
              merchantPhone: (item.merchantPhone ?? '').trim().isNotEmpty
                  ? item.merchantPhone
                  : (fallbackPhone.isNotEmpty ? fallbackPhone : null),
              merchantStoreName: (item.merchantStoreName ?? '')
                      .trim()
                      .isNotEmpty
                  ? item.merchantStoreName
                  : (fallbackStoreName.isNotEmpty ? fallbackStoreName : null),
              merchantLatitude: item.merchantLatitude ?? fallbackLat,
              merchantLongitude: item.merchantLongitude ?? fallbackLng,
              merchantOpenTime: item.merchantOpenTime ?? fallbackOpenTime,
              merchantCloseTime: item.merchantCloseTime ?? fallbackCloseTime,
              merchantIsOpen: item.merchantIsOpen ?? fallbackIsOpen,
            ))
        .toList();
  }

  Future<bool> _autoCancelExpiredPendingOrders(List<ActiveOrder> orders) async {
    var changed = false;
    final now = DateTime.now();
    for (final order in orders) {
      if (order.statusKey != 'pending') continue;
      final createdAt = _parseOrderCreatedAt(order);
      if (createdAt == null) continue;
      if (now.difference(createdAt) < _pendingApprovalTimeout) continue;
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
        noteAr:
            'انتهت مهلة قبول التاجر (${_pendingApprovalTimeout.inMinutes} دقيقة) وتم إلغاء الطلب تلقائيًا.',
        noteEn:
            'Order cancelled automatically after ${_pendingApprovalTimeout.inMinutes} minutes timeout.',
        paymentMethodAr: order.paymentMethodAr,
        paymentMethodEn: order.paymentMethodEn,
        statusKey: 'cancelled',
        statusAr: 'ملغي تلقائيًا',
        statusEn: 'Auto cancelled',
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
        deliveredAt: order.deliveredAt,
        estimatedArrivalMinutes: order.estimatedArrivalMinutes,
        estimatedArrivalAt: order.estimatedArrivalAt,
        courierPhone: order.courierPhone,
        customerLatitude: order.customerLatitude,
        customerLongitude: order.customerLongitude,
        createdAt: order.createdAt,
        merchantReadAt: order.merchantReadAt,
        merchantDecisionAt: order.merchantDecisionAt,
        isPriceLocked: order.isPriceLocked,
      );
      try {
        await SupabaseService.saveCustomerOrder(order.customerPhone, updated);
        changed = true;
      } catch (error) {
        debugPrint('AUTO_CANCEL_TIMEOUT_ERROR: $error');
      }
    }
    return changed;
  }

  Future<void> refreshMerchantIncomingOrders() =>
      _refreshMerchantIncomingOrders();

  Future<void> _refreshMerchantIncomingOrders() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      final previousById = {
        for (final order in _merchantIncomingOrders) order.id: order,
      };
      var loaded = await SupabaseService.loadMerchantIncomingOrders(phone);
      final changed = await _autoCancelExpiredPendingOrders(loaded);
      if (changed) {
        loaded = await SupabaseService.loadMerchantIncomingOrders(phone);
      }
      _merchantIncomingOrders = loaded;
      _notificationHub.onMerchantOrdersRefreshed(previousById, loaded);
      await _flushPendingOrderStatusSyncQueue();
      notifyListeners();
    } catch (error) {
      debugPrint('MERCHANT_ORDERS_LOAD_ERROR: $error');
    }
  }

  Future<void> refreshCustomerOrders() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      final previousById = {
        for (final order in _orders) order.id: order,
      };
      var loaded = await SupabaseService.loadCustomerOrders(phone);
      final changed = await _autoCancelExpiredPendingOrders(loaded);
      if (changed) {
        loaded = await SupabaseService.loadCustomerOrders(phone);
      }

      // احتفظ بأي طلبات محلية حديثة غير موجودة على السيرفر بعد
      // (إذا كان الحفظ بطيئاً أو فشل مؤقتاً)
      final serverIds = {for (final o in loaded) o.id};
      final recentLocalOrphans = _orders.where((o) {
        if (serverIds.contains(o.id)) return false;
        // فقط الطلبات الجديدة جداً (أقل من 5 دقائق)
        final created = _parseOrderCreatedAt(o);
        if (created == null) return false;
        return DateTime.now().difference(created) < const Duration(minutes: 5);
      }).toList();

      // حاول إعادة رفع الطلبات التي لم تُحفظ
      for (final orphan in recentLocalOrphans) {
        try {
          await SupabaseService.saveCustomerOrder(phone, orphan);
          debugPrint('RETRY_SAVE: Orphan order ${orphan.id} re-uploaded.');
        } catch (e) {
          debugPrint('RETRY_SAVE_ERROR: ${orphan.id}: $e');
        }
      }

      // إذا أعدنا رفع طلبات، حمّل القائمة من جديد
      if (recentLocalOrphans.isNotEmpty) {
        try {
          loaded = await SupabaseService.loadCustomerOrders(phone);
        } catch (_) {}
      }

      _orders = loaded;

      // أبقِ الطلبات المحلية الحديثة التي لم تُحفظ بعد مرئيةً حتى لا تختفي من الواجهة
      final confirmedIds = {for (final o in _orders) o.id};
      for (final orphan in recentLocalOrphans) {
        if (!confirmedIds.contains(orphan.id)) {
          _orders.insert(0, orphan);
        }
      }

      _notificationHub.onCustomerOrdersRefreshed(previousById, loaded);
      notifyListeners();
    } catch (error) {
      debugPrint('CUSTOMER_ORDERS_LOAD_ERROR: $error');
    }
  }

  Future<void> refreshCourierOrders() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      final prevPool = List<ActiveOrder>.from(_courierPoolSnapshot);
      final prevAssigned = List<ActiveOrder>.from(_courierAssignedSnapshot);
      final results = await Future.wait([
        SupabaseService.loadDeliveryPool(phone),
        SupabaseService.loadCourierOrders(phone),
      ]);
      _courierPoolOrders = results[0];
      _courierAssignedOrders = results[1];
      _courierPoolSnapshot = List<ActiveOrder>.from(_courierPoolOrders);
      _courierAssignedSnapshot = List<ActiveOrder>.from(_courierAssignedOrders);
      _notificationHub.courierBannersFromDiff(
        previousPool: prevPool,
        pool: _courierPoolOrders,
        previousAssigned: prevAssigned,
        assigned: _courierAssignedOrders,
      );
      notifyListeners();
    } catch (error) {
      debugPrint('COURIER_ORDERS_LOAD_ERROR: $error');
    }
  }

  List<RoleBannerData> pollCourierBanners() {
    final prevPool = List<ActiveOrder>.from(_courierPoolSnapshot);
    final prevAssigned = List<ActiveOrder>.from(_courierAssignedSnapshot);
    _courierPoolSnapshot = List<ActiveOrder>.from(_courierPoolOrders);
    _courierAssignedSnapshot = List<ActiveOrder>.from(_courierAssignedOrders);
    return _notificationHub.courierBannersFromDiff(
      previousPool: prevPool,
      pool: _courierPoolOrders,
      previousAssigned: prevAssigned,
      assigned: _courierAssignedOrders,
    );
  }

  List<RoleBannerData> pollTaxiBanners() {
    final prev = Map<String, TaxiRequest>.from(_taxiSnapshot);
    _taxiSnapshot = {for (final r in _taxiRequests) r.id: r};
    return _notificationHub.taxiBannersFromDiff(
      previousById: prev,
      current: _taxiRequests,
    );
  }

  void tickCustomerNotificationTimers() {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    if (_cart.isNotEmpty && _lastCartActivityMs > 0) {
      const abandoned = Duration(minutes: 30);
      if (nowMs - _lastCartActivityMs >= abandoned.inMilliseconds &&
          !_customerTimerEmitted.contains('cart_abandoned')) {
        _customerTimerEmitted.add('cart_abandoned');
        _notificationHub.onAbandonedCart(cartCount);
      }
    }

    for (final order in _orders) {
      final id = order.id;
      if (order.statusKey == 'delivering' ||
          order.deliveryStatusKey == 'on_way') {
        if (!_customerTimerEmitted.contains('delay:$id')) {
          final eta = order.estimatedArrivalAt;
          if (eta != null && eta.isNotEmpty) {
            final parsed = DateTime.tryParse(eta);
            if (parsed != null && now.isAfter(parsed)) {
              _customerTimerEmitted.add('delay:$id');
              _notificationHub.onDeliveryDelay(order);
            }
          }
        }
      }
      if (order.requiresDelivery &&
          !order.codConfirmed &&
          (order.statusKey == 'delivering' ||
              order.deliveryStatusKey == 'on_way' ||
              order.deliveryStatusKey == 'picked_up')) {
        final key = 'cod:$id';
        if (!_customerTimerEmitted.contains(key)) {
          _customerTimerEmitted.add(key);
          _notificationHub.onCustomerCodReminder(order);
        }
      }
      if (order.statusKey == 'completed') {
        final key = 'rate:$id';
        if (_customerTimerEmitted.contains(key)) continue;
        final delivered = order.deliveredAt;
        DateTime? completedAt;
        if (delivered != null && delivered.isNotEmpty) {
          completedAt = DateTime.tryParse(delivered);
        }
        completedAt ??= _parseOrderCreatedAt(order);
        if (completedAt != null &&
            now.difference(completedAt) >= const Duration(hours: 2) &&
            now.difference(completedAt) <= const Duration(days: 3)) {
          _customerTimerEmitted.add(key);
          _notificationHub.onRateOrderReminder(order);
        }
      }
    }
  }

  void tickMerchantNotificationTimers() {
    final now = DateTime.now();
    for (final offer in _merchantOffers) {
      if (!offer.isActive) continue;
      final end = DateTime.tryParse(offer.endDate);
      if (end == null) continue;
      final days = end.difference(now).inDays;
      if (days <= 2) {
        final key = 'offer:${offer.id}';
        if (_customerTimerEmitted.add(key)) {
          _notificationHub.onOfferExpiringSoon(offer.titleAr, days);
        }
      }
    }
  }

  void _touchCartActivity() {
    _lastCartActivityMs = DateTime.now().millisecondsSinceEpoch;
    _customerTimerEmitted.remove('cart_abandoned');
  }

  Future<void> _persistCustomerOrder(ActiveOrder order) async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null) return;
    await SupabaseService.saveCustomerOrder(phone, order);
  }

  /// تحويل الحالة الحالية إلى JSON للحفظ (فقط للإعدادات غير الحساسة)
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

  String _resolveMerchantPrimaryCategoryFromRow(Map<String, dynamic> row) {
    final primary = row['primary_service_id']?.toString().trim() ?? '';
    final serviceIds = _decodeStringList(row['service_ids']);
    if (serviceIds.isNotEmpty) {
      if (primary.isNotEmpty && serviceIds.contains(primary)) return primary;
      if (primary == 'restaurant' && !serviceIds.contains('restaurant')) {
        return serviceIds.first;
      }
      return serviceIds.first;
    }
    if (primary.isNotEmpty) return primary;
    return '';
  }

  Map<String, dynamic> _mapMerchantProfileRow(Map<String, dynamic> row) {
    return {
      'name': row['store_name']?.toString() ?? '',
      'description': row['description']?.toString() ?? '',
      'category': _resolveMerchantPrimaryCategoryFromRow(row),
      'phone': row['phone']?.toString() ?? '',
      'whatsapp': row['whatsapp']?.toString() ?? '',
      'address': row['address']?.toString() ?? '',
      'latitude': _toDoubleValue(row['latitude']) ?? _toDoubleValue(row['lat']),
      'longitude':
          _toDoubleValue(row['longitude']) ?? _toDoubleValue(row['lng']),
      'openTime': MerchantProfileFields.formatTimeDisplay(row['open_time']),
      'closeTime': MerchantProfileFields.formatTimeDisplay(row['close_time']),
      'open_time': MerchantProfileFields.formatTimeDisplay(row['open_time']),
      'close_time': MerchantProfileFields.formatTimeDisplay(row['close_time']),
      'deliveryFee':
          row['delivery_fee'] is num ? (row['delivery_fee'] as num).toInt() : 0,
      'deliveryAreas': row['delivery_areas']?.toString() ?? '',
      'isOpen': MerchantProfileFields.boolValue(row['is_open'], fallback: true),
      'isFrozen': MerchantProfileFields.boolValue(row['is_frozen'], fallback: false),
      'isBazaarMember':
          MerchantProfileFields.boolValue(row['is_bazaar_member'], fallback: false),
      'isApproved': (row['is_approved'] ?? row['isApproved']) == null
          ? null
          : MerchantProfileFields.boolValue(
              row['is_approved'] ?? row['isApproved'],
              fallback: false,
            ),
      'approvalStatus':
          row['approval_status']?.toString() ?? row['approvalStatus']?.toString(),
      'rejectionReasonKey': row['rejection_reason_key']?.toString() ??
          row['rejectionReasonKey']?.toString(),
      'rejectionMessageAr': row['rejection_message_ar']?.toString() ??
          row['rejectionMessageAr']?.toString(),
      'serviceIds': _decodeStringList(row['service_ids']),
      'activeServiceId': row['active_service_id']?.toString(),
      'restaurantCategory': row['restaurant_category']?.toString(),
      'professionalCategoryId': row['professional_category_id']?.toString(),
      'professionalInfo': row['professional_info'],
      'profileImageBase64': row['profile_image_base64']?.toString(),
      'coverImage': row['cover_image_url']?.toString(),
      'coverImageBase64': row['cover_image_url']?.toString(),
      'logoImage': row['logo_image_url']?.toString(),
      'logoImageBase64': row['logo_image_url']?.toString(),
      'workSampleImagesBase64': row['work_sample_images_base64'],
      'productSections': MerchantProductSections.toPayload(
        MerchantProductSections.parseList(
          row['product_sections'] ?? row['productSections'],
        ),
      ),
      'product_sections': row['product_sections'] ?? row['productSections'],
      ...row,
    };
  }

  void _applyMerchantStoreSnapshot(Map<String, dynamic> snapshot) {
    if (snapshot.isEmpty) return;
    final previousStore = _merchantStore == null
        ? null
        : Map<String, dynamic>.from(_merchantStore!);
    final wasApproved = MerchantProfileFields.isApproved(previousStore);
    final wasRejected = MerchantProfileFields.isRejected(previousStore);
    final previousRejectionMessage =
        MerchantProfileFields.rejectionMessage(previousStore);

    _merchantStore = Map<String, dynamic>.from(snapshot);
    _notifyMerchantApprovalTransition(
      wasApproved: wasApproved,
      wasRejected: wasRejected,
      previousRejectionMessage: previousRejectionMessage,
    );
  }

  void _notifyMerchantApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  }) {
    if (!hasCompletedMerchantProfile) return;

    final nowApproved = isMerchantApproved;
    final nowRejected = MerchantProfileFields.isRejected(_merchantStore);
    final rejectionMessage =
        MerchantProfileFields.rejectionMessage(_merchantStore);

    if (nowApproved && !wasApproved) {
      _notificationHub.onMerchantProfileActivated();
      _queueUnreadPromptForRole('merchant');
      return;
    }

    if (nowRejected &&
        (!wasRejected || rejectionMessage != previousRejectionMessage)) {
      _notificationHub.onMerchantRejected(rejectionMessage);
      _queueUnreadPromptForRole('merchant');
    }
  }

  /// تطبيق الحالة المسترجعة من السحابة
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

  Future<void> updateCustomerProfile({
    String? name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    String? avatarBase64,
  }) async {
    if (name != null && name.trim().isNotEmpty) _customerName = name.trim();
    if (phone != null && phone.trim().isNotEmpty)
      _customerPhone = _normalizeStoredPhone(phone);
    if (address != null && address.trim().isNotEmpty)
      _customerAddress = address.trim();
    if (latitude != null && latitude.isFinite) _customerLatitude = latitude;
    if (longitude != null && longitude.isFinite) _customerLongitude = longitude;
    if (avatarBase64 != null) {
      _customerAvatarBase64 =
          ImageStorageService.normalizeImageRef(avatarBase64);
    }

    _notificationHub.onProfileUpdated(
      notificationAudienceForRole(_userRole) ?? 'customer',
    );
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
          'latitude': _customerLatitude,
          'longitude': _customerLongitude,
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
    final normalized = _normalizeStoredPhone(phone);
    if (normalized.isEmpty) return;

    final normalizedToken = _trimmedOrNull(sessionToken) ?? _sessionToken;
    _sessionToken = normalizedToken;
    SupabaseService.setSessionToken(normalizedToken);
    _authPhone = normalized;
    _customerPhone = normalized;
    _isGuestMode = false;

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
    _isGuestMode = false;
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
      if (phone.isEmpty) return;

      final category = (_merchantStore?['category']?.toString() ?? '').trim();
      var serviceIds = (_merchantStore?['serviceIds'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          (_merchantStore?['service_ids'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList() ??
          <String>[];
      if (serviceIds.isEmpty && category.isNotEmpty) {
        serviceIds = [category];
      }
      final openTime = _normalizeTimeForDb(
        _merchantStore?['openTime'] ?? _merchantStore?['open_time'],
      );
      final closeTime = _normalizeTimeForDb(
        _merchantStore?['closeTime'] ?? _merchantStore?['close_time'],
      );
      if (openTime != null) {
        _merchantStore!['openTime'] = openTime;
        _merchantStore!['open_time'] = openTime;
      }
      if (closeTime != null) {
        _merchantStore!['closeTime'] = closeTime;
        _merchantStore!['close_time'] = closeTime;
      }
      final showPhoneToCustomers =
          MerchantProfileFields.showPhoneToCustomers(_merchantStore);
      final showWhatsAppToCustomers =
          MerchantProfileFields.showWhatsAppToCustomers(_merchantStore);
      final contactVisibility = <String, dynamic>{
        'showPhoneToCustomers': showPhoneToCustomers,
        'showWhatsAppToCustomers': showWhatsAppToCustomers,
        'show_phone_to_customers': showPhoneToCustomers,
        'show_whatsapp_to_customers': showWhatsAppToCustomers,
      };
      final professionalInfoRaw = _merchantStore?['professionalInfo'] ??
          _merchantStore?['professional_info'];
      final professionalInfo = professionalInfoRaw is Map
          ? Map<String, dynamic>.from(professionalInfoRaw)
          : <String, dynamic>{};
      final existingVisibility = professionalInfo['contact_visibility'] ??
          professionalInfo['contactVisibility'];
      final visibilityMap = existingVisibility is Map
          ? <String, dynamic>{
              ...Map<String, dynamic>.from(existingVisibility),
              ...contactVisibility,
            }
          : contactVisibility;
      professionalInfo['contact_visibility'] = visibilityMap;
      professionalInfo['contactVisibility'] = visibilityMap;
      _merchantStore!['showPhoneToCustomers'] = showPhoneToCustomers;
      _merchantStore!['showWhatsAppToCustomers'] = showWhatsAppToCustomers;
      _merchantStore!['show_phone_to_customers'] = showPhoneToCustomers;
      _merchantStore!['show_whatsapp_to_customers'] = showWhatsAppToCustomers;
      _merchantStore!['professionalInfo'] = professionalInfo;

      await SupabaseService.saveMerchantProfile(phone, {
        'store_name': _merchantStore?['name'],
        'description': _merchantStore?['description'],
        'primary_service_id': category.isNotEmpty
            ? category
            : _merchantStore?['primary_service_id'] ??
                _merchantStore?['primaryServiceId'],
        'whatsapp': _normalizeStoredPhone(
            _merchantStore?['whatsapp']?.toString() ?? ''),
        'address': MerchantProfileFields.addressFromMap(_merchantStore),
        'latitude': _merchantStore?['latitude'] ?? _merchantStore?['lat'],
        'longitude': _merchantStore?['longitude'] ?? _merchantStore?['lng'],
        if (openTime != null) 'open_time': openTime,
        if (closeTime != null) 'close_time': closeTime,
        'delivery_areas': _merchantStore?['deliveryAreas'] ??
            _merchantStore?['delivery_areas'],
        'delivery_fee':
            _merchantStore?['deliveryFee'] ?? _merchantStore?['delivery_fee'],
        'is_open':
            _merchantStore?['isOpen'] ?? _merchantStore?['is_open'] ?? true,
        'service_ids': serviceIds,
        'active_service_id': _merchantStore?['activeServiceId'],
        'restaurant_category': _merchantStore?['restaurantCategory'],
        'professional_category_id': _merchantStore?['professionalCategoryId'],
        'professional_info': professionalInfo,
        'show_phone_to_customers': showPhoneToCustomers,
        'show_whatsapp_to_customers': showWhatsAppToCustomers,
        'work_sample_images_base64':
            _merchantStore?['workSampleImagesBase64'] ??
                _merchantStore?['work_sample_images_base64'],
        'product_sections': MerchantProductSections.toPayload(
          merchantProductSections,
        ),
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
        if (_merchantStore?['isApproved'] != null)
          'is_approved': _merchantStore?['isApproved'] == true,
        if (_merchantStore?['approvalStatus'] != null)
          'approval_status': _merchantStore?['approvalStatus']?.toString(),
        if (_merchantStore?['rejectionReasonKey'] != null)
          'rejection_reason_key':
              _merchantStore?['rejectionReasonKey']?.toString(),
        if (_merchantStore?['rejectionMessageAr'] != null)
          'rejection_message_ar':
              _merchantStore?['rejectionMessageAr']?.toString(),
      });
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
    try {
      await _ensureMerchantProfileSynced();
    } catch (error) {
      debugPrint('MERCHANT_PROFILE_SYNC_SKIPPED_WHILE_SAVING_ITEMS: $error');
      // لا نوقف مزامنة المنتجات إذا تعذر حفظ بيانات المتجر.
    }
    final phone = _normalizeStoredPhone(_authPhone ?? merchantPhone);
    if (phone.isNotEmpty) {
      for (final item in _items) {
        await SupabaseService.saveMerchantProduct(
            phone, _productRowFromListItem(item));
      }
    }
    final statePhone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (statePhone != null) {
      await SupabaseService.saveUserState(statePhone, _buildRemoteState());
    }
    await _persistLocalBackup();
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
    _notificationHub.onMerchantReviewReplied(reviewId);
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
    final wasApproved = DriverProfileFields.isApproved(_driverProfile);
    final normalized = Map<String, dynamic>.from(profile);
    normalized['type'] = 'taxi';
    normalized['services'] = {'taxi': true, 'delivery': false};
    _driverType = 'taxi';
    normalized.remove('isApproved');
    normalized.remove('approvalStatus');
    normalized.remove('rejectionReasonKey');
    normalized.remove('rejectionMessageAr');
    normalized.remove('rejectedAt');

    _driverProfile = {
      ...?_driverProfile,
      ...normalized,
      'isApproved': wasApproved,
    };
    if (!wasApproved) {
      _driverProfile!['approvalStatus'] = 'pending';
      _driverProfile!.remove('rejectionReasonKey');
      _driverProfile!.remove('rejectionMessageAr');
      _driverProfile!.remove('rejectedAt');
    }
    if (_authPhone != null && _authPhone!.isNotEmpty) {
      await SupabaseService.saveUserState(_authPhone!, _buildRemoteState());
    }
    notifyListeners();
  }

  Future<void> setCourierProfile(Map<String, dynamic> profile) async {
    final wasApproved = CourierProfileFields.isApproved(_courierProfile);
    final next = Map<String, dynamic>.from(profile);
    next.remove('isApproved');
    next.remove('approvalStatus');
    next.remove('rejectionReasonKey');
    next.remove('rejectionMessageAr');
    next.remove('rejectedAt');
    _courierProfile = {
      ...?_courierProfile,
      ...next,
      'isApproved': wasApproved,
    };
    if (!wasApproved) {
      _courierProfile!['approvalStatus'] = 'pending';
      _courierProfile!.remove('rejectionReasonKey');
      _courierProfile!.remove('rejectionMessageAr');
      _courierProfile!.remove('rejectedAt');
    }
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

  Future<void> _ensureMerchantProfileSynced() async {
    if (_merchantStore == null || merchantStoreName.isEmpty) return;
    await _persistMerchantStore();
  }

  Future<void> _syncMerchantDataBeforeLeavingMerchantMode() async {
    if (_merchantStore == null && _items.isEmpty) return;
    try {
      await _ensureMerchantProfileSynced();
      if (_items.isNotEmpty) {
        await _persistMerchantItems();
      }
    } catch (error) {
      debugPrint('MERCHANT_SYNC_BEFORE_SWITCH_ERROR: $error');
      rethrow;
    }
  }

  /// يرفع بيانات المتجر والمنتجات إلى السحابة ليظهرها الزبون.
  Future<void> syncMerchantCatalogToCloud() async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null) {
      throw StateError('لا يوجد رقم هاتف مرتبط بالجلسة. أعد تسجيل الدخول.');
    }
    if (_sessionToken == null || _sessionToken!.trim().isEmpty) {
      throw StateError('جلسة الدخول منتهية أو غير متاحة. أعد تسجيل الدخول.');
    }
    try {
      await _syncMerchantDataBeforeLeavingMerchantMode();
      _notificationHub.onMerchantCatalogSynced();
    } catch (error) {
      _notificationHub.onMerchantCatalogSyncFailed(error.toString());
      rethrow;
    }
  }

  Future<void> setMerchantStore(Map<String, dynamic> storeData) async {
    final wasApproved = MerchantProfileFields.isApproved(_merchantStore);
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
    final latitude = _toDoubleValue(storeData['latitude']) ??
        _toDoubleValue(storeData['lat']);
    final longitude = _toDoubleValue(storeData['longitude']) ??
        _toDoubleValue(storeData['lng']);
    final nextStore = {
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
      'address': MerchantProfileFields.addressFromMap(storeData).isNotEmpty
          ? MerchantProfileFields.addressFromMap(storeData)
          : (storeData['address'] as String?)?.trim() ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'openTime': MerchantProfileFields.formatTimeDisplay(
              storeData['openTime'] ?? storeData['open_time']) ??
          '',
      'closeTime': MerchantProfileFields.formatTimeDisplay(
              storeData['closeTime'] ?? storeData['close_time']) ??
          '',
      'open_time': MerchantProfileFields.formatTimeDisplay(
        storeData['openTime'] ?? storeData['open_time'],
      ),
      'close_time': MerchantProfileFields.formatTimeDisplay(
        storeData['closeTime'] ?? storeData['close_time'],
      ),
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
      'restaurantCategory': storeData['restaurantCategory']?.toString(),
      if (storeData['professionalCategoryId'] != null)
        'professionalCategoryId': storeData['professionalCategoryId'],
      if (storeData['professionalInfo'] is Map &&
          (storeData['professionalInfo'] as Map)['professionId'] != null)
        'professionalCategoryId':
            (storeData['professionalInfo'] as Map)['professionId'],
      ...storeData,
    };
    _merchantStore = {
      ...nextStore,
      'isApproved': wasApproved,
    };
    if (!wasApproved) {
      _merchantStore!['approvalStatus'] = 'pending';
      _merchantStore!.remove('rejectionReasonKey');
      _merchantStore!.remove('rejectionMessageAr');
      _merchantStore!.remove('rejectedAt');
      _merchantStore!.remove('rejection_reason_key');
      _merchantStore!.remove('rejection_message_ar');
      _merchantStore!.remove('rejected_at');
    } else {
      _merchantStore!['approvalStatus'] = 'approved';
    }
    notifyListeners();
    await _persistMerchantStoreAndState();
  }

  Future<void> setMerchantProductSections(
    List<MerchantProductSection> sections,
  ) async {
    if (_merchantStore == null) return;
    final payload = MerchantProductSections.toPayload(sections);
    _merchantStore = {
      ..._merchantStore!,
      'productSections': payload,
      'product_sections': payload,
    };
    notifyListeners();
    await _persistMerchantStoreAndState();
  }

  int merchantProductsInSection(String sectionId) {
    final target = sectionId.trim();
    if (target.isEmpty) return 0;
    return merchantItems
        .where(
          (item) =>
              item.category == 'product' && (item.sectionId ?? '') == target,
        )
        .length;
  }

  void updateMerchantStore(Map<String, dynamic> updates) {
    if (_merchantStore == null) return;
    final normalized = Map<String, dynamic>.from(updates);
    if (normalized['productSections'] is List ||
        normalized['product_sections'] is List) {
      final parsed = MerchantProductSections.parseList(
        normalized['productSections'] ?? normalized['product_sections'],
      );
      final payload = MerchantProductSections.toPayload(parsed);
      normalized['productSections'] = payload;
      normalized['product_sections'] = payload;
    }
    final address = normalized['address']?.toString().trim();
    if (address != null && address.isNotEmpty) {
      normalized['address'] = address;
    }
    final open = MerchantProfileFields.normalizeTimeForPersistence(
      normalized['openTime'] ?? normalized['open_time'],
    );
    final close = MerchantProfileFields.normalizeTimeForPersistence(
      normalized['closeTime'] ?? normalized['close_time'],
    );
    if (open != null) {
      normalized['openTime'] = open;
      normalized['open_time'] = open;
    }
    if (close != null) {
      normalized['closeTime'] = close;
      normalized['close_time'] = close;
    }
    _merchantStore = {
      ..._merchantStore!,
      ...normalized,
    };
    if (MerchantProfileFields.isRejected(_merchantStore)) {
      _merchantStore!['isApproved'] = false;
      _merchantStore!['approvalStatus'] = 'pending';
      _merchantStore!.remove('rejectionReasonKey');
      _merchantStore!.remove('rejectionMessageAr');
      _merchantStore!.remove('rejectedAt');
      _merchantStore!.remove('rejection_reason_key');
      _merchantStore!.remove('rejection_message_ar');
      _merchantStore!.remove('rejected_at');
    }
    notifyListeners();
    unawaited(_persistMerchantStoreAndState());
  }

  void toggleMerchantOpenStatus() {
    if (_merchantStore == null) return;
    _merchantStore!['isOpen'] = !isMerchantStoreOpen;
    _notificationHub.onMerchantStoreOpenChanged(isMerchantStoreOpen);
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

  Future<void> addMerchantService(String serviceId) async {
    if (_merchantStore == null) return;
    final normalized = serviceId.trim();
    if (normalized.isEmpty) return;
    final current = merchantServiceIds;
    if (current.contains(normalized)) {
      await setMerchantActiveService(normalized);
      return;
    }
    final updated = <String>[...current, normalized];
    _merchantStore!['serviceIds'] = updated;
    _merchantStore!['activeServiceId'] = normalized;
    final existingCategory =
        (_merchantStore?['category'] as String?)?.trim() ?? '';
    _merchantStore!['category'] =
        existingCategory.isNotEmpty ? existingCategory : updated.first;
    notifyListeners();
    await _persistMerchantStoreAndState();
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
  int get merchantPendingOrdersCount =>
      _merchantIncomingOrders.where((o) => o.statusKey == 'pending').length;
  int get merchantActiveOrdersCount => _merchantIncomingOrders
      .where((o) =>
          o.statusKey == 'accepted' ||
          o.statusKey == 'preparing' ||
          o.statusKey == 'delivering')
      .length;
  int get merchantCompletedOrdersCount =>
      _merchantIncomingOrders.where((o) => o.statusKey == 'completed').length;
  int get merchantAcceptedOrdersCount => _merchantIncomingOrders
      .where((o) => o.statusKey == 'accepted' || o.statusKey == 'completed')
      .length;
  int get merchantRejectedOrdersCount =>
      _merchantIncomingOrders.where(_isMerchantRejectedOrder).length;
  int get merchantDecidedOrdersCount =>
      merchantAcceptedOrdersCount + merchantRejectedOrdersCount;
  double get merchantAcceptanceRate => merchantDecidedOrdersCount == 0
      ? 0
      : (merchantAcceptedOrdersCount / merchantDecidedOrdersCount) * 100;
  double get merchantRejectionRate => merchantDecidedOrdersCount == 0
      ? 0
      : (merchantRejectedOrdersCount / merchantDecidedOrdersCount) * 100;
  double get merchantAverageResponseMinutes {
    final minutes = _merchantIncomingOrders
        .map(_orderResponseMinutes)
        .whereType<double>()
        .toList();
    if (minutes.isEmpty) return 0;
    final total = minutes.fold<double>(0, (sum, value) => sum + value);
    return total / minutes.length;
  }

  bool _isMerchantRejectedOrder(ActiveOrder order) {
    if (order.statusKey != 'cancelled') return false;
    final noteAr = order.noteAr.trim();
    final noteEn = order.noteEn.trim();
    return noteAr.startsWith('سبب الرفض:') ||
        noteEn.startsWith('Rejected reason:');
  }

  double? _orderResponseMinutes(ActiveOrder order) {
    final isMerchantDecision = order.statusKey == 'accepted' ||
        order.statusKey == 'completed' ||
        _isMerchantRejectedOrder(order);
    if (!isMerchantDecision) return null;
    final decisionRaw = order.merchantDecisionAt?.trim();
    if (decisionRaw == null || decisionRaw.isEmpty) return null;
    final createdAt = _parseOrderCreatedAt(order);
    final decisionAt = DateTime.tryParse(decisionRaw)?.toLocal();
    if (createdAt == null || decisionAt == null) return null;
    final diff = decisionAt.difference(createdAt);
    if (diff.isNegative) return null;
    return diff.inSeconds / 60.0;
  }

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
      'service_id': item.category,
      'sub_category': item.subCategory,
      if (item.sectionId != null && item.sectionId!.trim().isNotEmpty)
        'section_id': item.sectionId!.trim(),
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
      'is_approved': item.isApproved,
    };
  }

  ListItem _listItemFromCatalogRow(Map<String, dynamic> row) {
    return _listItemFromProductRow(row).copyWith(
      merchantPhone:
          row['merchant_phone']?.toString() ?? row['phone']?.toString(),
      merchantWhatsApp: row['merchant_customer_whatsapp']?.toString() ??
          row['merchant_whatsapp']?.toString(),
      merchantShowPhoneToCustomers: row['merchant_show_phone_to_customers'] is bool
          ? row['merchant_show_phone_to_customers'] as bool
          : null,
      merchantShowWhatsAppToCustomers:
          row['merchant_show_whatsapp_to_customers'] is bool
              ? row['merchant_show_whatsapp_to_customers'] as bool
              : null,
      merchantStoreName: row['merchant_store_name']?.toString() ?? '',
      address:
          row['merchant_address']?.toString() ?? row['address']?.toString(),
      merchantLatitude: _toDoubleValue(row['merchant_latitude']) ??
          _toDoubleValue(row['latitude']),
      merchantLongitude: _toDoubleValue(row['merchant_longitude']) ??
          _toDoubleValue(row['longitude']),
      merchantOpenTime: MerchantProfileFields.formatTimeDisplay(
        row['merchant_open_time'] ?? row['open_time'],
      ),
      merchantCloseTime: MerchantProfileFields.formatTimeDisplay(
        row['merchant_close_time'] ?? row['close_time'],
      ),
      merchantIsOpen: row['merchant_is_open'] is bool
          ? row['merchant_is_open'] as bool
          : (row['merchant_is_open']?.toString().toLowerCase() == 'true'
              ? true
              : null),
      merchantIsFrozen: row['merchant_is_frozen'] is bool
          ? row['merchant_is_frozen'] as bool
          : (row['merchant_is_frozen']?.toString().toLowerCase() == 'true'
              ? true
              : null),
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
      sectionId: row['section_id']?.toString() ?? row['sectionId']?.toString(),
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
      isApproved: (row['is_approved'] as bool?) ?? true,
    );
  }

  List<ListItem> get items => isCustomer ? _catalogItems : _items;
  MarketplaceStatsSnapshot? get marketplaceStats => _marketplaceStats;
  bool get marketplaceStatsLoading => _marketplaceStatsLoading;
  List<ActiveOrder> get merchantIncomingOrders =>
      List<ActiveOrder>.unmodifiable(_merchantIncomingOrders);
  List<CartItem> get cart => _cart;
  List<ActiveOrder> get orders => _orders;
  int get customerActiveOrdersCount => _orders
      .where(
        (order) =>
            order.statusKey != 'completed' &&
            order.statusKey != 'rejected' &&
            order.statusKey != 'cancelled',
      )
      .length;
  List<TaxiRequest> get taxiRequests => _taxiRequests;
  List<String> get addresses => List<String>.unmodifiable(_addresses);
  List<AppNotificationItem> get notifications {
    final audience = notificationAudienceForRole(_userRole);
    if (audience == null) {
      return const [];
    }
    return List<AppNotificationItem>.unmodifiable(
      _notifications.where((n) => n.audience == audience),
    );
  }

  int get unreadNotificationCount {
    final audience = notificationAudienceForRole(_userRole);
    if (audience == null) return 0;
    return _notifications
        .where((n) => n.audience == audience && !n.read)
        .length;
  }

  List<AppNotificationItem> unreadNotificationsForRole(String role) {
    return _notifications.where((n) => n.audience == role && !n.read).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  String? takePendingUnreadPromptRole() {
    final role = _pendingUnreadPromptRole;
    _pendingUnreadPromptRole = null;
    return role;
  }

  void _queueUnreadPromptForRole(String role) {
    if (!_inAppAlertsEnabled) return;
    if (unreadNotificationsForRole(role).isEmpty) return;
    _pendingUnreadPromptRole = role;
  }

  String displayOrderNumber(ActiveOrder order) {
    final raw = order.orderNumber.trim();
    if (raw.isNotEmpty && raw.length <= 14) return raw;
    final idSeed = order.id.split('-').first;
    final seed = int.tryParse(idSeed);
    if (seed == null) return raw.isNotEmpty ? raw : order.id;
    final short = (seed % 1000000).toString().padLeft(6, '0');
    return '#$short';
  }

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

  int? _pendingMainTab;

  void requestMainShellTab(int index) {
    if (index < 0) return;
    _pendingMainTab = index;
    notifyListeners();
  }

  int? takePendingMainTab() {
    final tab = _pendingMainTab;
    _pendingMainTab = null;
    return tab;
  }

  void goToCustomerHomeTab() {
    resetHome();
    requestMainShellTab(0);
  }

  void toggleFavorite(String id) {
    final target = isCustomer ? _catalogItems : _items;
    final index = target.indexWhere((item) => item.id == id);
    if (index != -1) {
      toggleFavoriteItem(target[index]);
      return;
    }

    if (!_favoriteItemIds.contains(id)) return;
    _favoriteItemIds.remove(id);
    if (_authPhone != null && _authPhone!.isNotEmpty) {
      unawaited(SupabaseService.saveCustomerFavorite(
        _authPhone!,
        id,
        isFavorite: false,
      ));
    }
    notifyListeners();
  }

  bool isFavoriteId(String id) => _favoriteItemIds.contains(id);

  ListItem listItemFromStoreProduct(
    Map<String, dynamic> product,
    Map<String, dynamic> profile,
  ) {
    final visiblePhone = MerchantProfileFields.customerVisiblePhone(profile);
    final visibleWhatsApp = MerchantProfileFields.customerVisibleWhatsApp(profile);
    final showPhone = MerchantProfileFields.showPhoneToCustomers(profile);
    final showWhatsApp = MerchantProfileFields.showWhatsAppToCustomers(profile);
    final row = Map<String, dynamic>.from(product)
      ..['merchant_phone'] = profile['phone']?.toString()
      ..['merchant_whatsapp'] = visibleWhatsApp
      ..['merchant_customer_phone'] = visiblePhone
      ..['merchant_customer_whatsapp'] = visibleWhatsApp
      ..['merchant_show_phone_to_customers'] = showPhone
      ..['merchant_show_whatsapp_to_customers'] = showWhatsApp
      ..['merchant_store_name'] = profile['store_name']?.toString() ?? ''
      ..['merchant_address'] = MerchantProfileFields.addressFromMap(profile)
      ..['merchant_open_time'] =
          MerchantProfileFields.timeFromMap(profile, isOpen: true)
      ..['merchant_close_time'] =
          MerchantProfileFields.timeFromMap(profile, isOpen: false)
      ..['merchant_latitude'] =
          profile['latitude'] ?? profile['lat'] ?? profile['merchant_latitude']
      ..['merchant_longitude'] = profile['longitude'] ??
          profile['lng'] ??
          profile['merchant_longitude']
      ..['merchant_open_time'] = profile['open_time']?.toString()
      ..['merchant_close_time'] = profile['close_time']?.toString()
      ..['merchant_is_open'] = profile['is_open']
      ..['merchant_is_frozen'] = profile['is_frozen'];
    final item = _listItemFromCatalogRow(row);
    return item.copyWith(isFavorite: _favoriteItemIds.contains(item.id));
  }

  void toggleFavoriteItem(ListItem item) {
    final target = isCustomer ? _catalogItems : _items;
    final id = item.id;
    final index = target.indexWhere((entry) => entry.id == id);
    final currentlyFavorite =
        index != -1 ? target[index].isFavorite : _favoriteItemIds.contains(id);
    final nextFavorite = !currentlyFavorite;

    if (index == -1) {
      if (isCustomer) {
        _catalogItems.add(item.copyWith(isFavorite: nextFavorite));
      }
    } else {
      target[index].isFavorite = nextFavorite;
    }

    if (nextFavorite) {
      _favoriteItemIds.add(id);
    } else {
      _favoriteItemIds.remove(id);
    }

    if (_authPhone != null && _authPhone!.isNotEmpty) {
      unawaited(SupabaseService.saveCustomerFavorite(
        _authPhone!,
        id,
        isFavorite: nextFavorite,
      ));
    }
    notifyListeners();
  }

  void toggleFavoriteStoreProduct(
    Map<String, dynamic> product,
    Map<String, dynamic> profile,
  ) {
    toggleFavoriteItem(listItemFromStoreProduct(product, profile));
  }

  bool _merchantProfileSupportsCart(Map<String, dynamic> profile) {
    final ids = <String>[
      ..._decodeStringList(profile['service_ids']),
      if (profile['service_id'] != null) profile['service_id'].toString(),
    ].map((e) => e.trim()).where((e) => e.isNotEmpty);
    return ids.any(MarketplaceCatalog.usesShoppingCart);
  }

  bool addToCart(ListItem item, {bool fromStoreListing = false}) {
    if (!fromStoreListing &&
        !MarketplaceCatalog.usesShoppingCart(item.category)) {
      return false;
    }
    if (item.merchantIsFrozen == true) {
      return false;
    }

    final isBazarItem = item.category == 'bazar_ghaith';

    final merchantPhone = _trimmedOrNull(item.merchantPhone);
    if (_cart.isNotEmpty && merchantPhone != null) {
      final firstItem = _cart.first;
      final existingMerchant = _trimmedOrNull(firstItem.merchantPhone);
      final isBazarCart = firstItem.category == 'bazar_ghaith';

      // إذا كان العنصر الحالي بازار، والسلة فيها بازار، نسمح بتعدد التجار
      if (isBazarItem && isBazarCart) {
        // مسموح
      } else {
        // النظام القديم: تاجر واحد فقط
        if (existingMerchant != null && existingMerchant != merchantPhone) {
          return false;
        }
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
        descriptionAr: item.descriptionAr,
        descriptionEn: item.descriptionEn,
        merchantPhone: item.merchantPhone,
        merchantStoreName: item.merchantStoreName,
        merchantAddress: MerchantProfileFields.addressFromMap({
          'address': item.address,
          'merchant_address': item.address,
        }).isNotEmpty
            ? item.address
            : merchantAddress,
        merchantLatitude: item.merchantLatitude,
        merchantLongitude: item.merchantLongitude,
        merchantOpenTime: (item.merchantOpenTime ?? '').trim().isNotEmpty
            ? item.merchantOpenTime
            : merchantOpenTime,
        merchantCloseTime: (item.merchantCloseTime ?? '').trim().isNotEmpty
            ? item.merchantCloseTime
            : merchantCloseTime,
        merchantIsOpen: item.merchantIsOpen,
        merchantIsFrozen: item.merchantIsFrozen,
      ));
    }
    _touchCartActivity();
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
    if (!_merchantProfileSupportsCart(profile)) {
      return false;
    }
    return addToCart(
      listItemFromStoreProduct(product, profile),
      fromStoreListing: true,
    );
  }

  void incrementCartItem(String id) {
    final index = _cart.indexWhere((i) => i.id == id);
    if (index != -1) {
      _cart[index].count++;
      _touchCartActivity();
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
    if (_cart.isEmpty) {
      _appliedCartPromo = null;
    } else {
      _touchCartActivity();
    }
    notifyListeners();
  }

  void clearCart() {
    if (_cart.isEmpty) return;
    _cart.clear();
    _appliedCartPromo = null;
    _lastCartActivityMs = 0;
    _customerTimerEmitted.remove('cart_abandoned');
    notifyListeners();
  }

  bool reorderFromPreviousOrder(ActiveOrder order) {
    final merchant = _trimmedOrNull(order.merchantPhone);
    if (merchant == null || order.lineItems.isEmpty) return false;
    if (_hasActiveOrderForMerchant(merchant)) return false;
    if (_cart.isNotEmpty) {
      final existingMerchant = _trimmedOrNull(_cart.first.merchantPhone);
      if (existingMerchant != null && existingMerchant != merchant) {
        return false;
      }
    }
    final category = order.isRestaurantOrder ? 'restaurant' : 'product';
    for (var i = 0; i < order.lineItems.length; i++) {
      final line = order.lineItems[i];
      _cart.add(
        CartItem(
          id: 'reorder-${order.id}-$i',
          nameAr: line.nameAr,
          nameEn: line.nameEn,
          price: line.price,
          count: line.quantity,
          image: line.image ?? '',
          category: category,
          merchantPhone: order.merchantPhone,
          merchantStoreName: order.merchantStoreName,
        ),
      );
    }
    notifyListeners();
    return true;
  }

  int get cartTotal =>
      _cart.fold(0, (sum, item) => sum + (item.price * item.count));

  CartPromoDefinition? get appliedCartPromo => _appliedCartPromo;

  int get cartPromoDiscountIqd =>
      _appliedCartPromo?.discountForSubtotal(cartTotal) ?? 0;

  int get cartPayableTotal => cartTotal - cartPromoDiscountIqd;

  Future<CartPromoApplyResult> applyCartPromoCode(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      return const CartPromoApplyResult(
        success: false,
        messageAr: 'يرجى إدخال كود الخصم.',
      );
    }
    if (!SupabaseService.isConfigured) {
      return const CartPromoApplyResult(
        success: false,
        messageAr: 'الخدمة غير متاحة حالياً.',
      );
    }
    try {
      final row = await SupabaseService.validatePromoCode(
        code: normalized,
        subtotalIqd: cartTotal,
      );
      final valid = row['valid'] == true;
      if (!valid) {
        return CartPromoApplyResult(
          success: false,
          messageAr:
              row['messageAr']?.toString() ?? 'كود الخصم غير صحيح أو منتهي.',
        );
      }
      final promo = CartPromoDefinition.fromMap(row);
      _appliedCartPromo = promo;
      final discount = promo.discountForSubtotal(cartTotal);
      _notificationHub.onPromoApplied(promo.code, discount);
      notifyListeners();
      return CartPromoApplyResult(
        success: true,
        messageAr: 'تم تطبيق ${promo.labelAr} بنجاح.',
        promo: promo,
        discountAmountIqd: discount,
      );
    } catch (error) {
      debugPrint('PROMO_VALIDATE_ERROR: $error');
      return const CartPromoApplyResult(
        success: false,
        messageAr: 'تعذر التحقق من كود الخصم. حاول مجدداً.',
      );
    }
  }

  void clearCartPromo() {
    if (_appliedCartPromo == null) return;
    _appliedCartPromo = null;
    notifyListeners();
  }

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

  String _emitNotification({
    required String title,
    required String body,
    required String audience,
    String? orderNumber,
    NotificationCategory category = NotificationCategory.system,
    NotificationPriority priority = NotificationPriority.normal,
    String? eventKey,
  }) {
    return addNotification(
      title,
      body,
      audience: audience,
      orderNumber: orderNumber,
      category: category,
      priority: priority,
      eventKey: eventKey,
    );
  }

  String addNotification(
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
    unawaited(_persistLocalBackup());
    unawaited(_persistRemoteStateLight());
    return item.id;
  }

  void markNotificationRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0 || _notifications[index].read) return;
    _notifications[index] = _notifications[index].copyWith(read: true);
    notifyListeners();
    unawaited(_persistLocalBackup());
    unawaited(_persistRemoteStateLight());
  }

  void markNotificationsReadForOrder(String orderNumber, String audience) {
    var changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (n.audience == audience && !n.read && n.orderNumber == orderNumber) {
        _notifications[i] = n.copyWith(read: true);
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    unawaited(_persistLocalBackup());
    unawaited(_persistRemoteStateLight());
  }

  void markNotificationReadByTitleBody(
      String title, String body, String audience) {
    final index = _notifications.indexWhere(
      (n) =>
          n.audience == audience &&
          !n.read &&
          n.title == title &&
          n.body == body,
    );
    if (index < 0) return;
    markNotificationRead(_notifications[index].id);
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

  void _applyNotificationsFromState(dynamic raw) {
    if (raw is! List || raw.isEmpty) return;
    final parsed = <AppNotificationItem>[];
    for (final entry in raw) {
      if (entry is AppNotificationItem) {
        parsed.add(entry);
        continue;
      }
      if (entry is Map) {
        final map = Map<String, dynamic>.from(entry);
        if (map.containsKey('audience')) {
          parsed.add(AppNotificationItem.fromMap(map));
        } else {
          final audience = _userRole == 'merchant' ? 'merchant' : 'customer';
          parsed
              .add(AppNotificationItem.fromLegacyMap(map, audience: audience));
        }
      }
    }
    if (parsed.isEmpty) return;
    _notifications
      ..clear()
      ..addAll(parsed);
  }

  int get totalSales => _merchantIncomingOrders
      .where((o) => o.statusKey == 'accepted' || o.statusKey == 'delivering')
      .fold(0, (sum, item) => sum + item.price);

  int get productCount => _items.length;

  String _statusArFromKey(String statusKey) {
    switch (statusKey) {
      case 'pending':
        return 'بانتظار الموافقة';
      case 'accepted':
        return 'تمت الموافقة';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'cancel_requested':
        return 'طلب إلغاء بانتظار موافقة التاجر';
      default:
        return statusKey;
    }
  }

  String _statusEnFromKey(String statusKey) {
    switch (statusKey) {
      case 'pending':
        return 'Pending Approval';
      case 'accepted':
        return 'Approved';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'cancel_requested':
        return 'Cancellation Requested';
      default:
        return statusKey;
    }
  }

  bool requestCustomerOrderCancellation(String orderId) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return false;
    final order = _orders[index];
    if (order.statusKey == 'completed' ||
        order.statusKey == 'cancelled' ||
        order.statusKey == 'rejected' ||
        order.statusKey == 'cancel_requested') {
      return false;
    }

    if (order.statusKey == 'pending') {
      updateOrderStatus(
        orderId,
        'cancelled',
        'ملغي',
        'Cancelled',
        noteAr: 'تم إلغاء الطلب من الزبون قبل موافقة التاجر.',
        noteEn: 'Cancelled by customer before merchant approval.',
      );
      return true;
    }

    final noteEn = '__cancel_prev:${order.statusKey}__';
    updateOrderStatus(
      orderId,
      'cancel_requested',
      'طلب إلغاء بانتظار موافقة التاجر',
      'Cancellation requested',
      noteAr: 'تم إرسال طلب الإلغاء إلى التاجر بانتظار الموافقة.',
      noteEn: noteEn,
    );
    return true;
  }

  bool resolveCustomerCancellationRequestByMerchant(
    String orderId, {
    required bool approve,
  }) {
    final index =
        _merchantIncomingOrders.indexWhere((item) => item.id == orderId);
    if (index == -1) return false;
    final order = _merchantIncomingOrders[index];
    if (order.statusKey != 'cancel_requested') return false;

    final noteEn = order.noteEn;
    final match = RegExp(r'^__cancel_prev:([a-z_]+)__').firstMatch(noteEn);
    final previousStatus = match?.group(1) ?? 'pending';

    if (approve) {
      updateOrderStatus(
        orderId,
        'cancelled',
        'تم إلغاء الطلب بموافقة التاجر',
        'Cancelled by merchant approval',
        noteAr: 'تمت الموافقة على إلغاء الطلب.',
        noteEn: 'Merchant approved cancellation.',
      );
      return true;
    }

    final restoredStatus =
        previousStatus == 'accepted' || previousStatus == 'pending'
            ? previousStatus
            : 'pending';
    updateOrderStatus(
      orderId,
      restoredStatus,
      _statusArFromKey(restoredStatus),
      _statusEnFromKey(restoredStatus),
      noteAr: 'تم رفض طلب الإلغاء من التاجر.',
      noteEn: 'Merchant rejected cancellation request.',
    );
    return true;
  }

  Future<void> markMerchantOrderAsRead(String orderId) async {
    final index =
        _merchantIncomingOrders.indexWhere((item) => item.id == orderId);
    if (index == -1) return;
    final order = _merchantIncomingOrders[index];
    if (order.merchantReadAt != null &&
        order.merchantReadAt!.trim().isNotEmpty) {
      return;
    }
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
      deliveryStatusKey: order.deliveryStatusKey,
      deliveryStatusAr: order.deliveryStatusAr,
      deliveryStatusEn: order.deliveryStatusEn,
      assignedCourierName: order.assignedCourierName,
      isRestaurantOrder: order.isRestaurantOrder,
      merchantPhone: order.merchantPhone,
      merchantStoreName: order.merchantStoreName,
      requiresDelivery: order.requiresDelivery,
      codConfirmed: order.codConfirmed,
      deliveredAt: order.deliveredAt,
      estimatedArrivalMinutes: order.estimatedArrivalMinutes,
      estimatedArrivalAt: order.estimatedArrivalAt,
      courierPhone: order.courierPhone,
      customerLatitude: order.customerLatitude,
      customerLongitude: order.customerLongitude,
      createdAt: order.createdAt,
      merchantReadAt: DateTime.now().toIso8601String(),
      merchantDecisionAt: order.merchantDecisionAt,
      isPriceLocked: order.isPriceLocked,
    );
    _merchantIncomingOrders[index] = updated;
    notifyListeners();
    try {
      await SupabaseService.saveCustomerOrder(order.customerPhone, updated);
    } catch (error) {
      debugPrint('MARK_ORDER_READ_ERROR: $error');
    }
  }

  void _enqueuePendingOrderStatusSync({
    required String orderId,
    required String statusKey,
    required String statusAr,
    required String statusEn,
    String? noteAr,
    String? noteEn,
  }) {
    final existing = _pendingOrderStatusSyncQueue.indexWhere(
      (item) => item['orderId'] == orderId,
    );
    final payload = <String, dynamic>{
      'orderId': orderId,
      'statusKey': statusKey,
      'statusAr': statusAr,
      'statusEn': statusEn,
      'noteAr': noteAr,
      'noteEn': noteEn,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (existing >= 0) {
      _pendingOrderStatusSyncQueue[existing] = payload;
    } else {
      _pendingOrderStatusSyncQueue.add(payload);
    }
    unawaited(_persistLocalBackup());
  }

  Future<void> _flushPendingOrderStatusSyncQueue() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null || _pendingOrderStatusSyncQueue.isEmpty) return;
    final pending =
        List<Map<String, dynamic>>.from(_pendingOrderStatusSyncQueue);
    for (final item in pending) {
      try {
        await SupabaseService.updateIncomingOrderStatus(
          phone,
          item['orderId']?.toString() ?? '',
          statusKey: item['statusKey']?.toString() ?? 'pending',
          statusAr: item['statusAr']?.toString() ?? '',
          statusEn: item['statusEn']?.toString() ?? '',
          noteAr: item['noteAr']?.toString(),
          noteEn: item['noteEn']?.toString(),
        );
        _pendingOrderStatusSyncQueue.removeWhere(
          (queued) => queued['orderId'] == item['orderId'],
        );
      } catch (_) {
        // نبقي العنصر في الطابور ونعيد المحاولة لاحقًا.
      }
    }
    await _persistLocalBackup();
  }

  void updateOrderStatus(
    String orderId,
    String newStatusKey,
    String statusAr,
    String statusEn, {
    String? noteAr,
    String? noteEn,
  }) {
    final list = isMerchant ? _merchantIncomingOrders : _orders;
    final index = list.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = list[index];
    final previousStatus = order.statusKey;
    final nowIso = DateTime.now().toIso8601String();
    final isDecisionStatus =
        newStatusKey == 'accepted' || newStatusKey == 'cancelled';
    final lockPrice = order.isPriceLocked || newStatusKey == 'accepted';
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
      noteAr: noteAr ?? order.noteAr,
      noteEn: noteEn ?? order.noteEn,
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
      deliveredAt: order.deliveredAt,
      estimatedArrivalMinutes: order.estimatedArrivalMinutes,
      estimatedArrivalAt: order.estimatedArrivalAt,
      courierPhone: order.courierPhone,
      customerLatitude: order.customerLatitude,
      customerLongitude: order.customerLongitude,
      createdAt: order.createdAt,
      merchantReadAt: order.merchantReadAt,
      merchantDecisionAt: isDecisionStatus
          ? (order.merchantDecisionAt ?? nowIso)
          : order.merchantDecisionAt,
      isPriceLocked: lockPrice,
    );
    list[index] = updated;
    if (isMerchant) {
      _notificationHub.onMerchantOrderStatusChanged(
        updated,
        previousStatus,
        newStatusKey,
      );
      final phone = _trimmedOrNull(_authPhone);
      if (phone != null) {
        unawaited(
          SupabaseService.updateIncomingOrderStatus(
            phone,
            orderId,
            statusKey: newStatusKey,
            statusAr: statusAr,
            statusEn: statusEn,
            noteAr: noteAr,
            noteEn: noteEn,
          ).then((_) {
            _pendingOrderStatusSyncQueue
                .removeWhere((item) => item['orderId'] == orderId);
            unawaited(_persistLocalBackup());
            return _refreshMerchantIncomingOrders();
          }).catchError((_) {
            _enqueuePendingOrderStatusSync(
              orderId: orderId,
              statusKey: newStatusKey,
              statusAr: statusAr,
              statusEn: statusEn,
              noteAr: noteAr,
              noteEn: noteEn,
            );
          }),
        );
      }
    } else {
      unawaited(_persistCustomerOrder(updated));
    }
    notifyListeners();
  }

  Future<void> addProduct(ListItem item) async {
    assertCanPublishForService(item.category);
    if (item.category == 'bazar_ghaith' && !isBazaarApproved) {
      throw StateError(
        'يلزم حصولك على موافقة الإدارة قبل النشر داخل قسم بازار ومطاعم الغيث.',
      );
    }

    var finalItem = item;
    if (item.category == 'used') {
      // المنتجات المستعملة تحتاج موافقة الإدارة
      finalItem = item.copyWith(isApproved: false);
    }

    _items.insert(0, finalItem);
    notifyListeners();
    final phone = _normalizeStoredPhone(_authPhone ?? merchantPhone);
    if (phone.isEmpty) return;
    try {
      try {
        await _ensureMerchantProfileSynced();
      } catch (error) {
        debugPrint('MERCHANT_PROFILE_SYNC_SKIPPED_ON_ADD_PRODUCT: $error');
      }
      await SupabaseService.saveMerchantProduct(
        phone,
        _productRowFromListItem(finalItem),
      );
      final statePhone =
          _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
      if (statePhone != null) {
        await SupabaseService.saveUserState(statePhone, _buildRemoteState());
      }
      await _persistLocalBackup();
    } catch (error) {
      debugPrint('SAVE_PRODUCT_REMOTE_ERROR: $error');
      // لا نحذف المنتج محليًا حتى لا يشعر المستخدم أن زر الإضافة لا يعمل.
      // نحاول المزامنة لاحقًا في الخلفية.
      unawaited(_persistMerchantItems());
    }
  }

  void updateProduct(ListItem updatedItem) {
    final index = _items.indexWhere((item) => item.id == updatedItem.id);
    if (index == -1) return;
    final wasAvailable = _items[index].isAvailable;
    _items[index] = updatedItem;
    if (wasAvailable && !updatedItem.isAvailable) {
      _notificationHub.onProductUnavailable(updatedItem.nameAr);
    }
    unawaited(_persistMerchantItems());
    unawaited(_persistLocalBackup());
    notifyListeners();
  }

  void deleteProduct(String id) {
    _items.removeWhere((item) => item.id == id);
    if (_authPhone != null && _authPhone!.isNotEmpty) {
      unawaited(SupabaseService.deleteMerchantProduct(id, phone: _authPhone));
    }
    unawaited(_persistMerchantItems());
    unawaited(_persistLocalBackup());
    notifyListeners();
  }

  bool _hasActiveOrderForMerchant(String merchantPhone) {
    return _orders.any((order) {
      final sameMerchant =
          _trimmedOrNull(order.merchantPhone) == _trimmedOrNull(merchantPhone);
      if (!sameMerchant) return false;
      if (order.statusKey == 'pending') {
        final createdAt = _parseOrderCreatedAt(order);
        if (createdAt != null &&
            DateTime.now().difference(createdAt) >= _pendingApprovalTimeout) {
          return false;
        }
      }
      return _isOrderActiveStatus(order.statusKey);
    });
  }

  bool _isMerchantAcceptingForCartItem(CartItem item) {
    if (item.merchantIsFrozen == true) return false;
    return _isMerchantOpenNow(
      isOpenFlag: item.merchantIsOpen,
      openTime: item.merchantOpenTime,
      closeTime: item.merchantCloseTime,
    );
  }

  String _composeCheckoutNoteAr({
    required String customerNotes,
    required int deliveryFeeIqd,
    String? promoCode,
    required int promoDiscountIqd,
  }) {
    final parts = <String>[];
    if (customerNotes.isNotEmpty) parts.add(customerNotes);
    if (deliveryFeeIqd > 0) {
      parts.add('رسوم التوصيل: $deliveryFeeIqd د.ع');
    }
    if (promoDiscountIqd > 0 && (promoCode ?? '').isNotEmpty) {
      parts.add('كود الخصم $promoCode: -$promoDiscountIqd د.ع');
    }
    return parts.join('\n');
  }

  String _composeCheckoutNoteEn({
    required String customerNotes,
    required int deliveryFeeIqd,
    String? promoCode,
    required int promoDiscountIqd,
  }) {
    final parts = <String>[];
    if (customerNotes.isNotEmpty) parts.add(customerNotes);
    if (deliveryFeeIqd > 0) {
      parts.add('Delivery fee: $deliveryFeeIqd IQD');
    }
    if (promoDiscountIqd > 0 && (promoCode ?? '').isNotEmpty) {
      parts.add('Promo $promoCode: -$promoDiscountIqd IQD');
    }
    return parts.join('\n');
  }

  Future<int> checkout({
    int deliveryFeeIqd = 0,
    String? orderNotes,
  }) async {
    if (_cart.isEmpty) return 0;

    final customerPhone = _trimmedOrNull(_authPhone);
    if (customerPhone == null) {
      throw StateError(
        'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى قبل إتمام الطلب.',
      );
    }

    final promoDiscountTotal = cartPromoDiscountIqd;
    if (_appliedCartPromo != null && promoDiscountTotal <= 0) {
      throw StateError(
        'كود الخصم لم يعد ينطبق على السلة الحالية.',
      );
    }

    final grouped = <String, List<CartItem>>{};
    for (final item in _cart) {
      final key = _trimmedOrNull(item.merchantPhone) ?? 'unknown';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final effectiveCustomerPhone = customerPhone.isNotEmpty
        ? customerPhone
        : _trimmedOrNull(_customerPhone) ?? '';

    var createdCount = 0;
    var remainingPromoDiscount = promoDiscountTotal;
    final stagedOrders = <({ActiveOrder order, List<CartItem> items})>[];
    final trimmedNotes = orderNotes?.trim() ?? '';
    final promoCode = _appliedCartPromo?.code;

    for (final entry in grouped.entries) {
      final items = entry.value;
      if (items.isEmpty) continue;

      final subtotal =
          items.fold(0, (sum, item) => sum + (item.price * item.count));
      final merchantPhone = entry.key == 'unknown' ? null : entry.key;
      if (merchantPhone == null) {
        throw StateError(
          'تعذر تحديد التاجر. يرجى إعادة إضافة المنتجات والمحاولة مجددًا.',
        );
      }
      if (_hasActiveOrderForMerchant(merchantPhone)) {
        throw StateError(
          'لديك طلب نشط بالفعل من نفس المتجر. أكمل الطلب الحالي أولًا.',
        );
      }
      if (items.first.merchantIsFrozen == true) {
        throw StateError(
          'هذا الحساب مجمّد حالياً ولا يستقبل أي طلبات جديدة.',
        );
      }
      if (!_isMerchantAcceptingForCartItem(items.first)) {
        final service = items.first.category;
        if (service == 'restaurant') {
          throw StateError(
            'المطعم مغلق الآن ولا يستقبل الطلبات خارج أوقات العمل.',
          );
        }
        if (service == 'product') {
          throw StateError(
            'المتجر مغلق الآن ولا يستقبل طلبات التسوق خارج أوقات العمل.',
          );
        }
        throw StateError(
          'الخدمة مغلقة الآن ولا تستقبل الطلبات خارج أوقات العمل.',
        );
      }

      final merchantStoreName = items.first.merchantStoreName;
      final now = DateTime.now();
      final createdAtIso = now.toIso8601String();
      final idSeed = now.millisecondsSinceEpoch;
      final shortOrder = (idSeed % 1000000).toString().padLeft(6, '0');
      final orderId = _generateUuid();

      final finalAddressAr = _addresses.isNotEmpty
          ? _addresses.first
          : (_customerAddress.isNotEmpty
              ? _customerAddress
              : 'لم يتم تحديد الموقع');
      final finalAddressEn = _addresses.isNotEmpty
          ? _addresses.first
          : (_customerAddress.isNotEmpty
              ? _customerAddress
              : 'Location not set');

      final orderDeliveryFee = createdCount == 0 ? deliveryFeeIqd : 0;
      final orderPromoDiscount =
          createdCount == 0 ? remainingPromoDiscount.clamp(0, subtotal) : 0;
      remainingPromoDiscount -= orderPromoDiscount;
      final totalPrice = subtotal +
          (orderDeliveryFee > 0 ? orderDeliveryFee : 0) -
          orderPromoDiscount;
      final orderNoteAr = _composeCheckoutNoteAr(
        customerNotes: trimmedNotes,
        deliveryFeeIqd: orderDeliveryFee,
        promoCode: orderPromoDiscount > 0 ? promoCode : null,
        promoDiscountIqd: orderPromoDiscount,
      );
      final orderNoteEn = _composeCheckoutNoteEn(
        customerNotes: trimmedNotes,
        deliveryFeeIqd: orderDeliveryFee,
        promoCode: orderPromoDiscount > 0 ? promoCode : null,
        promoDiscountIqd: orderPromoDiscount,
      );
      final newOrder = ActiveOrder(
        id: orderId,
        orderNumber: '#$shortOrder',
        dateAr: 'الآن',
        dateEn: 'Just now',
        customerNameAr:
            _customerName.trim().isNotEmpty ? _customerName : 'زبون الغيث',
        customerNameEn: _customerName.trim().isNotEmpty
            ? _customerName
            : 'Al-Ghaith Customer',
        customerPhone: effectiveCustomerPhone,
        addressAr: finalAddressAr,
        addressEn: finalAddressEn,
        noteAr: orderNoteAr,
        noteEn: orderNoteEn,
        paymentMethodAr: 'نقداً عند الاستلام',
        paymentMethodEn: 'Cash on Delivery',
        statusKey: 'pending',
        statusAr: 'بانتظار الموافقة',
        statusEn: 'Pending Approval',
        price: totalPrice,
        itemsCount: items.length,
        itemsNameAr: items.map((e) => e.nameAr).join(' ، '),
        itemsNameEn: items.map((e) => e.nameEn).join(', '),
        lineItems: items
            .map(
              (item) => OrderLineItem(
                nameAr: item.nameAr,
                nameEn: item.nameEn,
                quantity: item.count,
                price: item.price,
                image: item.image,
              ),
            )
            .toList(),
        isRestaurantOrder: items.any((item) => item.category == 'restaurant'),
        requiresDelivery: true,
        codConfirmed: false,
        customerLatitude: _customerLatitude,
        customerLongitude: _customerLongitude,
        deliveryStatusKey: null,
        deliveryStatusAr: null,
        deliveryStatusEn: null,
        merchantPhone: merchantPhone,
        merchantStoreName: merchantStoreName,
        createdAt: createdAtIso,
        isPriceLocked: false,
      );

      stagedOrders.add((order: newOrder, items: List<CartItem>.from(items)));
      createdCount++;
    }

    final successfulOrders = <ActiveOrder>[];
    final successfulItemKeys = <String>{};
    final failedStores = <String>[];
    var hasFrozenStoreFailure = false;

    for (final staged in stagedOrders) {
      try {
        await SupabaseService.saveCustomerOrder(customerPhone, staged.order);
        successfulOrders.add(staged.order);
        successfulItemKeys.addAll(
          staged.items.map(
            (item) =>
                '${item.id}:${item.optionAr ?? ''}:${item.optionEn ?? ''}',
          ),
        );
      } catch (error) {
        debugPrint('CHECKOUT_SAVE_ERROR (${staged.order.id}): $error');
        if (error.toString().contains('MERCHANT_FROZEN')) {
          hasFrozenStoreFailure = true;
        }
        failedStores.add(
          _trimmedOrNull(staged.order.merchantStoreName) ?? 'المتجر المحدد',
        );
      }
    }

    if (successfulOrders.isNotEmpty) {
      final existingIds = {for (final order in _orders) order.id};
      for (final order in successfulOrders.reversed) {
        if (!existingIds.contains(order.id)) {
          _orders.insert(0, order);
        }
      }
      _cart.removeWhere(
        (item) => successfulItemKeys.contains(
          '${item.id}:${item.optionAr ?? ''}:${item.optionEn ?? ''}',
        ),
      );
      if (_cart.isEmpty) {
        _appliedCartPromo = null;
      }
      _notificationHub.onCheckoutSuccess(successfulOrders);
      notifyListeners();
    }

    if (hasFrozenStoreFailure &&
        failedStores.isNotEmpty &&
        successfulOrders.isEmpty) {
      throw StateError(
        'أحد الحسابات التي في سلتك مجمّد حالياً ولا يستقبل أي طلبات جديدة.',
      );
    }

    if (failedStores.isNotEmpty) {
      final storesLabel = failedStores.toSet().join('، ');
      throw StateError(
        successfulOrders.isEmpty
            ? 'تعذر حفظ الطلب في الخادم. لم يتم إرسال الطلب إلى $storesLabel، وما زالت المنتجات في السلة.'
            : 'تم إرسال بعض الطلبات فقط. تعذر حفظ الطلب إلى $storesLabel، وأبقينا المنتجات غير المرسلة في السلة لإعادة المحاولة.',
      );
    }

    return successfulOrders.length;
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
      final previousRole = _userRole;
      _userRole = role;
      if (previousRole != null && previousRole != role) {
        _queueUnreadPromptForRole(role);
        _notificationHub.onRoleSwitched(role, _roleLabelAr(role));
      }
      notifyListeners();
      await _persistLocalBackup();
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
      _queueUnreadPromptForRole(role);
      _notificationHub.onRoleSwitched(role, _roleLabelAr(role));
    }

    notifyListeners();
    await _persistLocalBackup();

    unawaited(
        _runRoleSwitchSideEffects(role: role, previousRole: previousRole));
    return true;
  }

  /// مزامنة وبيانات الدور بعد الانتقال — لا تُبطئ واجهة التحويل.
  Future<void> _runRoleSwitchSideEffects({
    required String role,
    required String? previousRole,
  }) async {
    try {
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
      }

      notifyListeners();
    } catch (error) {
      debugPrint('ROLE_SWITCH_BACKGROUND: $error');
    }
  }

  /// بعد إكمال إعداد التاجر — تأكد من حفظ الدور + المتجر في السحابة.
  Future<void> activateMerchantRole() async {
    // الحساب الموحّد (marketplace/delivery) يسمح بدور التاجر؛ التكسي فقط مستثنى.
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
    _cart = [];
    _items = [];
    _catalogItems = [];
    _orders = [];
    _merchantIncomingOrders = [];
    _courierPoolOrders = [];
    _courierAssignedOrders = [];
    _adminReports = null;
    _allCouriers = [];
    _taxiRequests = [];
    _addresses = [];
    _notifications.clear();
    _customerName = '';
    _customerPhone = '';
    _customerAddress = '';
    _customerLatitude = null;
    _customerLongitude = null;
    _customerAvatarBase64 = null;
    _favoriteItemIds.clear();

    unawaited(PushNotificationService.instance.unbindFromUser(phone: previousPhone));
    unawaited(
      AccountRepository.instance.clearSession(phone: previousPhone).then((_) {
        debugPrint('LOGOUT: Local session cleared.');
      }),
    );
    SupabaseService.setSessionToken(null);

    // العودة لوضع البداية
    _isReady = true;
    _isLoggingIn = false;
    notifyListeners();
  }

  Future<void> submitMerchantReview({
    required String orderId,
    required int stars,
    String? comment,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = _orders[index];
    final merchantPhone = _trimmedOrNull(order.merchantPhone);
    if (merchantPhone == null) return;

    final customerPhone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone) ?? '';
    if (customerPhone.isEmpty) return;

    await SupabaseService.submitMerchantReview(
      merchantPhone: merchantPhone,
      customerPhone: customerPhone,
      customerName: _customerName.isNotEmpty ? _customerName : 'زبون الغيث',
      orderId: orderId,
      stars: stars,
      comment: comment,
    );

    // تحديث الحالة محلياً لتعليم الطلب كـ "تم التقييم"
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
      deliveryStatusKey: order.deliveryStatusKey,
      deliveryStatusAr: order.deliveryStatusAr,
      deliveryStatusEn: order.deliveryStatusEn,
      assignedCourierName: order.assignedCourierName,
      isRestaurantOrder: order.isRestaurantOrder,
      merchantPhone: order.merchantPhone,
      merchantStoreName: order.merchantStoreName,
      requiresDelivery: order.requiresDelivery,
      codConfirmed: order.codConfirmed,
      deliveredAt: order.deliveredAt,
      estimatedArrivalMinutes: order.estimatedArrivalMinutes,
      estimatedArrivalAt: order.estimatedArrivalAt,
      courierPhone: order.courierPhone,
      customerLatitude: order.customerLatitude,
      customerLongitude: order.customerLongitude,
      createdAt: order.createdAt,
      merchantReadAt: order.merchantReadAt,
      merchantDecisionAt: order.merchantDecisionAt,
      isPriceLocked: order.isPriceLocked,
      isRated: true,
    );

    _orders[index] = updated;
    await _persistCustomerOrder(updated);
    notifyListeners();
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
          'cancel_requested',
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

  int _deliveryFeeFromOrder(ActiveOrder order) {
    final arMatch = RegExp(r'رسوم التوصيل:\s*(\d+)').firstMatch(order.noteAr);
    if (arMatch != null) {
      return int.tryParse(arMatch.group(1) ?? '') ?? 0;
    }
    final enMatch = RegExp(r'Delivery fee:\s*(\d+)').firstMatch(order.noteEn);
    if (enMatch != null) {
      return int.tryParse(enMatch.group(1) ?? '') ?? 0;
    }
    return 0;
  }

  int courierDeliveryFeeForOrder(ActiveOrder order) =>
      _deliveryFeeFromOrder(order);

  bool _isDeliveredWithinDays(ActiveOrder order, int days) {
    final deliveredAt = order.deliveredAt;
    if (deliveredAt == null || deliveredAt.trim().isEmpty) return false;
    final parsed = DateTime.tryParse(deliveredAt.trim());
    if (parsed == null) return false;
    final now = DateTime.now();
    if (days <= 1) {
      return DateUtils.isSameDay(parsed.toLocal(), now);
    }
    final diff = now.difference(parsed.toLocal());
    return !diff.isNegative && diff <= Duration(days: days);
  }

  int get courierTotalEarnings => deliveryCompletedOrders.fold<int>(
        0,
        (sum, order) => sum + _deliveryFeeFromOrder(order),
      );

  int get courierTodayEarnings => deliveryCompletedOrders
      .where((order) => _isDeliveredWithinDays(order, 1))
      .fold<int>(0, (sum, order) => sum + _deliveryFeeFromOrder(order));

  int get courierWeeklyEarnings => deliveryCompletedOrders
      .where((order) => _isDeliveredWithinDays(order, 7))
      .fold<int>(0, (sum, order) => sum + _deliveryFeeFromOrder(order));

  int get courierMonthlyEarnings => deliveryCompletedOrders
      .where((order) => _isDeliveredWithinDays(order, 30))
      .fold<int>(0, (sum, order) => sum + _deliveryFeeFromOrder(order));

  int get courierCompletedCount => deliveryCompletedOrders.length;

  Map<String, dynamic>? get adminReports => _adminReports;
  List<Map<String, dynamic>> _allMerchants = [];
  List<Map<String, dynamic>> _allCouriers = [];
  List<Map<String, dynamic>> get allMerchants =>
      List<Map<String, dynamic>>.unmodifiable(_allMerchants);
  List<Map<String, dynamic>> get allCouriers =>
      List<Map<String, dynamic>>.unmodifiable(_allCouriers);

  Future<void> refreshAllMerchants() async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      _allMerchants = await SupabaseService.loadAllMerchants();
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_MERCHANTS_ERROR: $error');
    }
  }

  Future<void> refreshAccountFromCloud() async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null) return;
    await _restoreRemoteSession(phone);
    notifyListeners();
  }

  void _notifyDriverApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  }) {
    if (!hasDriverProfile) return;

    final nowApproved = isDriverApproved;
    final nowRejected = DriverProfileFields.isRejected(_driverProfile);
    final rejectionMessage =
        DriverProfileFields.rejectionMessage(_driverProfile);

    if (nowApproved && !wasApproved) {
      _notificationHub.onDriverApproved();
      _queueUnreadPromptForRole('driver');
      return;
    }

    if (nowRejected &&
        (!wasRejected || rejectionMessage != previousRejectionMessage)) {
      _notificationHub.onDriverRejected(rejectionMessage);
      _queueUnreadPromptForRole('driver');
    }
  }

  void _notifyCourierApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  }) {
    if (!hasCourierProfile) return;

    final nowApproved = isCourierApproved;
    final nowRejected = CourierProfileFields.isRejected(_courierProfile);
    final rejectionMessage =
        CourierProfileFields.rejectionMessage(_courierProfile);

    if (nowApproved && !wasApproved) {
      _notificationHub.onCourierApproved();
      _queueUnreadPromptForRole('delivery');
      return;
    }

    if (nowRejected &&
        (!wasRejected || rejectionMessage != previousRejectionMessage)) {
      _notificationHub.onCourierRejected(rejectionMessage);
      _queueUnreadPromptForRole('delivery');
    }
  }

  Future<void> refreshCourierApprovalIfNeeded() async {
    if (_userRole != 'delivery' || !hasCourierProfile || isCourierApproved) {
      return;
    }
    await refreshAccountFromCloud();
  }

  Future<void> handleCourierStatusPush() async {
    if (_userRole != 'delivery' || !hasCourierProfile) return;
    await refreshAccountFromCloud();
  }

  Future<void> refreshAllCouriers() async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      _allCouriers = await SupabaseService.loadAllCouriers();
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_COURIERS_ERROR: $error');
    }
  }

  Future<void> rejectCourierApplication(
    String courierPhone,
    String reasonKey, {
    String? rejectionMessageAr,
  }) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      await SupabaseService.rejectCourierApplication(
        courierPhone: courierPhone,
        reasonKey: reasonKey,
        rejectionMessageAr: rejectionMessageAr,
      );
      await refreshAllCouriers();
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_REJECT_COURIER_ERROR: $error');
      rethrow;
    }
  }

  Future<void> toggleMerchantApproval(
    String merchantPhone,
    bool isApproved,
  ) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      await SupabaseService.toggleMerchantApprovalStatus(
        merchantPhone: merchantPhone,
        isApproved: isApproved,
      );
      final selfPhone = _trimmedOrNull(_authPhone);
      if (selfPhone != null &&
          PhoneUtils.variants(selfPhone).contains(
            PhoneUtils.normalize(merchantPhone),
          )) {
        await _restoreRemoteSession(selfPhone);
      }
      await refreshAllMerchants();
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_MERCHANT_APPROVAL_ERROR: $error');
      rethrow;
    }
  }

  Future<void> rejectMerchantApplication(
    String merchantPhone,
    String reasonKey, {
    String? rejectionMessageAr,
  }) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      await SupabaseService.rejectMerchantApplication(
        merchantPhone: merchantPhone,
        reasonKey: reasonKey,
        rejectionMessageAr: rejectionMessageAr,
      );
      final selfPhone = _trimmedOrNull(_authPhone);
      if (selfPhone != null &&
          PhoneUtils.variants(selfPhone).contains(
            PhoneUtils.normalize(merchantPhone),
          )) {
        await _restoreRemoteSession(selfPhone);
      }
      await refreshAllMerchants();
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_REJECT_MERCHANT_ERROR: $error');
      rethrow;
    }
  }

  Future<void> toggleCourierApproval(
    String courierPhone,
    bool isApproved,
  ) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      await SupabaseService.toggleCourierApprovalStatus(
        courierPhone: courierPhone,
        isApproved: isApproved,
      );
      final index =
          _allCouriers.indexWhere((c) => c['phone']?.toString() == courierPhone);
      if (index != -1) {
        _allCouriers[index] = Map<String, dynamic>.from(_allCouriers[index]);
        _allCouriers[index]['isApproved'] = isApproved;
      }
      final selfPhone = _trimmedOrNull(_authPhone);
      if (selfPhone != null &&
          PhoneUtils.variants(selfPhone).contains(
            PhoneUtils.normalize(courierPhone),
          )) {
        await _restoreRemoteSession(selfPhone);
      }
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_TOGGLE_COURIER_ERROR: $error');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> toggleMerchantBazaarMember(
      String merchantPhone, bool isBazaarMember) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return const {};
    try {
      final result = await SupabaseService.toggleMerchantBazaarStatus(
        merchantPhone: merchantPhone,
        isBazaarMember: isBazaarMember,
      );
      // تحديث الحالة محلياً
      final index =
          _allMerchants.indexWhere((m) => m['phone'] == merchantPhone);
      if (index != -1) {
        _allMerchants[index] = Map<String, dynamic>.from(_allMerchants[index]);
        _allMerchants[index]['isBazaarMember'] = isBazaarMember;
      }
      notifyListeners();
      return result;
    } catch (error) {
      debugPrint('ADMIN_TOGGLE_BAZAAR_ERROR: $error');
      rethrow;
    }
  }

  Future<void> toggleMerchantFrozen(String merchantPhone, bool isFrozen) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      await SupabaseService.toggleMerchantFreezeStatus(
        merchantPhone: merchantPhone,
        isFrozen: isFrozen,
      );
      final index =
          _allMerchants.indexWhere((m) => m['phone'] == merchantPhone);
      if (index != -1) {
        _allMerchants[index] = Map<String, dynamic>.from(_allMerchants[index]);
        _allMerchants[index]['isFrozen'] = isFrozen;
      }
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_TOGGLE_FREEZE_ERROR: $error');
      rethrow;
    }
  }

  List<ListItem> searchCatalogItems(String query) {
    final orderable = _catalogItems.where(
      (item) => MarketplaceCatalog.usesShoppingCart(item.category),
    );
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return List<ListItem>.unmodifiable(orderable);
    }
    return orderable.where((item) {
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
      final previous = _adminReports == null
          ? null
          : Map<String, dynamic>.from(_adminReports!);
      _adminReports = await SupabaseService.loadAdminReports(phone);
      _notificationHub.onAdminReportsUpdated(previous, _adminReports);
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_REPORTS_ERROR: $error');
    }
  }

  // ── إعداد أقسام الصفحة الرئيسية (يتحكّم فيه الأدمن عن بُعد) ──────────────
  Map<String, HomeCategoryPlatformOverride> _homeCategoryOverrides = {};

  Map<String, HomeCategoryPlatformOverride> get homeCategoryOverrides =>
      Map<String, HomeCategoryPlatformOverride>.unmodifiable(
        _homeCategoryOverrides,
      );

  /// الأقسام الظاهرة للزبون على المنصة الحالية.
  List<ServiceCategory> get visibleHomeCategories =>
      MarketplaceCatalog.homeCategoriesWithOverrides(
        _homeCategoryOverrides,
        platform: PlatformKey.current,
      );

  /// هل القسم مفعّل على المنصة الحالية (للزبون).
  bool isHomeCategoryEnabled(String categoryId) =>
      MarketplaceCatalog.isHomeCategoryEnabled(
        categoryId,
        overrides: _homeCategoryOverrides,
        platform: PlatformKey.current,
      );

  /// قيمة القسم على منصة محددة (للوحة الأدمن).
  bool homeCategoryEnabledOnPlatform(String categoryId, String platform) {
    final override = _homeCategoryOverrides[categoryId];
    if (override != null) {
      final value = override.isEnabledOn(platform);
      if (value != null) return value;
    }
    return MarketplaceCatalog.customerHomeCategoryIds.contains(categoryId);
  }

  Future<void> refreshHomeCategoriesConfig() async {
    if (!SupabaseService.isConfigured) return;
    try {
      final overrides = await SupabaseService.loadHomeCategoriesConfig();
      _homeCategoryOverrides = overrides;
      notifyListeners();
    } catch (error) {
      debugPrint('HOME_CATEGORIES_CONFIG_ERROR: $error');
    }
  }

  /// حفظ تفعيل/إطفاء قسم لمنصة محددة من لوحة الأدمن.
  Future<bool> setHomeCategoryPlatformEnabled(
    String categoryId,
    String platform,
    bool enabled,
  ) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null) return false;

    final previous =
        Map<String, HomeCategoryPlatformOverride>.from(_homeCategoryOverrides);
    final current = _homeCategoryOverrides[categoryId] ??
        const HomeCategoryPlatformOverride();
    final next = Map<String, HomeCategoryPlatformOverride>.from(
      _homeCategoryOverrides,
    )..[categoryId] = current.withPlatform(platform, enabled);
    _homeCategoryOverrides = next;
    notifyListeners();

    try {
      final saved = await SupabaseService.saveHomeCategoriesConfig(
        phone: phone,
        overrides: next,
      );
      _homeCategoryOverrides = saved;
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('HOME_CATEGORIES_SAVE_ERROR: $error');
      _homeCategoryOverrides = previous;
      notifyListeners();
      return false;
    }
  }

  List<ActiveOrder> get visibleDeliveryIncomingOrders => deliveryIncomingOrders;
  List<ActiveOrder> get visibleDeliveryActiveOrders => deliveryActiveOrders;
  List<ActiveOrder> get visibleDeliveryCompletedOrders =>
      deliveryCompletedOrders;

  void addTaxiRequest(TaxiRequest request) {
    _taxiRequests.insert(0, request);
    _notificationHub.onTaxiRequestCreated(request);
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
    _notificationHub.taxiBannersFromDiff(
      previousById: {request.id: request},
      current: [updated],
    );
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

  String? cancelTaxiRequestByCustomer(String requestId) {
    final index = _taxiRequests.indexWhere((item) => item.id == requestId);
    if (index == -1) return null;
    final request = _taxiRequests[index];

    if (request.statusKey == 'pending' || request.statusKey == 'new') {
      _updateTaxiRequest(
        requestId,
        'cancelled',
        'ملغي من الزبون',
        'Cancelled by customer',
      );
      return 'cancelled';
    }

    if (request.statusKey == 'accepted') {
      _updateTaxiRequest(
        requestId,
        'cancel_requested',
        'طلب إلغاء من الزبون',
        'Cancellation requested by customer',
      );
      return 'requested';
    }

    return null;
  }

  void approveTaxiCancellationByDriver(String requestId) => _updateTaxiRequest(
        requestId,
        'cancelled',
        'تمت الموافقة على الإلغاء',
        'Cancellation approved',
      );

  void rejectTaxiCancellationByDriver(String requestId) => _updateTaxiRequest(
        requestId,
        'accepted',
        'الرحلة مستمرة',
        'Trip continues',
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
      ActiveOrder? matched;
      for (final o in _courierPoolOrders) {
        if (o.id == orderId) {
          matched = o;
          break;
        }
      }
      if (matched == null) {
        for (final o in _courierAssignedOrders) {
          if (o.id == orderId) {
            matched = o;
            break;
          }
        }
      }
      _notificationHub.onCourierAcceptedOrder(
        matched?.orderNumber ?? orderId,
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
      ActiveOrder? matched;
      for (final o in _courierPoolOrders) {
        if (o.id == orderId) {
          matched = o;
          break;
        }
      }
      _courierPoolOrders.removeWhere((order) => order.id == orderId);
      _notificationHub.onCourierRejectedOrder(
        matched?.orderNumber ?? orderId,
      );
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
