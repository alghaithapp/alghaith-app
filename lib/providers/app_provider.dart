import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/catalog/marketplace_catalog.dart';
import '../core/catalog/marketplace_stats.dart';
import '../core/checkout/cart_promo.dart';
import '../core/storage/app_state_policy.dart';
import '../core/storage/catalog_cache.dart';
import '../core/storage/home_categories_cache.dart';
import '../modules/notifications/services/notification_hub.dart';
import '../modules/notifications/services/push_notification_inbox.dart';
import '../modules/notifications/services/push_notification_service.dart';
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
import '../models/merchant_product_section.dart';
import '../core/orders/order_adjustment.dart';
import '../modules/taxi/models/taxi_request.dart';
import '../modules/admin/screens/models/admin_role.dart';
import '../modules/auth/services/auth_service.dart';
import 'app_navigation_state.dart';
import 'app_ui_preferences.dart';
import 'app_notification_inbox_state.dart';
import 'app_cart_state.dart';
import 'app_customer_orders_state.dart';
import '../modules/marketplace/services/customer_service.dart';
import '../modules/merchant/services/merchant_service.dart';
import '../modules/driver/services/driver_service.dart';
import '../modules/courier/services/delivery_service.dart';
import '../modules/admin/services/admin_service.dart';

class AppProvider extends ChangeNotifier {
  static const Duration _pendingApprovalTimeout = Duration(minutes: 20);

  // ── Service instances ────────────────────────────────────────────
  final auth = AuthService();
  final customer = CustomerService();
  final merchant = MerchantService();
  final driver = DriverService();
  final delivery = DeliveryService();
  final admin = AdminService();

  final AppNavigationState _navigation = AppNavigationState();
  final AppUiPreferences _ui = AppUiPreferences();
  final AppNotificationInboxState _notificationInbox = AppNotificationInboxState();
  final AppCartState _cartState = AppCartState();
  final AppCustomerOrdersState _ordersState = AppCustomerOrdersState();

  late final NotificationHub _notificationHub =
      NotificationHub(_emitNotification);

  // ── Local state (UI / theme / navigation) ────────────────────────

  // Admin role state (not in any service yet)
  AdminRole? _adminRole;

  // Boot state
  Timer? _bootWatchdog;
  bool _isHydrating = false;
  bool _isReady = false;

  // ── Constructor ──────────────────────────────────────────────────
  AppProvider() {
    PushNotificationInbox.onCourierStatusPush = handleCourierStatusPush;

    auth.addListener(notifyListeners);
    customer.addListener(notifyListeners);
    merchant.addListener(notifyListeners);
    driver.addListener(notifyListeners);
    delivery.addListener(notifyListeners);
    admin.addListener(notifyListeners);

    _wireCrossServiceCallbacks();

    _isHydrating = false;
    _isReady = true;
    notifyListeners();

    _bootWatchdog = Timer(const Duration(seconds: 15), _forceBootReady);
    _loadSettingsBackend();
  }

  void _wireCrossServiceCallbacks() {
    // Auth → service refresh callbacks for role switch side effects
    auth.setOnRefreshCustomerCatalog(() => customer.refreshCustomerCatalog());
    auth.setOnRefreshCustomerOrders(() async {
      final phone = auth.authPhone;
      if (phone == null) return;
      final orders = await SupabaseService.loadCustomerOrders(phone);
      _ordersState.orders = orders;
      _ordersState.lastFetch = DateTime.now();
      notifyListeners();
    });
    auth.setOnRefreshMerchantIncomingOrders(() async {
      await merchant.refreshMerchantIncomingOrders();
      await merchant.hydrateMerchantEngagementFromCloud();
    });
    auth.setOnRefreshCourierOrders(() => refreshCourierOrders());
    auth.setOnRefreshTaxiRequests(() => refreshTaxiRequests());
    auth.setOnAdminReportsRefresh(() => admin.refreshAdminReports());

    // Auth → merchant persistence callbacks (handled internally by merchant service)

    // Auth → snapshot apply callbacks
    auth.setOnApplyMerchantSnapshot((snapshot) {
      merchant.applyMerchantStoreSnapshot(snapshot);
      auth.updateMerchantStore(merchant.merchantStore);
    });
    auth.setOnCollectUiState(() => _ui.toRemoteState());
    auth.setOnCollectLocalBackupData(() => {
      'merchantStore': merchant.merchantStore,
      'driverProfile': driver.driverProfile,
      'courierProfile': delivery.courierProfile,
      // items/orders/offers: local backup only — never persisted to app_state.
      'items': _itemsDelegate(),
      'orders': _ordersState.orders,
      'merchantOffers': merchant.merchantOffers,
    });
    auth.setOnApplyMerchantStore((store) {
      merchant.applyMerchantStoreSnapshot(store);
      auth.updateMerchantStore(merchant.merchantStore);
    });
    auth.setOnApplyDriverProfile((profile) => driver.loadProfileFromRemoteState({'driverProfile': profile}));
    auth.setOnApplyCourierProfile((profile) => delivery.loadProfileFromRemoteState({'courierProfile': profile}));
    auth.setOnApplyLocalBackupItems(
      (items) => merchant.loadInitialData(items, persist: false),
    );
    auth.setOnApplyLocalBackupOrders((orders) { _ordersState.orders = orders; notifyListeners(); });
    auth.setOnApplyLocalBackupOffers(
      (offers) => merchant.loadOffersFromLocalBackup(offers),
    );
    auth.setOnApplyRemoteOrders((orders) { _ordersState.orders = orders; _ordersState.lastFetch = DateTime.now(); notifyListeners(); });
    auth.setOnApplyRemoteAddresses((addresses) { /* restore addresses later */ });
    auth.setOnApplyRemoteProducts((products) {
      merchant.loadInitialData(
        products.map((p) => ListItem.fromMap(p)).toList(),
        persist: false,
      );
    });

    auth.setOnApplyRemoteState((state) {
      _ui.applyRemoteState(state);
      if (_ui.skippedCustomerSetup) {
        customer.applySkippedSetupFromRemote();
      }
      merchant.updateAuthPhone(auth.authPhone);
      merchant.updateCustomerPhone(customer.customerPhone);
      merchant.updateUserRole(auth.userRole);
      merchant.updateSessionToken(auth.sessionToken);
      driver.updateAuthPhone(auth.authPhone);
      driver.updateUserRole(auth.userRole);
      delivery.updateAuthPhone(auth.authPhone);
      delivery.updateUserRole(auth.userRole);
      final remoteDriverType = _ui.driverType;
      if (remoteDriverType != null && remoteDriverType.isNotEmpty) {
        driver.setDriverType(remoteDriverType);
      }
    });

    // مزامنة مباشرة من customer-profile / app-user بعد الاستعادة
    auth.setOnApplyRestoredCustomerProfile(({
      String? name,
      String? phone,
      String? address,
      double? latitude,
      double? longitude,
      String? avatarBase64,
    }) {
      customer.applyRestoredProfile(
        name: name,
        phone: phone,
        address: address,
        latitude: latitude,
        longitude: longitude,
        avatarBase64: avatarBase64,
      );
    });

    auth.setOnEnsureMerchantProfileSynced(() async {
      await merchant.ensureMerchantProfileSynced();
      auth.updateMerchantStore(merchant.merchantStore);
    });
    auth.setOnPersistMerchantStoreAndState(() async {
      await merchant.persistMerchantStoreAndStateForAuth();
      await auth.persistSessionBackup();
    });
    auth.setOnSyncMerchantDataBeforeLeavingMerchantMode(
      () => merchant.syncMerchantDataBeforeLeavingMerchantModeForAuth(),
    );
    auth.setOnPersistMerchantItems(
      () => merchant.persistMerchantItemsForAuth(),
    );
    merchant.requestSessionBackup = auth.persistSessionBackup;

    // Delivery → refresh account from cloud
    delivery.setOnRefreshAccountFromCloud(() async {
      await auth.setPhoneSession(auth.authPhone ?? '', sessionToken: auth.sessionToken);
    });

    // Admin → restore remote session & taxi refresh
    admin.setOnRestoreRemoteSession((phone) async {
      await auth.setPhoneSession(phone, sessionToken: auth.sessionToken);
    });
    admin.setOnRefreshTaxiRequests(() => refreshTaxiRequests());
  }

  void _forceBootReady() {
    if (_isReady) return;
    debugPrint('BOOT_WATCHDOG: forcing ready state after timeout');
    _isHydrating = false;
    _isReady = true;
    notifyListeners();
  }

  void _finalizeBootState() {
    _isHydrating = false;
    _isReady = true;
    if (!auth.hasPhoneSession && !auth.isGuestMode) {
      setGuestMode();
    }
    if (auth.hasPhoneSession && auth.authPhone != null &&
        auth.authPhone!.isNotEmpty) {
      unawaited(PushNotificationService.instance.bindToUser(auth.authPhone!));
      unawaited(_preloadAllOperatorProfiles());
      unawaited(_checkMerchantServerProfileIfNeeded());
    }
    notifyListeners();
  }

