import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/catalog/marketplace_catalog.dart';
import '../../core/storage/home_categories_cache.dart';
import '../../core/notifications/notification_hub.dart';
import '../../core/utils/phone_utils.dart';
import '../../models/app_models.dart';
import '../../models/app_notification.dart';
import '../../models/app_user_view.dart';
import '../../models/home_category_platform_override.dart';
import '../../models/merchant_models.dart';
import '../../models/merchant_store_view.dart';
import '../../services/supabase_service.dart';
import '../../services/image_storage_service.dart';
import '../../utils/merchant_service_labels.dart';
import '../../utils/platform_key.dart';
import '../../models/merchant_product_section.dart';
import '../../utils/merchant_product_sections.dart';
import '../../utils/courier_profile_fields.dart';
import '../../utils/driver_profile_fields.dart';
import '../../utils/merchant_profile_fields.dart';

mixin AppCoreMixin on ChangeNotifier {
  static const Duration _pendingApprovalTimeout = Duration(minutes: 20);
  String? _authPhone;
  String? _sessionToken;
  String? _driverType;
  Map<String, dynamic>? _driverProfile;
  Map<String, dynamic>? _courierProfile;
  String? _userRole;
  String? _accountType;
  bool _hasAdminAccess = false;
  Map<String, dynamic>? _appUserRecord;
  Map<String, dynamic>? _merchantStore;
  List<MerchantOffer> _merchantOffers = [];
  List<MerchantReview> _merchantReviews = [];
  List<ListItem> _items = [];
  List<ListItem> _catalogItems = [];
  DateTime? _lastCatalogFetch;
  MarketplaceStatsSnapshot? _marketplaceStats;
  bool _marketplaceStatsLoading = false;
  List<CartItem> _cart = [];
  CartPromoDefinition? _appliedCartPromo;
  List<ActiveOrder> _orders = [];
  DateTime? _lastOrdersFetch;
  List<ActiveOrder> _merchantIncomingOrders = [];
  List<ActiveOrder> _courierPoolOrders = [];
  List<ActiveOrder> _courierAssignedOrders = [];
  Map<String, dynamic>? _adminReports;
  List<TaxiRequest> _taxiRequests = [];
  List<TaxiRequest> _taxiPoolRequests = [];
  List<TaxiRequest> _taxiDriverAssignedRequests = [];
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

  int? _pendingMainTab;
  int? _pendingMerchantTab;
  int? _pendingDeliveryTab;
  int? _pendingDriverTab;

  String? _pendingOrderIdCustomer;
  String? _pendingOrderIdMerchant;
  String? _pendingOrderIdDelivery;
  String? _pendingOrderIdDriver;

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

  // ── Basic getters ─────────────────────────────────────────────
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
      if (parsed.isNotEmpty) return parsed;
    }
    final serviceIdsSnake = _merchantStore?['service_ids'];
    if (serviceIdsSnake is List) {
      final parsed = serviceIdsSnake
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) return parsed;
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
      (_merchantStore?['coverImageBase64'] as String?)?.trim() ?? '';
  String get merchantLogoImage =>
      (_merchantStore?['logoImage'] as String?)?.trim() ??
      (_merchantStore?['logo_image_url'] as String?)?.trim() ??
      (_merchantStore?['logoImageBase64'] as String?)?.trim() ?? '';
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
  double get merchantRating => (() {
        final storedRating = (_merchantStore?['rating'] as num?)?.toDouble();
        if (storedRating != null && storedRating > 0) return storedRating;
        return _averageMerchantRatingFromReviews();
      })();
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

  double _averageMerchantRatingFromReviews() {
    if (_merchantReviews.isEmpty) return 0.0;
    final validReviews =
        _merchantReviews.where((review) => review.stars > 0).toList();
    if (validReviews.isEmpty) return 0.0;
    final total =
        validReviews.fold<int>(0, (sum, review) => sum + review.stars);
    return total / validReviews.length;
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
  bool get canUseCourierAccount => hasCourierProfile && isCourierApproved;
  String get deliveryCourierName {
    final name = _courierProfile?['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    if (_customerName.trim().isNotEmpty) return _customerName.trim();
    return 'مندوب التوصيل';
  }

  String get driverDisplayName {
    final name = DriverProfileFields.name(_driverProfile);
    if (name.isNotEmpty) return name;
    if (_customerName.trim().isNotEmpty) return _customerName.trim();
    return 'سائق الغيث';
  }

  String get courierPhone {
    final phone = _courierProfile?['phone']?.toString().trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return _authPhone ?? _customerPhone;
  }

  bool get isCourierAvailable =>
      MerchantProfileFields.boolValue(_courierProfile?['available'],
          fallback: true);

  bool get isGuestMode => _isGuestMode;

  bool get driverAcceptsTaxi =>
      _userRole == 'driver' || _driverServiceEnabled('taxi');
  bool get driverAcceptsDelivery =>
      _userRole == 'driver' && _driverServiceEnabled('delivery');
  bool get driverAcceptsBoth =>
      _userRole == 'driver' &&
      _driverServiceEnabled('taxi') &&
      _driverServiceEnabled('delivery');
  String get driverServiceModeLabelAr {
    if (_userRole != 'driver') return '';
    if (driverAcceptsBoth) return 'سائق تكسي + توصيل';
    if (driverAcceptsDelivery) return 'سائق توصيل';
    return 'سائق تكسي';
  }
  String get driverServiceModeLabelEn {
    if (_userRole != 'driver') return '';
    if (driverAcceptsBoth) return 'Taxi + Delivery';
    if (driverAcceptsDelivery) return 'Delivery Driver';
    return 'Taxi Driver';
  }

  void setLanguage(String l) {}

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

  String? _normalizeTimeForDb(dynamic value) =>
      MerchantProfileFields.normalizeTimeForPersistence(value);

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

  bool _driverServiceEnabled(String service) {
    final services = _driverProfile?['services'];
    if (services is Map) {
      final value = services[service];
      if (value is bool) return value;
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
    if (audience == null) return const [];
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

  int? takePendingMerchantTab() {
    final tab = _pendingMerchantTab;
    _pendingMerchantTab = null;
    return tab;
  }

  int? takePendingDeliveryTab() {
    final tab = _pendingDeliveryTab;
    _pendingDeliveryTab = null;
    return tab;
  }

  int? takePendingDriverTab() {
    final tab = _pendingDriverTab;
    _pendingDriverTab = null;
    return tab;
  }

  void setPendingOrderId(String role, String? orderId) {
    switch (role) {
      case 'customer':
        _pendingOrderIdCustomer = orderId;
        break;
      case 'merchant':
        _pendingOrderIdMerchant = orderId;
        break;
      case 'delivery':
        _pendingOrderIdDelivery = orderId;
        break;
      case 'driver':
        _pendingOrderIdDriver = orderId;
        break;
    }
  }

  String? takePendingOrderId(String role) {
    switch (role) {
      case 'customer': {
          final id = _pendingOrderIdCustomer;
          _pendingOrderIdCustomer = null;
          return id;
        }
      case 'merchant': {
          final id = _pendingOrderIdMerchant;
          _pendingOrderIdMerchant = null;
          return id;
        }
      case 'delivery': {
          final id = _pendingOrderIdDelivery;
          _pendingOrderIdDelivery = null;
          return id;
        }
      case 'driver': {
          final id = _pendingOrderIdDriver;
          _pendingOrderIdDriver = null;
          return id;
        }
      default:
        return null;
    }
  }

  void requestTabForRole(String role, int index) {
    if (index < 0) return;
    switch (role) {
      case 'customer':
        _pendingMainTab = index;
        break;
      case 'merchant':
        _pendingMerchantTab = index;
        break;
      case 'delivery':
        _pendingDeliveryTab = index;
        break;
      case 'driver':
        _pendingDriverTab = index;
        break;
    }
    notifyListeners();
  }

  void goToCustomerHomeTab() {
    resetHome();
    requestTabForRole('customer', 0);
  }

  void handleNotificationOpen(Map<String, dynamic> data) {
    final eventKey = data['eventKey']?.toString() ?? '';
    final category = data['category']?.toString() ?? '';
    final role = data['role']?.toString() ?? _userRole ?? 'customer';
    final orderId = data['orderId']?.toString().trim() ??
        _extractOrderIdFromEventKey(eventKey);
    final hasOrderId = orderId != null && orderId.isNotEmpty;

    debugPrint(
        'Push: handleNotificationOpen event=$eventKey category=$category targetRole=$role orderId=$orderId');

    if (hasOrderId) {
      setPendingOrderId(role, orderId);
    }

    if (eventKey.contains('order:new') || eventKey.contains('request:new')) {
      if (role == 'merchant') requestTabForRole('merchant', 1);
      if (role == 'delivery') requestTabForRole('delivery', 1);
      if (role == 'driver') requestTabForRole('driver', 1);
    } else if (eventKey.contains('order:cancelled') ||
        eventKey.contains('order:updated')) {
      if (role == 'customer') requestTabForRole('customer', 3);
      if (role == 'merchant') requestTabForRole('merchant', 1);
    } else if (eventKey.contains('approval:approved')) {
      if (role == 'merchant') requestTabForRole('merchant', 0);
      if (role == 'delivery') requestTabForRole('delivery', 0);
      if (role == 'driver') requestTabForRole('driver', 0);
    } else if (category == 'taxi') {
      if (role == 'driver') requestTabForRole('driver', 1);
      if (role == 'customer') requestTabForRole('customer', 0);
    } else {
      if (role == 'customer') requestTabForRole('customer', 3);
      if (role == 'merchant') requestTabForRole('merchant', 1);
      if (role == 'delivery') requestTabForRole('delivery', 1);
      if (role == 'driver') requestTabForRole('driver', 1);
    }
  }

  String? _extractOrderIdFromEventKey(String eventKey) {
    if (eventKey.isEmpty) return null;
    final parts = eventKey.split(':');
    if (parts.length >= 3) {
      final candidate = parts[1].trim();
      if (candidate.isNotEmpty && !candidate.contains(' ')) return candidate;
    }
    return null;
  }

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

  String? notificationAudienceForRole(String? role) {
    switch (role) {
      case 'customer':
      case 'merchant':
      case 'delivery':
      case 'driver':
        return role;
      case 'admin':
        return 'customer';
      default:
        return null;
    }
  }

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

  Map<String, HomeCategoryPlatformOverride> _homeCategoryOverrides = {};
  int _homeCategoriesSaveGeneration = 0;

  Map<String, HomeCategoryPlatformOverride> get homeCategoryOverrides =>
      Map<String, HomeCategoryPlatformOverride>.unmodifiable(
        _homeCategoryOverrides,
      );

  List<ServiceCategory> get visibleHomeCategories =>
      MarketplaceCatalog.homeCategoriesWithOverrides(
        _homeCategoryOverrides,
        platform: PlatformKey.current,
      );

  bool isHomeCategoryEnabled(String categoryId) =>
      MarketplaceCatalog.isHomeCategoryEnabled(
        categoryId,
        overrides: _homeCategoryOverrides,
        platform: PlatformKey.current,
      );

  bool homeCategoryEnabledOnPlatform(String categoryId, String platform) {
    final override = _homeCategoryOverrides[categoryId];
    if (override != null) {
      final value = override.isEnabledOn(platform);
      if (value != null) return value;
    }
    return true;
  }

  int get totalSales => _merchantIncomingOrders
      .where((o) => o.statusKey == 'accepted' || o.statusKey == 'delivering')
      .fold(0, (sum, item) => sum + item.price);

  int get productCount => _items.length;

  // Forward declarations for methods provided by PersistenceMixin
  Future<void> _persistLocalBackup();
  Future<void> _persistRemoteStateLight();

  // Forward declarations for methods provided by CustomerMixin
  ListItem _listItemFromCatalogRow(Map<String, dynamic> row);
  ListItem _listItemFromProductRow(Map<String, dynamic> row);
  void _applyFavoriteSelections();
  void _hydrateCustomerIdentityFromRestoredData();
  Future<void> refreshCustomerCatalog({bool force = false});
  Future<void> refreshCustomerOrders({bool force = false});
  Future<void> refreshTaxiRequests();

  // Forward declarations for methods provided by AuthMixin
  void _resolveRoleAfterAuth();
  void _inferAccountTypeFromLegacyData();
  void _inferRoleFromRestoredData();
  void _applyAccountTypeConstraints();
  Future<void> _syncIdentityRecords();

  // Forward declarations for methods provided by MerchantMixin
  void _applyMerchantStoreSnapshot(Map<String, dynamic> snapshot);
  Map<String, dynamic> _mapMerchantProfileRow(Map<String, dynamic> row);

  // Forward declarations for methods provided by DriverMixin
  void _normalizeDriverProfileForRole();
  void _notifyDriverApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  });

  // Forward declarations for methods provided by DeliveryMixin
  void _notifyCourierApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  });
}