  Future<void> _checkMerchantServerProfileIfNeeded() async {
    if (auth.userRole != 'merchant') return;
    if (!merchant.hasCompletedMerchantProfile || merchant.isMerchantApproved) {
      return;
    }
    if (!merchant.isMerchantProfileServerCheckPending) return;
    await merchant.refreshMerchantProfileServerStatus();
    notifyListeners();
  }

  /// يحمّل ملفات المندوب والسائق والتاجر من التخزين المحلي أو السيرفر
  /// حتى يكون التبديل بين الأدوار فورياً دون شاشة إعداد فارغة.
  Future<void> _preloadAllOperatorProfiles() async {
    await Future.wait([
      _ensureCourierProfileLoaded(),
      _ensureDriverProfileLoaded(),
    ]);
    notifyListeners();
  }

  Future<void> _ensureCourierProfileLoaded() async {
    if (delivery.hasCourierProfile ||
        delivery.hasCourierRegistration) {
      return;
    }
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) return;

    try {
      final snapshot =
          await AccountRepository.instance.readLocalSnapshot(phone);
      final local = snapshot?.courierProfile;
      if (local != null && local.isNotEmpty) {
        delivery.loadProfileFromRemoteState({'courierProfile': local});
        if (delivery.hasCourierRegistration) return;
      }
    } catch (error) {
      debugPrint('ENSURE_COURIER_LOCAL_ERROR: $error');
    }

    if (!SupabaseService.isConfigured) return;
    try {
      final state = await SupabaseService.loadUserState(phone);
      if (state != null) {
        delivery.loadProfileFromRemoteState(state);
      }
    } catch (error) {
      debugPrint('ENSURE_COURIER_REMOTE_ERROR: $error');
    }
  }

  Future<void> _ensureDriverProfileLoaded() async {
    if (driver.hasDriverProfile) return;
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) return;

    try {
      final snapshot =
          await AccountRepository.instance.readLocalSnapshot(phone);
      final local = snapshot?.driverProfile;
      if (local != null && local.isNotEmpty) {
        driver.loadProfileFromRemoteState({'driverProfile': local});
        if (driver.hasDriverProfile) return;
      }
    } catch (error) {
      debugPrint('ENSURE_DRIVER_LOCAL_ERROR: $error');
    }

    if (!SupabaseService.isConfigured) return;
    try {
      final state = await SupabaseService.loadUserState(phone);
      if (state != null) {
        driver.loadProfileFromRemoteState(state);
      }
    } catch (error) {
      debugPrint('ENSURE_DRIVER_REMOTE_ERROR: $error');
    }
  }

  Future<void> _loadSettingsBackend() async {
    await _restoreHomeCategoriesFromCache();
    unawaited(admin.refreshHomeCategoriesConfig());
    unawaited(_restoreCatalogFromCache());

    try {
      final accountRepo = AccountRepository.instance;
      final stored = await accountRepo.readStoredSession();
      if (stored != null) {
        await auth.setPhoneSession(stored.phone, sessionToken: stored.token);
      }
    } catch (error) {
      debugPrint('CRITICAL: Initial load failed: $error');
    } finally {
      _bootWatchdog?.cancel();
      _bootWatchdog = null;
      if (!auth.isLoggingIn) {
        _finalizeBootState();
      }
    }
  }

  Future<void> _restoreCatalogFromCache() async {
    try {
      final cached = await CatalogCache.readCatalog();
      if (cached != null && cached.isNotEmpty) {
        notifyListeners();
        debugPrint('CACHE: Global catalog restored (${cached.length} items)');
      }
    } catch (e) {
      debugPrint('CACHE_RESTORE_ERROR: $e');
    }
  }

  Future<void> _restoreHomeCategoriesFromCache() async {
    final cached = await HomeCategoriesCache.read();
    if (cached == null || cached.isEmpty) return;
    admin.applyHomeCategoryOverrides(cached);
  }

  // ── Internal notification callback ──────────────────────────────
  String _emitNotification({
    required String title,
    required String body,
    required String audience,
    String? orderNumber,
    NotificationCategory category = NotificationCategory.system,
    NotificationPriority priority = NotificationPriority.normal,
    String? eventKey,
  }) {
    final id = _notificationInbox.add(
      title,
      body,
      audience: audience,
      orderNumber: orderNumber,
      category: category,
      priority: priority,
      eventKey: eventKey,
    );
    notifyListeners();
    return id;
  }

  // ── AUTH ─────────────────────────────────────────────────────────
  String get lang => _ui.lang;
  bool get hasSelectedLanguage => true;
  String? get userRole => auth.userRole;
  String? get accountType => auth.accountType;
  bool get hasLockedAccountType => auth.hasLockedAccountType;
  bool get isMarketplaceAccount => auth.isMarketplaceAccount;
  bool get isDeliveryAccount => auth.isDeliveryAccount;
  bool get isDriverAccount => auth.isDriverAccount;
  bool get hasAdminAccess => auth.hasAdminAccess;
  String? get authPhone => auth.authPhone;
  String? get sessionToken => auth.sessionToken;
  bool get isLoggingIn => auth.isLoggingIn;
  bool get hasPhoneSession => auth.hasPhoneSession;
  bool get hasSelectedRole => auth.hasSelectedRole;
  bool get isGuestMode => auth.isGuestMode;
  bool get isRestoring => auth.isRestoring;
  bool get isSessionDataReady => auth.isReady;
  /// بيانات الحساب ما زالت تُحمَّل من السيرفر بعد تسجيل الدخول أو استعادة الجلسة.
  bool get isLoadingAccountFromServer =>
      hasPhoneSession &&
      (isLoggingIn || isRestoring || !isSessionDataReady);
  bool get isReady => _isReady;
  bool get isHydrating => _isHydrating;

  bool isRoleAllowedForAccount(String role) =>
      auth.isRoleAllowedForAccount(role);

  Future<void> setPhoneSession(String phone, {String? sessionToken}) async {
    await auth.setPhoneSession(phone, sessionToken: sessionToken);
    _propagateCrossDomainState();
    await _preloadAllOperatorProfiles();
  }

  Future<bool> setUserRole(String role) async {
    if (role == 'delivery') {
      await _ensureCourierProfileLoaded();
    } else if (role == 'driver') {
      await _ensureDriverProfileLoaded();
    }

    final result = await auth.setUserRole(role);
    if (result) {
      _propagateCrossDomainState();
      if (role == 'merchant') {
        merchant.resetMerchantProfileServerStatus();
        unawaited(_checkMerchantServerProfileIfNeeded());
      }
      notifyListeners();
    }
    return result;
  }

  Future<void> activateMerchantRole() => auth.activateMerchantRole();
  Future<void> deleteAccountPermanently() async {
    await auth.deleteAccountPermanently();
    resetAll();
  }

  void resetAll() {
    auth.resetAll();
    _adminRole = null;
    _notificationInbox.reset();
    _navigation.reset();
    _isHydrating = false;
    _isReady = true;
    notifyListeners();
  }

  void setGuestMode() {
    auth.enterGuestMode();
    _propagateCrossDomainState();
    _isReady = true;
    _isHydrating = false;
    notifyListeners();
    unawaited(refreshHomeCategoriesConfig());
    if (isGuestMode) {
      unawaited(customer.refreshCustomerCatalog());
      unawaited(refreshMarketplaceStats());
    }
  }

  void setLanguage(String l) {
    _ui.setLanguage(l);
  }

  Future<void> refreshAccountFromCloud() async {
    if (auth.authPhone != null && auth.authPhone!.isNotEmpty) {
      await auth.setPhoneSession(auth.authPhone!, sessionToken: auth.sessionToken);
    }
    if (merchant.hasCompletedMerchantProfile && !merchant.isMerchantApproved) {
      await merchant.refreshMerchantProfileServerStatus();
      auth.updateMerchantStore(merchant.merchantStore);
    }
    notifyListeners();
  }

  Future<String?> uploadImage(File file, {String bucket = 'uploads'}) async {
    try {
      return await ImageStorageService.uploadImageFile(file, bucket: bucket);
    } catch (e) {
      debugPrint('UPLOAD_ERROR: $e');
      return null;
    }
  }

  // ── CROSS-DOMAIN STATE PROPAGATION ──────────────────────────────
  void _propagateCrossDomainState() {
    final phone = auth.authPhone;
    final role = auth.userRole;
    customer.updateAuthPhone(phone);
    customer.updateUserRole(role);
    merchant.updateAuthPhone(phone);
    merchant.updateCustomerPhone(customer.customerPhone);
    merchant.updateUserRole(role);
    merchant.updateSessionToken(auth.sessionToken);
    driver.updateAuthPhone(phone);
    driver.updateUserRole(role);
    delivery.updateAuthPhone(phone);
    delivery.updateCustomerPhone(customer.customerPhone);
    delivery.updateUserRole(role);
    admin.updateAuthPhone(phone);
    admin.updateCustomerPhone(customer.customerPhone);
    admin.updateUserRole(role);
  }

  // ── CUSTOMER ─────────────────────────────────────────────────────
  Map<String, dynamic>? _appUserRecord;

  String? get customerAvatarBase64 => customer.customerAvatarBase64;
  String? get customerAvatarUrl => customer.customerAvatarUrl;
  AppUserView get appUserView => AppUserView(_appUserRecord ?? auth.appUserRecord);
  bool get hasCompletedCustomerProfile => customer.hasCompletedCustomerProfile;
  Map<String, dynamic>? get appUserRecord => _appUserRecord ?? auth.appUserRecord;
  String get customerName => customer.customerName;
  String get customerPhone => customer.customerPhone;
  String get customerAddress => customer.customerAddress;
  double? get customerLatitude => customer.customerLatitude;
  double? get customerLongitude => customer.customerLongitude;
  bool get isCustomer => customer.isCustomer;
  bool get skippedCustomerSetup =>
      _ui.skippedCustomerSetup || customer.skippedCustomerSetup;

  void skipCustomerSetup() {
    customer.skipCustomerSetup();
    _ui.skippedCustomerSetup = true;
    unawaited(_persistUiState());
  }

  List<ListItem> get items =>
      isCustomer ? customer.catalogItems : merchant.merchantItems;
  MarketplaceStatsSnapshot? get marketplaceStats => customer.marketplaceStats;
  bool get marketplaceStatsLoading => customer.marketplaceStatsLoading;
  List<CartItem> get cart => _cartState.cart;
  List<ActiveOrder> get orders => _ordersState.orders;
  int get customerActiveOrdersCount => _ordersState.activeCount;
  List<String> get addresses =>
      List<String>.unmodifiable(_ordersState.addresses);

  bool isFavoriteId(String id) => customer.isFavoriteId(id);
  String get selectedCategory => _cartState.selectedCategory;
  String? get activeSubCategory => _cartState.activeSubCategory;
  void setCategory(String category) {
    _cartState.selectedCategory = category;
    if (category != 'all') {
      _cartState.activeSubCategory = null;
    }
    notifyListeners();
  }

  void resetHome() {
    _cartState.resetHome();
    notifyListeners();
  }

  void goToCustomerHomeTab() {
    resetHome();
    requestTabForRole('customer', 0);
  }

  void toggleFavorite(String id) => customer.toggleFavorite(id);
  void toggleFavoriteItem(ListItem item) => customer.toggleFavoriteItem(item);
  void toggleFavoriteStoreProduct(
      Map<String, dynamic> product, Map<String, dynamic> profile) =>
      customer.toggleFavoriteStoreProduct(product, profile);
  ListItem listItemFromStoreProduct(
      Map<String, dynamic> product, Map<String, dynamic> profile) =>
      customer.listItemFromStoreProduct(product, profile);

  // ── Cart ─────────────────────────────────────────────────────────
  int get cartTotal => _cartState.total;

  CartPromoDefinition? get appliedCartPromo => _cartState.appliedPromo;
  int get cartPromoDiscountIqd => _cartState.promoDiscountIqd;
  int get cartPayableTotal => _cartState.payableTotal;

  int get cartCount => _cartState.count;

  bool get cartHasMultipleMerchants => _cartState.hasMultipleMerchants;

  bool addToCart(ListItem item, {bool fromStoreListing = false}) {
    if (!_cartState.canAddItem(item, fromStoreListing: fromStoreListing)) {
      return false;
    }
    _cartState.addItem(item);
    notifyListeners();
    return true;
  }

  bool addStoreProductToCart(
      Map<String, dynamic> product, Map<String, dynamic> profile) {
    return addToCart(
      listItemFromStoreProduct(product, profile),
      fromStoreListing: true,
    );
  }

  void incrementCartItem(String id) {
    _cartState.incrementItem(id);
    notifyListeners();
  }

  void decrementCartItem(String id) {
    _cartState.decrementItem(id);
    notifyListeners();
  }

  void removeFromCart(String id) {
    _cartState.removeItem(id);
    notifyListeners();
  }

  void clearCart() {
    if (_cartState.cart.isEmpty) return;
    _cartState.clear();
    notifyListeners();
  }

  bool reorderFromPreviousOrder(ActiveOrder order) {
    final merchantPhone = _trimmedOrNull(order.merchantPhone);
    if (merchantPhone == null || order.lineItems.isEmpty) return false;
    if (_hasActiveOrderForMerchant(merchantPhone)) return false;
    final c = _cartState.cart;
    if (c.isNotEmpty) {
      final existingMerchant = _trimmedOrNull(c.first.merchantPhone);
      if (existingMerchant != null && existingMerchant != merchantPhone) {
        return false;
      }
    }
    final category = order.isRestaurantOrder ? 'restaurant' : 'product';
    for (var i = 0; i < order.lineItems.length; i++) {
      final line = order.lineItems[i];
      c.add(CartItem(
        id: 'reorder-${order.id}-$i',
        nameAr: line.nameAr,
        nameEn: line.nameEn,
        price: line.price,
        count: line.quantity,
        image: line.image ?? '',
        category: category,
        originalCategory: category,
        merchantPhone: order.merchantPhone,
        merchantStoreName: order.merchantStoreName,
        merchantLatitude: order.merchantLatitude,
        merchantLongitude: order.merchantLongitude,
      ));
    }
    notifyListeners();
    return true;
  }

  bool _hasActiveOrderForMerchant(String merchantPhone) {
    return _ordersState.orders.any((order) {
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
      return order.statusKey != 'completed' &&
          order.statusKey != 'cancelled' &&
          order.statusKey != 'rejected';
    });
  }

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
          messageAr: row['messageAr']?.toString() ?? 'كود الخصم غير صحيح أو منتهي.',
        );
      }
      final promo = CartPromoDefinition.fromMap(row);
      _cartState.appliedPromo = promo;
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
    if (_cartState.appliedPromo == null) return;
    _cartState.clearPromo();
    notifyListeners();
  }

  // ── Address ──────────────────────────────────────────────────────
  Future<void> addAddress(String address) async {
    final value = address.trim();
    if (!_ordersState.addAddress(value)) return;
    notifyListeners();
    if (auth.authPhone != null && auth.authPhone!.isNotEmpty) {
      try {
        await SupabaseService.saveCustomerAddress(auth.authPhone!, value, sortOrder: 0);
      } catch (error) {
        debugPrint('DB_ERROR: Failed to save address: $error');
      }
    }
  }

  Future<void> removeAddress(int index) async {
    final removed = _ordersState.removeAddressAt(index);
    if (removed == null) return;
    notifyListeners();
    if (auth.authPhone != null && auth.authPhone!.isNotEmpty) {
      try {
        await SupabaseService.deleteCustomerAddress(auth.authPhone!, removed);
      } catch (error) {
        debugPrint('DB_ERROR: Failed to delete address: $error');
      }
    }
  }

  // ── Customer profile ─────────────────────────────────────────────
  Future<void> updateCustomerProfile({
    String? name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    String? avatarBase64,
  }) async {
    await customer.updateCustomerProfile(
      name: name,
      phone: phone,
      address: address,
      latitude: latitude,
      longitude: longitude,
      avatarBase64: avatarBase64,
    );
  }

  // ── Catalog / orders ─────────────────────────────────────────────
  Future<void> refreshCustomerCatalog({bool force = false}) =>
      customer.refreshCustomerCatalog(force: force);
  Future<void> refreshMarketplaceStats({bool force = false}) =>
      customer.refreshMarketplaceStats(force: force);
  ListItem catalogItemFromRow(Map<String, dynamic> row) =>
      customer.catalogItemFromRow(row);

  List<ListItem> _itemsDelegate() => merchant.merchantItems;

  Future<void> refreshCustomerOrders({bool force = false}) async {
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    if (!force &&
        _ordersState.lastFetch != null &&
        DateTime.now().difference(_ordersState.lastFetch!) <
            const Duration(minutes: 2)) {
      return;
    }
    try {
      _ordersState.orders = await SupabaseService.loadCustomerOrders(phone);
      _ordersState.lastFetch = DateTime.now();
      notifyListeners();
    } catch (error) {
      debugPrint('CUSTOMER_ORDERS_LOAD_ERROR: $error');
    }
  }

  bool requestCustomerOrderCancellation(String orderId) {
    final orders = _ordersState.orders;
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return false;
    final order = orders[index];
    if (order.statusKey == 'completed' ||
        order.statusKey == 'cancelled' ||
        order.statusKey == 'rejected' ||
        order.statusKey == 'cancel_requested') {
      return false;
    }
    if (order.statusKey == 'pending' || order.statusKey == 'adjustment_pending') {
      _updateCustomerOrderStatus(
        orderId, 'cancelled', 'ملغي', 'Cancelled',
        noteAr: 'تم إلغاء الطلب من الزبون قبل موافقة التاجر.',
        noteEn: 'Cancelled by customer before merchant approval.',
      );
      return true;
    }
    final noteEn = '__cancel_prev:${order.statusKey}__';
    _updateCustomerOrderStatus(
      orderId, 'cancel_requested', 'طلب إلغاء بانتظار موافقة التاجر', 'Cancellation requested',
      noteAr: 'تم إرسال طلب الإلغاء إلى التاجر بانتظار الموافقة.',
      noteEn: noteEn,
    );
    return true;
  }

  void _updateCustomerOrderStatus(
    String orderId,
    String newStatusKey,
    String statusAr,
    String statusEn, {
    String? noteAr,
    String? noteEn,
  }) {
    final orders = _ordersState.orders;
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = orders[index];
    final nowIso = DateTime.now().toIso8601String();
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
      merchantLatitude: order.merchantLatitude,
      merchantLongitude: order.merchantLongitude,
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
      merchantDecisionAt: newStatusKey == 'cancelled' ? nowIso : order.merchantDecisionAt,
      isPriceLocked: order.isPriceLocked,
    );
    orders[index] = updated;
    notifyListeners();
    _persistCustomerOrder(updated);
  }

  Future<void> _persistCustomerOrder(ActiveOrder order) async {
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) return;
    await SupabaseService.saveCustomerOrder(phone, order);
  }

  bool resolveCustomerCancellationRequestByMerchant(
    String orderId, {
    required bool approve,
  }) {
    final incoming = merchant.merchantIncomingOrders;
    final index = incoming.indexWhere((item) => item.id == orderId);
    if (index == -1) return false;
    final order = incoming[index];
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

  Future<bool> respondToOrderAdjustment(
    String orderId, {
    required bool approve,
  }) async {
    final index = _ordersState.orders.indexWhere((item) => item.id == orderId);
    if (index == -1) return false;
    final order = _ordersState.orders[index];
    if (order.statusKey != 'adjustment_pending') return false;

    if (approve) {
      final availableItems =
          order.lineItems.where((item) => item.isAvailable).toList();
      final updated = order.copyWith(
        statusKey: 'accepted',
        statusAr: 'تمت الموافقة',
        statusEn: 'Approved',
        lineItems: availableItems,
        itemsCount: orderAvailableItemsCount(availableItems),
        itemsNameAr: orderAvailableItemsLabelAr(availableItems),
        itemsNameEn: orderAvailableItemsLabelEn(availableItems),
        isPriceLocked: true,
        noteAr: 'وافق الزبون على الطلب المعدّل.',
        noteEn: 'Customer approved adjusted order.',
      );
      _ordersState.orders[index] = updated;
      _notificationHub.onOrderAdjustmentAccepted(updated);
      notifyListeners();
      try {
        await _persistCustomerOrder(updated);
      } catch (error) {
        debugPrint('ACCEPT_ORDER_ADJUSTMENT_ERROR: $error');
        return false;
      }
      return true;
    }

    final updated = order.copyWith(
      statusKey: 'cancelled',
      statusAr: 'ملغي',
      statusEn: 'Cancelled',
      noteAr: 'رفض الزبون الطلب المعدّل.',
      noteEn: 'Customer rejected adjusted order.',
    );
    _ordersState.orders[index] = updated;
    _notificationHub.onOrderAdjustmentRejected(updated);
    notifyListeners();
    try {
      await _persistCustomerOrder(updated);
    } catch (error) {
      debugPrint('REJECT_ORDER_ADJUSTMENT_ERROR: $error');
      return false;
    }
    return true;
  }

  Future<void> submitMerchantReview({
    required String orderId,
    required int stars,
    String? comment,
  }) async {
    final index = _ordersState.orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = _ordersState.orders[index];
    final merchantPhone = _trimmedOrNull(order.merchantPhone);
    if (merchantPhone == null) return;

    final customerPhone =
        _trimmedOrNull(auth.authPhone) ?? _trimmedOrNull(customer.customerPhone) ?? '';
    if (customerPhone.isEmpty) return;

    await SupabaseService.submitMerchantReview(
      merchantPhone: merchantPhone,
      customerPhone: customerPhone,
      customerName: customer.customerName.isNotEmpty
          ? customer.customerName
          : 'زبون الغيث',
      orderId: orderId,
      stars: stars,
      comment: comment,
    );

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
      merchantLatitude: order.merchantLatitude,
      merchantLongitude: order.merchantLongitude,
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

    _ordersState.orders[index] = updated;
    await _persistCustomerOrder(updated);
    notifyListeners();
  }

  Future<int> checkout({
    int deliveryFeeIqd = 0,
    Map<String, int>? merchantDeliveryFees,
    String? orderNotes,
  }) async {
    if (_cartState.cart.isEmpty) return 0;

    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) {
      throw StateError(
        'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى قبل إتمام الطلب.',
      );
    }

    if (_cartState.appliedPromo != null && cartPromoDiscountIqd <= 0) {
      throw StateError('كود الخصم لم يعد ينطبق على السلة الحالية.');
    }

    final grouped = <String, List<CartItem>>{};
    for (final item in _cartState.cart) {
      final key = _trimmedOrNull(item.merchantPhone) ?? 'unknown';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final trimmedNotes = orderNotes?.trim() ?? '';
    final createdOrders = <ActiveOrder>[];

    for (final entry in grouped.entries) {
      final groupItems = entry.value;
      if (groupItems.isEmpty) continue;

      final subtotal = groupItems.fold(0, (sum, item) => sum + (item.price * item.count));
      final merchantPhone = entry.key == 'unknown' ? null : entry.key;
      if (merchantPhone == null) continue;
      if (_hasActiveOrderForMerchant(merchantPhone)) continue;

      final now = DateTime.now();
      final orderId = _generateUuid();

      final newOrder = ActiveOrder(
        id: orderId,
        orderNumber: '#${(now.millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}',
        dateAr: 'الآن',
        dateEn: 'Just now',
        customerNameAr: customerName.isNotEmpty ? customerName : 'زبون الغيث',
        customerNameEn: customerName.isNotEmpty ? customerName : 'Al-Ghaith Customer',
        customerPhone: phone,
        addressAr: customerAddress.isNotEmpty ? customerAddress : 'لم يتم تحديد الموقع',
        addressEn: customerAddress.isNotEmpty ? customerAddress : 'Location not set',
        noteAr: trimmedNotes,
        noteEn: trimmedNotes,
        paymentMethodAr: 'نقداً عند الاستلام',
        paymentMethodEn: 'Cash on Delivery',
        statusKey: 'pending',
        statusAr: 'بانتظار الموافقة',
        statusEn: 'Pending Approval',
        price: subtotal,
        itemsCount: groupItems.length,
        itemsNameAr: groupItems.map((e) => e.nameAr).join(' ، '),
        itemsNameEn: groupItems.map((e) => e.nameEn).join(', '),
        lineItems: groupItems.map((item) => OrderLineItem(
          nameAr: item.nameAr,
          nameEn: item.nameEn,
          quantity: item.count,
          price: item.price,
          image: item.image,
        )).toList(),
        isRestaurantOrder: groupItems.any((item) => item.category == 'restaurant'),
        requiresDelivery: true,
        codConfirmed: false,
        customerLatitude: customerLatitude,
        customerLongitude: customerLongitude,
        merchantPhone: merchantPhone,
        merchantStoreName: groupItems.first.merchantStoreName,
        merchantLatitude: groupItems.first.merchantLatitude,
        merchantLongitude: groupItems.first.merchantLongitude,
        createdAt: now.toIso8601String(),
        isPriceLocked: false,
        itemsSubtotalIqd: subtotal,
        deliveryFeeIqd: 0,
        promoDiscountIqd: 0,
        originalPrice: subtotal,
      );

      try {
        await SupabaseService.saveCustomerOrder(phone, newOrder);
        createdOrders.add(newOrder);
      } catch (error) {
        debugPrint('CHECKOUT_SAVE_ERROR (${newOrder.id}): $error');
      }
    }

    if (createdOrders.isNotEmpty) {
      _ordersState.prependOrders(createdOrders.reversed);
      _cartState.clear();
      _notificationHub.onCheckoutSuccess(createdOrders);
      notifyListeners();
    }

    return createdOrders.length;
  }

  // ── Catalog helpers ──────────────────────────────────────────────
  List<ListItem> searchCatalogItems(String query) =>
      customer.searchCatalogItems(query);
  String displayOrderNumber(ActiveOrder order) {
    final raw = order.orderNumber.trim();
    if (raw.isNotEmpty && raw.length <= 14) return raw;
    final idSeed = order.id.split('-').first;
    final seed = int.tryParse(idSeed);
    if (seed == null) return raw.isNotEmpty ? raw : order.id;
    final short = (seed % 1000000).toString().padLeft(6, '0');
    return '#$short';
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

  DateTime? parseOrderCreatedAtForSort(ActiveOrder order) =>
      _parseOrderCreatedAt(order);

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

  void tickCustomerNotificationTimers() {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final c = _cartState.cart;

    if (c.isNotEmpty && _cartState.lastActivityMs > 0) {
      const abandoned = Duration(minutes: 30);
      if (nowMs - _cartState.lastActivityMs >= abandoned.inMilliseconds &&
          !_cartState.timerEmitted.contains('cart_abandoned')) {
        _cartState.timerEmitted.add('cart_abandoned');
        _notificationHub.onAbandonedCart(cartCount);
      }
    }

    for (final order in _ordersState.orders) {
      final id = order.id;
      if (order.statusKey == 'delivering' ||
          order.deliveryStatusKey == 'on_way') {
        if (!_cartState.timerEmitted.contains('delay:$id')) {
          final eta = order.estimatedArrivalAt;
          if (eta != null && eta.isNotEmpty) {
            final parsed = DateTime.tryParse(eta);
            if (parsed != null && now.isAfter(parsed)) {
              _cartState.timerEmitted.add('delay:$id');
              _notificationHub.onDeliveryDelay(order);
            }
          }
        }
      }
      if (order.requiresDelivery && !order.codConfirmed &&
          (order.statusKey == 'delivering' ||
              order.deliveryStatusKey == 'on_way' ||
              order.deliveryStatusKey == 'picked_up')) {
        final key = 'cod:$id';
        if (!_cartState.timerEmitted.contains(key)) {
          _cartState.timerEmitted.add(key);
          _notificationHub.onCustomerCodReminder(order);
        }
      }
    }
  }

  void tickMerchantNotificationTimers() {
    final now = DateTime.now();
    for (final offer in merchant.merchantOffers) {
      if (!offer.isActive) continue;
      final end = DateTime.tryParse(offer.endDate);
      if (end == null) continue;
      final days = end.difference(now).inDays;
      if (days <= 2) {
        final key = 'offer:${offer.id}';
        if (_cartState.timerEmitted.add(key)) {
          _notificationHub.onOfferExpiringSoon(offer.titleAr, days);
        }
      }
    }
  }

  // ── MERCHANT ─────────────────────────────────────────────────────
  String? get merchantProfileImageBase64 => merchant.merchantProfileImageBase64;
  List<String> get merchantWorkSampleImagesBase64 =>
      merchant.merchantWorkSampleImagesBase64;
  Map<String, dynamic>? get merchantStore => merchant.merchantStore;
  List<MerchantOffer> get merchantOffers => merchant.merchantOffers;
  List<MerchantReview> get merchantReviews => merchant.merchantReviews;
  bool get isMerchant => merchant.isMerchant;
  bool get hasCompletedMerchantProfile => merchant.hasCompletedMerchantProfile;
  bool get isMerchantApproved => merchant.isMerchantApproved;
  bool get isCheckingMerchantServerProfile =>
      merchant.isMerchantProfileServerCheckPending;
  bool get isMerchantProfileOnServer => merchant.isMerchantProfileOnServer;
  bool get needsMerchantProfileResubmit => merchant.needsMerchantProfileResubmit;
  bool get shouldShowMerchantPendingApproval =>
      merchant.shouldShowMerchantPendingApproval;
  bool get canUseMerchantAccount => merchant.canUseMerchantAccount;
  MerchantStoreView get merchantStoreView => MerchantStoreView(merchant.merchantStore);
  bool get isMerchantStoreOpen => merchant.isMerchantStoreOpen;
  bool get isBazaarApproved => merchant.isBazaarApproved;
  String get merchantStoreName => merchant.merchantStoreName;
  String get merchantCategoryId => merchant.merchantCategoryId;
  List<String> get merchantServiceIds => merchant.merchantServiceIds;
  String get merchantActiveServiceId => merchant.merchantActiveServiceId;
  bool get merchantHasMultipleServices => merchant.merchantHasMultipleServices;
  MerchantServiceLabels get merchantActiveLabels =>
      merchant.merchantActiveLabels;
  MerchantServiceLabels get merchantLabels => merchant.merchantLabels;
  String get merchantDescription => merchant.merchantDescription;
  String get merchantCoverImage => merchant.merchantCoverImage;
  String get merchantLogoImage => merchant.merchantLogoImage;
  String get merchantPhone => merchant.merchantPhone;
  String get merchantWhatsApp => merchant.merchantWhatsApp;
  bool get merchantShowPhoneToCustomers =>
      merchant.merchantShowPhoneToCustomers;
  bool get merchantShowWhatsAppToCustomers =>
      merchant.merchantShowWhatsAppToCustomers;
  String get merchantAddress => merchant.merchantAddress;
  double? get merchantLatitude => merchant.merchantLatitude;
  double? get merchantLongitude => merchant.merchantLongitude;

  bool requiresMerchantLocationForService(String serviceId) =>
      merchant.requiresMerchantLocationForService(serviceId);
  bool canPublishForService(String serviceId) =>
      merchant.canPublishForService(serviceId);
  void assertCanPublishForService(String serviceId) =>
      merchant.assertCanPublishForService(serviceId);

  String get merchantOpenTime => merchant.merchantOpenTime;
  String get merchantCloseTime => merchant.merchantCloseTime;
  int get merchantDeliveryFee => merchant.merchantDeliveryFee;
  String get merchantDeliveryAreas => merchant.merchantDeliveryAreas;
  double get merchantRating => merchant.merchantRating;
  List<MerchantProductSection> get merchantProductSections =>
      merchant.merchantProductSections;
  String? merchantProductSectionName(String? sectionId) =>
      merchant.merchantProductSectionName(sectionId);
  String? get merchantProfileImageUrl => merchant.merchantProfileImageUrl;
  List<String> get merchantWorkSampleUrls => merchant.merchantWorkSampleUrls;
  String? get merchantProfessionalCategoryId =>
      merchant.merchantProfessionalCategoryId;
  bool get merchantCatalogSeeded => false;

  List<ListItem> get merchantItems => merchant.merchantItems;
  List<ListItem> get merchantFeaturedItems => merchant.merchantFeaturedItems;
  int get merchantProductCount => merchant.merchantProductCount;
  int get merchantOrdersCount => merchant.merchantOrdersCount;
  int get merchantPendingOrdersCount => merchant.merchantPendingOrdersCount;
  int get merchantActiveOrdersCount => merchant.merchantActiveOrdersCount;
  int get merchantCompletedOrdersCount => merchant.merchantCompletedOrdersCount;
  int get merchantAcceptedOrdersCount => merchant.merchantAcceptedOrdersCount;
  int get merchantRejectedOrdersCount => merchant.merchantRejectedOrdersCount;
  int get merchantDecidedOrdersCount => merchant.merchantDecidedOrdersCount;
  double get merchantAcceptanceRate => merchant.merchantAcceptanceRate;
  double get merchantRejectionRate => merchant.merchantRejectionRate;
  double get merchantAverageResponseMinutes =>
      merchant.merchantAverageResponseMinutes;

  int merchantProductsInSection(String sectionId) =>
      merchant.merchantProductsInSection(sectionId);

  Future<void> addMerchantOffer(MerchantOffer offer) =>
      merchant.addMerchantOffer(offer);
  Future<void> updateMerchantOffer(MerchantOffer updatedOffer) =>
      merchant.updateMerchantOffer(updatedOffer);
  Future<void> toggleMerchantOfferActive(String offerId) =>
      merchant.toggleMerchantOfferActive(offerId);
  Future<void> deleteMerchantOffer(String offerId) =>
      merchant.deleteMerchantOffer(offerId);
  Future<void> replyMerchantReview(String reviewId, String reply) =>
      merchant.replyMerchantReview(reviewId, reply);
  Future<void> setMerchantStore(Map<String, dynamic> storeData) =>
      merchant.setMerchantStore(storeData);
  Future<void> ensureMerchantProfileSynced() =>
      merchant.ensureMerchantProfileSynced();
  Future<bool> resubmitMerchantProfileToServer() =>
      merchant.resubmitMerchantProfileToServer();
  Future<bool> refreshMerchantProfileServerStatus() =>
      merchant.refreshMerchantProfileServerStatus();
  Future<void> updateMerchantStore(Map<String, dynamic> updates) =>
      merchant.updateMerchantStore(updates);
  Future<void> setMerchantProductSections(
          List<MerchantProductSection> sections) =>
      merchant.setMerchantProductSections(sections);
  Future<void> toggleMerchantOpenStatus() =>
      merchant.toggleMerchantOpenStatus();
  Future<void> setMerchantActiveService(String serviceId) =>
      merchant.setMerchantActiveService(serviceId);
  Future<void> addMerchantService(String serviceId) =>
      merchant.addMerchantService(serviceId);
  Future<void> setMerchantServiceEnabled(String serviceId, bool enabled) =>
      merchant.setMerchantServiceEnabled(serviceId, enabled);
  Future<void> removeMerchantService(String serviceId) =>
      merchant.removeMerchantService(serviceId);
  bool isMerchantServiceEnabled(String serviceId) =>
      merchant.isMerchantServiceEnabled(serviceId);
  Map<String, bool> get merchantServiceEnabledMap =>
      merchant.merchantServiceEnabledMap;
  Future<void> addProduct(ListItem item) => merchant.addProduct(item);
  Future<void> updateProduct(ListItem updatedItem) =>
      merchant.updateProduct(updatedItem);
  Future<void> deleteProduct(String id) => merchant.deleteProduct(id);
  Future<void> syncMerchantCatalogToCloud() =>
      merchant.syncMerchantCatalogToCloud();
  Future<void> refreshMerchantIncomingOrders() =>
      merchant.refreshMerchantIncomingOrders();
  List<ActiveOrder> get merchantIncomingOrders =>
      merchant.merchantIncomingOrders;
  int get totalSales => merchant.totalSales;
  int get productCount => merchant.productCount;
  Future<void> markMerchantOrderAsRead(String orderId) async {
    final incoming = merchant.merchantIncomingOrders;
    final index = incoming.indexWhere((item) => item.id == orderId);
    if (index == -1) return;
    final order = incoming[index];
    if (order.merchantReadAt != null &&
        order.merchantReadAt!.trim().isNotEmpty) {
      return;
    }
    final nowIso = DateTime.now().toIso8601String();
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
      merchantLatitude: order.merchantLatitude,
      merchantLongitude: order.merchantLongitude,
      requiresDelivery: order.requiresDelivery,
      codConfirmed: order.codConfirmed,
      deliveredAt: order.deliveredAt,
      estimatedArrivalMinutes: order.estimatedArrivalMinutes,
      estimatedArrivalAt: order.estimatedArrivalAt,
      courierPhone: order.courierPhone,
      customerLatitude: order.customerLatitude,
      customerLongitude: order.customerLongitude,
      createdAt: order.createdAt,
      merchantReadAt: nowIso,
      merchantDecisionAt: order.merchantDecisionAt,
      isPriceLocked: order.isPriceLocked,
    );
    notifyListeners();
    try {
      await SupabaseService.saveCustomerOrder(order.customerPhone, updated);
    } catch (error) {
      debugPrint('MARK_ORDER_READ_ERROR: $error');
    }
  }

  Future<bool> proposeMerchantOrderAdjustment(
    String orderId,
    List<OrderLineItem> adjustedLineItems,
  ) async {
    final incoming = merchant.merchantIncomingOrders;
    final index = incoming.indexWhere((item) => item.id == orderId);
    if (index == -1) return false;
    final order = incoming[index];
    if (order.statusKey != 'pending') return false;
    if (adjustedLineItems.isEmpty) return false;
    final availableCount =
        adjustedLineItems.where((item) => item.isAvailable).length;
    if (availableCount == 0) return false;
    notifyListeners();
    return true;
  }

  void loadInitialData(List<ListItem> initialItems) =>
      merchant.loadInitialData(initialItems, persist: false);

  void updateOrderStatus(
    String orderId,
    String newStatusKey,
    String statusAr,
    String statusEn, {
    String? noteAr,
    String? noteEn,
  }) {
    final isMerchant = userRole == 'merchant' || userRole == 'admin';
    final list = isMerchant ? merchant.merchantIncomingOrders : _ordersState.orders;
    final index = list.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = list[index];

    var effectiveStatusKey = newStatusKey;
    var effectiveStatusAr = statusAr;
    var effectiveStatusEn = statusEn;

    if (isMerchant &&
        effectiveStatusKey == 'accepted' &&
        order.requiresDelivery) {
      effectiveStatusKey = 'delivering';
      effectiveStatusAr = 'جاهز للتوصيل';
      effectiveStatusEn = 'Ready for Delivery';
    }

    final previousStatus = order.statusKey;
    final nowIso = DateTime.now().toIso8601String();
    final isDecisionStatus = effectiveStatusKey == 'accepted' ||
        effectiveStatusKey == 'delivering' ||
        effectiveStatusKey == 'cancelled';
    final lockPrice = order.isPriceLocked ||
        effectiveStatusKey == 'accepted' ||
        effectiveStatusKey == 'delivering';

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
      statusKey: effectiveStatusKey,
      statusAr: effectiveStatusAr,
      statusEn: effectiveStatusEn,
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
      merchantLatitude: order.merchantLatitude,
      merchantLongitude: order.merchantLongitude,
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

    if (isMerchant) {
      merchant.replaceIncomingOrder(updated);
      _notificationHub.onMerchantOrderStatusChanged(
        updated,
        previousStatus,
        effectiveStatusKey,
      );
      final phone = _trimmedOrNull(auth.authPhone);
      if (phone != null) {
        unawaited(
          SupabaseService.updateIncomingOrderStatus(
            phone,
            orderId,
            statusKey: effectiveStatusKey,
            statusAr: effectiveStatusAr,
            statusEn: effectiveStatusEn,
            noteAr: noteAr,
            noteEn: noteEn,
          ).then((_) => merchant.refreshMerchantIncomingOrders()),
        );
      }
    } else {
      _ordersState.orders[index] = updated;
      unawaited(_persistCustomerOrder(updated));
    }
    notifyListeners();
  }

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
      case 'adjustment_pending':
        return 'بانتظار موافقة الزبون على التعديل';
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
      case 'adjustment_pending':
        return 'Awaiting customer approval';
      default:
        return statusKey;
    }
  }

  // ── DRIVER ───────────────────────────────────────────────────────
  String? get driverType => driver.driverType;
  Map<String, dynamic>? get driverProfile => driver.driverProfile;
  bool get hasDriverProfile => driver.hasDriverProfile;
  bool get isDriverApproved => driver.isDriverApproved;
  bool get isDriver => driver.isDriver;
  bool get driverAcceptsTaxi => driver.driverAcceptsTaxi;
  bool get driverAcceptsDelivery => driver.driverAcceptsDelivery;
  bool get driverAcceptsBoth => driver.driverAcceptsBoth;
  String get driverServiceModeLabelAr => driver.driverServiceModeLabelAr;
  String get driverServiceModeLabelEn => driver.driverServiceModeLabelEn;
  String get driverDisplayName => driver.driverDisplayName;

  void setDriverType(String type) => driver.setDriverType(type);
  Future<void> setDriverProfile(Map<String, dynamic> profile) =>
      driver.setDriverProfile(profile);
  Future<void> setDriverAvailability(bool available) =>
      driver.setDriverAvailability(available);
  Future<void> setDriverServiceEnabled(String service, bool enabled) =>
      driver.setDriverServiceEnabled(service, enabled);

  // ── DELIVERY ────────────────────────────────────────────────────
  List<ActiveOrder> _courierPoolOrders = [];
  List<ActiveOrder> _courierAssignedOrders = [];

  Map<String, dynamic>? get courierProfile => delivery.courierProfile;
  bool get hasCourierProfile => delivery.hasCourierProfile;
  bool get hasCourierRegistration => delivery.hasCourierRegistration;
  bool get isCourierApproved => delivery.isCourierApproved;
  bool get canUseCourierAccount => delivery.canUseCourierAccount;
  bool get isDelivery => delivery.isDelivery;
  String get deliveryCourierName => delivery.deliveryCourierName;
  String get courierPhone => delivery.courierPhone;
  bool get isCourierAvailable => delivery.isCourierAvailable;

  Future<void> setCourierProfile(Map<String, dynamic> profile) =>
      delivery.setCourierProfile(profile);
  Future<void> setCourierAvailability(bool available) =>
      delivery.setCourierAvailability(available);

  Future<void> refreshCourierOrders() async {
    final phone = _trimmedOrNull(auth.authPhone);
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

  List<RoleBannerData> pollCourierBanners() => [];

  List<ActiveOrder> get deliveryIncomingOrders =>
      List<ActiveOrder>.unmodifiable(_courierPoolOrders);

  List<ActiveOrder> get deliveryActiveOrders =>
      List<ActiveOrder>.unmodifiable(_courierAssignedOrders.where((order) {
        return const {
          'accepted', 'picked_up', 'on_way', 'delivering',
        }.contains(order.deliveryStatusKey);
      }));

  List<ActiveOrder> get deliveryCompletedOrders =>
      List<ActiveOrder>.unmodifiable(_courierAssignedOrders.where((order) {
        return const {'delivered', 'completed', 'done'}
            .contains(order.deliveryStatusKey);
      }));

  int _deliveryFeeFromOrder(ActiveOrder order) {
    final arMatch = RegExp(r'رسوم التوصيل:\s*(\d+)').firstMatch(order.noteAr);
    if (arMatch != null) return int.tryParse(arMatch.group(1) ?? '') ?? 0;
    final enMatch = RegExp(r'Delivery fee:\s*(\d+)').firstMatch(order.noteEn);
    if (enMatch != null) return int.tryParse(enMatch.group(1) ?? '') ?? 0;
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
      0, (sum, order) => sum + _deliveryFeeFromOrder(order));

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

  Future<void> refreshCourierApprovalIfNeeded() async =>
      delivery.refreshCourierApprovalIfNeeded();
  Future<void> handleCourierStatusPush() async =>
      delivery.handleCourierStatusPush();

  List<ActiveOrder> get visibleDeliveryIncomingOrders => deliveryIncomingOrders;
  List<ActiveOrder> get visibleDeliveryActiveOrders => deliveryActiveOrders;
  List<ActiveOrder> get visibleDeliveryCompletedOrders =>
      deliveryCompletedOrders;

  Future<void> acceptDeliveryOrder(String orderId) async {
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) return;

    ActiveOrder? target;
    for (final o in _courierPoolOrders) {
      if (o.id == orderId) { target = o; break; }
    }
    if (target != null && target.groupId != null) {
      await acceptDeliveryGroup(target.groupId!);
      return;
    }

    try {
      await SupabaseService.acceptDeliveryOrder(
        phone, orderId,
        courierName: deliveryCourierName,
      );
      await refreshCourierOrders();
    } catch (error) {
      debugPrint('ACCEPT_DELIVERY_ERROR: $error');
    }
  }

  Future<void> acceptDeliveryGroup(String groupId) async {
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) return;
    final related = _courierPoolOrders.where((o) => o.groupId == groupId).toList();
    if (related.isEmpty) return;
    try {
      for (final order in related) {
        await SupabaseService.acceptDeliveryOrder(
          phone, order.id,
          courierName: deliveryCourierName,
        );
      }
      await refreshCourierOrders();
    } catch (error) {
      debugPrint('ACCEPT_GROUP_ERROR: $error');
    }
  }

  Future<void> rejectDeliveryOrder(String orderId) async {
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) return;

    ActiveOrder? target;
    for (final o in _courierPoolOrders) {
      if (o.id == orderId) { target = o; break; }
    }
    if (target != null && target.groupId != null) {
      await rejectDeliveryGroup(target.groupId!);
      return;
    }

    try {
      await SupabaseService.rejectDeliveryOrder(phone, orderId);
      _courierPoolOrders.removeWhere((order) => order.id == orderId);
      notifyListeners();
      await refreshCourierOrders();
    } catch (error) {
      debugPrint('REJECT_DELIVERY_ERROR: $error');
    }
  }

  Future<void> rejectDeliveryGroup(String groupId) async {
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) return;
    final related = _courierPoolOrders.where((o) => o.groupId == groupId).toList();
    if (related.isEmpty) return;
    try {
      for (final order in related) {
        await SupabaseService.rejectDeliveryOrder(phone, order.id);
      }
      _courierPoolOrders.removeWhere((o) => o.groupId == groupId);
      notifyListeners();
      await refreshCourierOrders();
    } catch (error) {
      debugPrint('REJECT_GROUP_ERROR: $error');
    }
  }

  Future<void> _updateCourierDeliveryStatus(
    String orderId, String deliveryStatusKey,
    String deliveryStatusAr, String deliveryStatusEn,
  ) async {
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) return;
    try {
      await SupabaseService.updateDeliveryOrderStatus(
        phone, orderId,
        deliveryStatusKey: deliveryStatusKey,
        deliveryStatusAr: deliveryStatusAr,
        deliveryStatusEn: deliveryStatusEn,
      );
      await refreshCourierOrders();
    } catch (error) {
      debugPrint('UPDATE_DELIVERY_STATUS_ERROR: $error');
    }
  }

  Future<void> markDeliveryPickedUp(String orderId) async =>
      _updateCourierDeliveryStatus(
        orderId, 'picked_up', 'تم استلام الطلب من المتجر', 'Order picked up from store',
      );

  Future<void> markDeliveryOnTheWay(String orderId) async {
    ActiveOrder? target;
    for (final o in _courierAssignedOrders) {
      if (o.id == orderId) { target = o; break; }
    }
    if (target != null && target.groupId != null) {
      final related = _courierAssignedOrders
          .where((o) => o.groupId == target!.groupId).toList();
      for (final order in related) {
        await _updateCourierDeliveryStatus(
          order.id, 'on_way', 'في الطريق للزبون', 'On the way to customer',
        );
      }
      return;
    }
    await _updateCourierDeliveryStatus(
      orderId, 'on_way', 'في الطريق للزبون', 'On the way to customer',
    );
  }

  Future<void> markDeliveryCompleted(String orderId) async {
    ActiveOrder? target;
    for (final o in _courierAssignedOrders) {
      if (o.id == orderId) { target = o; break; }
    }
    if (target != null && target.groupId != null) {
      final related = _courierAssignedOrders
          .where((o) => o.groupId == target!.groupId).toList();
      for (final order in related) {
        await _updateCourierDeliveryStatus(
          order.id, 'delivered', 'تم التسليم — دفع نقداً', 'Delivered — cash collected',
        );
      }
      return;
    }
    await _updateCourierDeliveryStatus(
      orderId, 'delivered', 'تم التسليم — دفع نقداً', 'Delivered — cash collected',
    );
  }

  // ── ADMIN ────────────────────────────────────────────────────────
  bool get isAdmin => auth.isAdmin;
  AdminRole? get adminRole => _adminRole;
  int get adminRoleLevel => _adminRole?.level ?? 0;
  bool get isSuperAdmin => _adminRole == AdminRole.superAdmin;
  bool get isModerator =>
      _adminRole == AdminRole.moderator ||
      _adminRole == AdminRole.admin ||
      _adminRole == AdminRole.superAdmin;

  bool hasAdminPermission(AdminPermission permission) {
    if (_adminRole == null) return false;
    return permissionsForRole(_adminRole!).contains(permission);
  }

  Map<String, dynamic>? get adminReports => admin.adminReports;
  String? get adminReportsError => admin.adminReportsError;
  List<Map<String, dynamic>> get allMerchants => admin.allMerchants;
  List<Map<String, dynamic>> get allCouriers => admin.allCouriers;
  List<Map<String, dynamic>> get allDrivers => admin.allDrivers;

  Future<void> refreshAllMerchants() => admin.refreshAllMerchants();
  Future<void> refreshAllCouriers() => admin.refreshAllCouriers();
  Future<void> refreshAllDrivers() => admin.refreshAllDrivers();
  Future<void> deleteDriverAccount(String driverPhone) =>
      admin.deleteDriverAccount(driverPhone);
  Future<void> rejectCourierApplication(
    String courierPhone,
    String reasonKey, {
    String? rejectionMessageAr,
  }) =>
      admin.rejectCourierApplication(
        courierPhone, reasonKey,
        rejectionMessageAr: rejectionMessageAr,
      );
  Future<void> toggleMerchantApproval(
          String merchantPhone, bool isApproved) async =>
      admin.toggleMerchantApproval(merchantPhone, isApproved);
  Future<void> rejectMerchantApplication(
    String merchantPhone,
    String reasonKey, {
    String? rejectionMessageAr,
  }) =>
      admin.rejectMerchantApplication(
        merchantPhone, reasonKey,
        rejectionMessageAr: rejectionMessageAr,
      );
  Future<void> toggleCourierApproval(String courierPhone, bool isApproved) =>
      admin.toggleCourierApproval(courierPhone, isApproved);
  Future<void> toggleDriverApproval(String driverPhone, bool isApproved) =>
      admin.toggleDriverApproval(driverPhone, isApproved);
  Future<void> rejectDriverApplication(
    String driverPhone,
    String reasonKey, {
    String? rejectionMessageAr,
  }) =>
      admin.rejectDriverApplication(
        driverPhone, reasonKey,
        rejectionMessageAr: rejectionMessageAr,
      );
  Future<Map<String, dynamic>> toggleMerchantBazaarMember(
          String merchantPhone, bool isBazaarMember) =>
      admin.toggleMerchantBazaarMember(merchantPhone, isBazaarMember);
  Future<void> toggleMerchantFrozen(
          String merchantPhone, bool isFrozen) async =>
      admin.toggleMerchantFrozen(merchantPhone, isFrozen);
  Future<void> refreshAdminReports() => admin.refreshAdminReports();

  Map<String, HomeCategoryPlatformOverride> get homeCategoryOverrides =>
      admin.homeCategoryOverrides;
  List<ServiceCategory> get visibleHomeCategories =>
      admin.visibleHomeCategories;
  bool isHomeCategoryEnabled(String categoryId) =>
      admin.isHomeCategoryEnabled(categoryId);
  bool homeCategoryEnabledOnPlatform(String categoryId, String platform) =>
      admin.homeCategoryEnabledOnPlatform(categoryId, platform);
  Future<void> refreshHomeCategoriesConfig() =>
      admin.refreshHomeCategoriesConfig();
  Future<bool> setHomeCategoryPlatformEnabled(
    String categoryId,
    String platform,
    bool enabled,
  ) =>
      admin.setHomeCategoryPlatformEnabled(categoryId, platform, enabled);

  // ── TAXI ─────────────────────────────────────────────────────────
  List<TaxiRequest> _taxiRequests = [];
  List<TaxiRequest> _taxiPoolRequests = [];
  List<TaxiRequest> _taxiDriverAssignedRequests = [];

  List<TaxiRequest> get taxiRequests =>
      List<TaxiRequest>.unmodifiable(_taxiRequests);

  List<TaxiRequest> get visibleTaxiRequests {
    if (driver.isDriver) {
      return List<TaxiRequest>.unmodifiable(_mergedTaxiSnapshotList());
    }
    return List<TaxiRequest>.unmodifiable(_taxiRequests);
  }

  List<TaxiRequest> get visibleTaxiIncomingRequests {
    if (driver.isDriver) {
      return List<TaxiRequest>.unmodifiable(_taxiPoolRequests);
    }
    return List<TaxiRequest>.unmodifiable(
      _taxiRequests.where((r) =>
          r.statusKey == 'pending' || r.statusKey == 'new'),
    );
  }

  List<TaxiRequest> _dedupeTaxiById(Iterable<TaxiRequest> requests) {
    final byId = <String, TaxiRequest>{};
    for (final request in requests) {
      final id = request.id.trim();
      if (id.isEmpty) continue;
      byId[id] = request;
    }
    return byId.values.toList();
  }

  List<TaxiRequest> get visibleTaxiActiveRequests {
    final source = driver.isDriver ? _taxiDriverAssignedRequests : _taxiRequests;
    return List<TaxiRequest>.unmodifiable(_dedupeTaxiById(source.where((r) {
      return const {
        'accepted', 'on_way', 'arrived', 'picked_up', 'in_progress',
        'cancel_requested',
      }.contains(r.statusKey);
    })));
  }

  List<TaxiRequest> get visibleTaxiCompletedRequests {
    final source = driver.isDriver ? _taxiDriverAssignedRequests : _taxiRequests;
    return List<TaxiRequest>.unmodifiable(_dedupeTaxiById(source.where((r) {
      return const {'completed', 'done', 'finished'}.contains(r.statusKey);
    })));
  }

  List<TaxiRequest> _mergedTaxiSnapshotList() {
    if (driver.isDriver) {
      final merged = <String, TaxiRequest>{};
      for (final r in _taxiPoolRequests) {
        merged[r.id] = r;
      }
      for (final r in _taxiDriverAssignedRequests) {
        merged[r.id] = r;
      }
      return merged.values.toList();
    }
    return List<TaxiRequest>.from(_taxiRequests);
  }

  Future<void> refreshTaxiRequests() async {
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      if (driver.isDriver) {
        final results = await Future.wait([
          SupabaseService.loadTaxiPool(phone),
          SupabaseService.loadDriverTaxiOrders(phone),
        ]);
        _taxiPoolRequests = _dedupeTaxiById(results[0]);
        _taxiDriverAssignedRequests = _dedupeTaxiById(results[1]);
      } else if (customer.isCustomer) {
        _taxiRequests = await SupabaseService.loadCustomerTaxiRequests(phone);
      }
      notifyListeners();
    } catch (error) {
      debugPrint('TAXI_REQUESTS_LOAD_ERROR: $error');
    }
  }

  Future<void> refreshDriverTaxiRequests() => refreshTaxiRequests();
  List<RoleBannerData> pollTaxiBanners() => [];
  Future<bool> addTaxiRequest(TaxiRequest request) async {
    try {
      await SupabaseService.saveTaxiRequest(request.customerPhone, request);
      await refreshTaxiRequests();
      return true;
    } catch (error) {
      debugPrint('ADD_TAXI_ERROR: $error');
      return false;
    }
  }

  Future<void> acceptTaxiRequest(String requestId) async {
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) return;
    try {
      await SupabaseService.acceptTaxiRequest(
        phone, requestId,
        driverName: driver.driverDisplayName,
        vehicleType: driver.driverProfile?['vehicle']?.toString(),
      );
      await refreshTaxiRequests();
    } catch (error) {
      debugPrint('ACCEPT_TAXI_ERROR: $error');
    }
  }

  Future<void> rejectTaxiRequest(String requestId) async {
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) return;
    try {
      await SupabaseService.rejectTaxiRequest(phone, requestId);
      _taxiPoolRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
      await refreshTaxiRequests();
    } catch (error) {
      debugPrint('REJECT_TAXI_ERROR: $error');
    }
  }

  Future<void> _updateTaxiStatus(
    String requestId, String statusKey, String statusAr, String statusEn,
  ) async {
    final phone = _trimmedOrNull(auth.authPhone);
    if (phone == null) return;
    await SupabaseService.updateTaxiRequestStatus(
      phone, requestId,
      statusKey: statusKey, statusAr: statusAr, statusEn: statusEn,
    );
    await refreshTaxiRequests();
  }

  Future<void> markTaxiOnWay(String id) =>
      _updateTaxiStatus(id, 'on_way', 'في الطريق', 'On the way');
  Future<void> markTaxiArrived(String id) =>
      _updateTaxiStatus(id, 'arrived', 'وصل السائق', 'Driver arrived');
  Future<void> markTaxiPickedUp(String id) =>
      _updateTaxiStatus(id, 'picked_up', 'تمت الركوب', 'Picked up');
  Future<void> completeTaxiRequest(String id) =>
      _updateTaxiStatus(id, 'completed', 'مكتمل', 'Completed');
  Future<void> approveTaxiCancellationByDriver(String requestId) =>
      _updateTaxiStatus(requestId, 'cancelled', 'ملغي بموافقة السائق', 'Cancelled by driver');
  Future<void> rejectTaxiCancellationByDriver(String requestId) =>
      _updateTaxiStatus(requestId, 'accepted', 'مقبول', 'Accepted');

  Future<String?> cancelTaxiRequestByCustomer(String requestId) async {
    TaxiRequest? request;
    for (final r in _taxiRequests) {
      if (r.id == requestId) {
        request = r;
        break;
      }
    }
    if (request == null) return 'الطلب غير موجود';
    if (request.statusKey == 'completed' || request.statusKey == 'cancelled') {
      return 'لا يمكن إلغاء هذا الطلب';
    }
    if (request.statusKey == 'picked_up') {
      return 'لا يمكن الإلغاء بعد بدء الرحلة';
    }
    await _updateTaxiStatus(requestId, 'cancelled', 'ملغي', 'Cancelled');
    return null;
  }

  // ── THEME / UI ───────────────────────────────────────────────────
  ThemeMode get themeMode => _ui.themeMode;
  bool get darkMode => _ui.darkMode;
  bool get inAppAlertsEnabled => _ui.inAppAlertsEnabled;

  Future<void> setDarkMode(bool enabled) async {
    _ui.darkMode = enabled;
    notifyListeners();
    await _persistUiState();
  }

  Future<void> toggleDarkMode() => setDarkMode(!_ui.darkMode);

  Future<void> setInAppAlertsEnabled(bool enabled) async {
    _ui.inAppAlertsEnabled = enabled;
    if (!enabled) {
      _notificationInbox.clearUnreadPrompt();
    }
    notifyListeners();
    await _persistUiState();
  }

  Future<void> _persistUiState() async {
    final phone = auth.authPhone?.trim();
    if (phone == null || phone.isEmpty) return;
    try {
      await SupabaseService.saveUserState(
        phone,
        AppStatePolicy.stripForRemotePersist(_ui.toRemoteState()),
      );
    } catch (error) {
      debugPrint('PERSIST_UI_STATE_ERROR: $error');
    }
  }

  void arePendingApprovals(bool value) {
    // Kept for external callers
  }

  // ── NOTIFICATIONS ────────────────────────────────────────────────
  List<AppNotificationItem> get notifications {
    final audience = auth.userRole;
    if (audience == null) return const [];
    return _notificationInbox.forAudience(audience);
  }

  int get unreadNotificationCount {
    final audience = auth.userRole;
    if (audience == null) return 0;
    return _notificationInbox.unreadCountFor(audience);
  }

  List<AppNotificationItem> unreadNotificationsForRole(String role) {
    return _notificationInbox.unreadForRole(role);
  }

  String? takePendingUnreadPromptRole() {
    return _notificationInbox.takePendingUnreadPromptRole();
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
    final id = _notificationInbox.add(
      title,
      body,
      audience: audience,
      orderNumber: orderNumber,
      category: category,
      priority: priority,
      eventKey: eventKey,
    );
    notifyListeners();
    return id;
  }

  void markNotificationRead(String id) {
    if (!_notificationInbox.markRead(id)) return;
    notifyListeners();
  }

  void markNotificationsReadForOrder(String orderNumber, String audience) {
    if (!_notificationInbox.markReadForOrder(orderNumber, audience)) return;
    notifyListeners();
  }

  void markNotificationReadByTitleBody(
      String title, String body, String audience) {
    if (!_notificationInbox.markReadByTitleBody(title, body, audience)) return;
    notifyListeners();
  }

  // ── TABS & NAVIGATION ────────────────────────────────────────────
  void requestMainShellTab(int index) {
    _navigation.requestMainShellTab(index);
    notifyListeners();
  }

  int? takePendingMainTab() => _navigation.takePendingMainTab();

  int? takePendingMerchantTab() => _navigation.takePendingMerchantTab();

  int? takePendingDeliveryTab() => _navigation.takePendingDeliveryTab();

  int? takePendingDriverTab() => _navigation.takePendingDriverTab();

  void setPendingOrderId(String role, String? orderId) {
    _navigation.setPendingOrderId(role, orderId);
  }

  String? takePendingOrderId(String role) =>
      _navigation.takePendingOrderId(role);

  void requestTabForRole(String role, int index) {
    _navigation.requestTabForRole(role, index);
    notifyListeners();
  }

  void handleNotificationOpen(Map<String, dynamic> data) {
    final eventKey = data['eventKey']?.toString() ?? '';
    final role = data['role']?.toString() ?? auth.userRole ?? 'customer';
    final orderId = data['orderId']?.toString().trim() ??
        _extractOrderIdFromEventKey(eventKey);
    final hasOrderId = orderId != null && orderId.isNotEmpty;

    debugPrint(
        'Push: handleNotificationOpen event=$eventKey targetRole=$role orderId=$orderId');

    if (eventKey == 'call:incoming') {
      return;
    }

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
    } else if (eventKey.contains('taxi')) {
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

  // ── Helpers ──────────────────────────────────────────────────────
  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _generateUuid() {
    final rng = math.Random.secure();
    const hex = '0123456789abcdef';
    String seg(int len) =>
        List.generate(len, (_) => hex[rng.nextInt(16)]).join();
    return '${seg(8)}-${seg(4)}-4${seg(3)}-${hex[8 + rng.nextInt(4)]}${seg(3)}-${seg(12)}';
  }

  String? get sessionPhone => auth.authPhone;
  Future<String?> getValidToken() async => auth.sessionToken;

}
