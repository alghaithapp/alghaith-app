import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/app_state_policy.dart';
import '../../core/utils/phone_utils.dart';
import '../../models/app_models.dart';
import '../../models/home_category_platform_override.dart';
import '../../modules/taxi/models/taxi_request.dart';
import '../models/account_snapshot.dart';


/// الوصول إلى قاعدة البيانات عبر Railway فقط — لا اتصال مباشر بـ Supabase من التطبيق.
class DatabaseRepository {
  DatabaseRepository._();

  static final DatabaseRepository instance = DatabaseRepository._();

  String _phone(String phone) => PhoneUtils.normalize(phone);

  Future<Map<String, dynamic>?> loadAppUser(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/app-user',
      queryParameters: {'phone': _phone(phone)},
    );
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<Map<String, dynamic>?> loadMerchantProfile(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/merchant-profile',
      queryParameters: {'phone': _phone(phone)},
    );
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<List<Map<String, dynamic>>> loadMerchantProducts(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/merchant-products',
      queryParameters: {'phone': _phone(phone)},
    );
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>?> loadUserState(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/user-state',
      queryParameters: {'phone': _phone(phone)},
    );
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<List<Map<String, dynamic>>> loadProfessionalProfiles({
    String? professionId,
  }) async {
    final result = await ApiClient.instance.get(
      '/db/professionals',
      queryParameters: {
        if (professionId != null && professionId.trim().isNotEmpty)
          'professionId': professionId.trim(),
      },
    );
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadShoppingStores({
    String? subCategoryId,
  }) async {
    final result = await ApiClient.instance.get(
      '/db/shopping-stores',
      queryParameters: {
        if (subCategoryId != null && subCategoryId.trim().isNotEmpty)
          'subCategoryId': subCategoryId.trim(),
      },
    );
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadRestaurantStores({
    String? subCategoryId,
  }) async {
    final result = await ApiClient.instance.get(
      '/db/restaurant-stores',
      queryParameters: {
        if (subCategoryId != null && subCategoryId.trim().isNotEmpty)
          'subCategoryId': subCategoryId.trim(),
      },
    );
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadServiceStores({
    required String serviceId,
    String? productCategory,
    String? subCategoryId,
    String? marketplaceCategory,
  }) async {
    final result = await ApiClient.instance.get(
      '/db/service-stores',
      queryParameters: {
        'serviceId': serviceId.trim(),
        if (productCategory != null && productCategory.trim().isNotEmpty)
          'productCategory': productCategory.trim(),
        if (subCategoryId != null && subCategoryId.trim().isNotEmpty)
          'subCategoryId': subCategoryId.trim(),
        if (marketplaceCategory != null &&
            marketplaceCategory.trim().isNotEmpty)
          'marketplaceCategory': marketplaceCategory.trim(),
      },
    );
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadOffersCatalog() async {
    final result = await ApiClient.instance.get('/db/offer-catalog-products');
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> loadMarketplaceStats() async {
    final result = await ApiClient.instance.get('/db/marketplace-stats');
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return const {};
  }

  Future<Map<String, dynamic>> validatePromoCode({
    required String code,
    required int subtotalIqd,
  }) async {
    final result = await ApiClient.instance.post(
      '/db/validate-promo',
      body: {
        'code': code.trim(),
        'subtotalIqd': subtotalIqd,
      },
    );
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return const {'valid': false, 'messageAr': 'تعذر التحقق من كود الخصم.'};
  }

  Future<List<Map<String, dynamic>>> loadCatalog({
    String? category,
    String? subCategoryId,
  }) async {
    final result = await ApiClient.instance.get(
      '/db/catalog',
      queryParameters: {
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (subCategoryId != null && subCategoryId.trim().isNotEmpty)
          'subCategoryId': subCategoryId.trim(),
      },
    );
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<ActiveOrder>> loadMerchantIncomingOrders(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/merchant-incoming-orders',
      queryParameters: {'phone': _phone(phone)},
    );
    if (result is! List) return const [];
    return result
        .map((item) => ActiveOrder.fromMap(
              Map<String, dynamic>.from(item['order_payload'] as Map),
            ))
        .toList();
  }

  Future<void> updateIncomingOrderStatus(
    String merchantPhone,
    String orderId, {
    required String statusKey,
    required String statusAr,
    required String statusEn,
    String? noteAr,
    String? noteEn,
    String? deliveryStatusKey,
    String? deliveryStatusAr,
    String? deliveryStatusEn,
    List<Map<String, dynamic>>? lineItems,
    int? price,
    int? itemsCount,
    String? itemsNameAr,
    String? itemsNameEn,
    int? originalPrice,
    int? itemsSubtotalIqd,
    int? deliveryFeeIqd,
    int? promoDiscountIqd,
    String? merchantDecisionAt,
    bool? isPriceLocked,
  }) async {
    await ApiClient.instance.put('/db/incoming-order-status', body: {
      'phone': _phone(merchantPhone),
      'orderId': orderId,
      'statusKey': statusKey,
      'statusAr': statusAr,
      'statusEn': statusEn,
      if (noteAr != null) 'noteAr': noteAr,
      if (noteEn != null) 'noteEn': noteEn,
      if (deliveryStatusKey != null) 'deliveryStatusKey': deliveryStatusKey,
      if (deliveryStatusAr != null) 'deliveryStatusAr': deliveryStatusAr,
      if (deliveryStatusEn != null) 'deliveryStatusEn': deliveryStatusEn,
      if (lineItems != null) 'lineItems': lineItems,
      if (price != null) 'price': price,
      if (itemsCount != null) 'itemsCount': itemsCount,
      if (itemsNameAr != null) 'itemsNameAr': itemsNameAr,
      if (itemsNameEn != null) 'itemsNameEn': itemsNameEn,
      if (originalPrice != null) 'originalPrice': originalPrice,
      if (itemsSubtotalIqd != null) 'itemsSubtotalIqd': itemsSubtotalIqd,
      if (deliveryFeeIqd != null) 'deliveryFeeIqd': deliveryFeeIqd,
      if (promoDiscountIqd != null) 'promoDiscountIqd': promoDiscountIqd,
      if (merchantDecisionAt != null) 'merchantDecisionAt': merchantDecisionAt,
      if (isPriceLocked != null) 'isPriceLocked': isPriceLocked,
    });
  }

  List<ActiveOrder> _mapOrderRows(dynamic result) {
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => ActiveOrder.fromMap(
              Map<String, dynamic>.from(item['order_payload'] as Map),
            ))
        .toList();
  }

  Future<List<ActiveOrder>> loadDeliveryPool(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/delivery-pool',
      queryParameters: {'phone': _phone(phone)},
    );
    return _mapOrderRows(result);
  }

  Future<List<ActiveOrder>> loadCourierOrders(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/courier-orders',
      queryParameters: {'phone': _phone(phone)},
    );
    return _mapOrderRows(result);
  }

  Future<void> acceptDeliveryOrder(
    String courierPhone,
    String orderId, {
    String? courierName,
  }) async {
    await ApiClient.instance.put('/db/delivery-order/accept', body: {
      'phone': _phone(courierPhone),
      'orderId': orderId,
      if (courierName != null && courierName.trim().isNotEmpty)
        'courierName': courierName.trim(),
    });
  }

  Future<void> updateDeliveryOrderStatus(
    String courierPhone,
    String orderId, {
    required String deliveryStatusKey,
    String? deliveryStatusAr,
    String? deliveryStatusEn,
  }) async {
    await ApiClient.instance.put('/db/delivery-order/status', body: {
      'phone': _phone(courierPhone),
      'orderId': orderId,
      'deliveryStatusKey': deliveryStatusKey,
      if (deliveryStatusAr != null) 'deliveryStatusAr': deliveryStatusAr,
      if (deliveryStatusEn != null) 'deliveryStatusEn': deliveryStatusEn,
    });
  }

  Future<void> rejectDeliveryOrder(String courierPhone, String orderId) async {
    await ApiClient.instance.put('/db/delivery-order/reject', body: {
      'phone': _phone(courierPhone),
      'orderId': orderId,
    });
  }

  Future<void> saveDeviceToken({
    required String phone,
    required String token,
    required String platform,
  }) async {
    await ApiClient.instance.put('/db/device-token', body: {
      'phone': _phone(phone),
      'token': token,
      'platform': platform,
    });
  }

  Future<void> deleteDeviceToken({
    required String phone,
    required String token,
  }) async {
    await ApiClient.instance.delete(
      '/db/device-token',
      queryParameters: {
        'phone': _phone(phone),
        'token': token,
      },
    );
  }

  Future<void> markPushInboxOpened({required String phone}) async {
    await ApiClient.instance.put('/db/push-inbox/opened', body: {
      'phone': _phone(phone),
    });
  }

  /// تحميل كل بيانات المستخدم من السيرفر دفعة واحدة (تُستدعى بعد تسجيل الدخول).
  Future<RemoteAccountBundle> loadAccountBundle(String phone) async {
    final normalized = _phone(phone);
    
    Future<T> safe<T>(Future<T> request, T fallback) async {
      try {
        return await request;
      } catch (e) {
        debugPrint('loadAccountBundle safe fetch error: $e');
        return fallback;
      }
    }

    final appUser = await safe(loadAppUser(normalized), null);
    final customerProfile = await safe(_loadCustomerProfile(normalized), null);
    final addresses = await safe(_loadCustomerAddresses(normalized), <String>[]);
    final favoriteIds = await safe(_loadCustomerFavoriteIds(normalized), <String>[]);
    final merchantProfile = await safe(loadMerchantProfile(normalized), null);
    final driverProfile = await safe(_loadDriverProfile(normalized), null);
    final courierProfile = await safe(_loadCourierProfile(normalized), null);
    final userState = await safe(loadUserState(normalized), null);
    final orders = await safe(_loadCustomerOrders(normalized), <ActiveOrder>[]);
    final products = await safe(loadMerchantProducts(normalized), <Map<String, dynamic>>[]);

    return RemoteAccountBundle(
      appUser: appUser,
      customerProfile: customerProfile,
      addresses: addresses,
      favoriteIds: favoriteIds,
      merchantProfile: merchantProfile,
      driverProfile: driverProfile,
      courierProfile: courierProfile,
      userState: userState,
      orders: orders,
      products: products,
    );
  }

  Future<Map<String, dynamic>?> _loadDriverProfile(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/driver-profile',
      queryParameters: {'phone': phone},
    );
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<Map<String, dynamic>?> _loadCourierProfile(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/courier-profile',
      queryParameters: {'phone': phone},
    );
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<void> saveDriverProfile(
    String phone,
    Map<String, dynamic> profile,
  ) async {
    await ApiClient.instance.put(
      '/db/driver-profile',
      body: {
        'phone': _phone(phone),
        ...profile,
      },
    );
  }

  Future<void> saveCourierProfile(
    String phone,
    Map<String, dynamic> profile,
  ) async {
    await ApiClient.instance.put(
      '/db/courier-profile',
      body: {
        'phone': _phone(phone),
        ...profile,
      },
    );
  }

  Future<Map<String, dynamic>?> _loadCustomerProfile(String phone) async {
    final result = await ApiClient.instance.get('/db/customer-profile', queryParameters: {'phone': phone});
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<List<String>> _loadCustomerAddresses(String phone) async {
    final result = await ApiClient.instance.get('/db/customer-addresses', queryParameters: {'phone': phone});
    if (result is! List) return const [];
    return result.map((e) => e.toString()).toList();
  }

  Future<List<String>> _loadCustomerFavoriteIds(String phone) async {
    final result = await ApiClient.instance.get('/db/customer-favorites', queryParameters: {'phone': phone});
    if (result is! List) return const [];
    return result.map((e) => e.toString()).toList();
  }

  Future<List<ActiveOrder>> _loadCustomerOrders(String phone) async {
    final result = await ApiClient.instance.get('/db/customer-orders', queryParameters: {'phone': phone});
    if (result is! List) return const [];
    return result.map((e) => ActiveOrder.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  // ── دوال مساعدة — stubs للتوافق ──

  Future<Map<String, dynamic>> loadAdminReports(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/admin/reports',
      queryParameters: {'phone': _phone(phone)},
    );
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  }
  Future<Map<String, HomeCategoryPlatformOverride>> loadHomeCategoriesConfig() async {
    final result = await ApiClient.instance.get('/app/home-categories');
    if (result is! Map) return const {};
    final raw = result['overrides'] ?? result;
    if (raw is! Map) return const {};
    final out = <String, HomeCategoryPlatformOverride>{};
    raw.forEach((key, value) {
      final override = HomeCategoryPlatformOverride.fromDynamic(value);
      if (override != null) {
        out[key.toString()] = override;
      }
    });
    return out;
  }

  Future<Map<String, HomeCategoryPlatformOverride>> saveHomeCategoriesConfig({
    required String phone,
    required Map<String, HomeCategoryPlatformOverride> overrides,
  }) async {
    final bodyOverrides = overrides.map((key, value) => MapEntry(key, value.toJson()));
    final result = await ApiClient.instance.put(
      '/db/admin/home-categories',
      body: {
        'phone': _phone(phone),
        'overrides': bodyOverrides,
      },
    );
    if (result is! Map) return const {};
    final raw = result['overrides'] ?? result;
    if (raw is! Map) return const {};
    final out = <String, HomeCategoryPlatformOverride>{};
    raw.forEach((key, value) {
      final override = HomeCategoryPlatformOverride.fromDynamic(value);
      if (override != null) {
        out[key.toString()] = override;
      }
    });
    return out;
  }

  Future<List<Map<String, dynamic>>> loadRealEstateListings({
    String? subCategoryId,
    String? listingMode,
    String? neighborhood,
  }) async {
    final result = await ApiClient.instance.get(
      '/db/real-estate-listings',
      queryParameters: {
        if (subCategoryId != null && subCategoryId.trim().isNotEmpty)
          'subCategoryId': subCategoryId.trim(),
        if (listingMode != null && listingMode.trim().isNotEmpty)
          'listingMode': listingMode.trim(),
        if (neighborhood != null && neighborhood.trim().isNotEmpty)
          'neighborhood': neighborhood.trim(),
      },
    );
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>?> loadCustomerProfile(String phone) async =>
      _loadCustomerProfile(_phone(phone));

  Future<List<String>> loadCustomerAddresses(String phone) async =>
      _loadCustomerAddresses(_phone(phone));

  Future<List<String>> loadCustomerFavoriteIds(String phone) async =>
      _loadCustomerFavoriteIds(_phone(phone));

  Future<List<ActiveOrder>> loadCustomerOrders(String phone) async =>
      _loadCustomerOrders(_phone(phone));

  Future<void> saveAppUser(
    String phone, {
    String? fullName,
    String? role,
    String? accountType,
    String? avatarBase64,
  }) async {
    await ApiClient.instance.put(
      '/db/app-user',
      body: {
        'phone': _phone(phone),
        if (fullName != null) 'fullName': fullName,
        if (role != null) 'role': role,
        if (accountType != null) 'accountType': accountType,
        if (avatarBase64 != null) 'avatarBase64': avatarBase64,
      },
    );
  }

  Future<void> saveMerchantProfile(
    String phone,
    Map<String, dynamic> profile,
  ) async {
    await ApiClient.instance.put(
      '/db/merchant-profile',
      body: {
        'phone': _phone(phone),
        ...profile,
      },
    );
  }

  Future<void> saveMerchantProduct(
    String phone,
    Map<String, dynamic> product,
  ) async {
    await ApiClient.instance.put(
      '/db/merchant-product',
      body: {
        'phone': _phone(phone),
        ...product,
      },
    );
  }

  Future<Map<String, dynamic>> replyMerchantReview(
    String phone,
    String reviewId,
    String reply,
  ) async {
    final result = await ApiClient.instance.put(
      '/db/merchant-review/reply',
      body: {
        'phone': _phone(phone),
        'reviewId': reviewId,
        'reply': reply,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> loadMerchantOffers(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/merchant-offers',
      queryParameters: {'phone': _phone(phone)},
    );
    if (result is! List) return const [];
    return result
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> saveMerchantOffer(
    String phone,
    Map<String, dynamic> offer,
  ) async {
    await ApiClient.instance.put(
      '/db/merchant-offer',
      body: {
        'phone': _phone(phone),
        ...offer,
      },
    );
  }

  Future<void> deleteMerchantOffer(String phone, String offerId) async {
    await ApiClient.instance.delete(
      '/db/merchant-offer',
      queryParameters: {
        'phone': _phone(phone),
        'id': offerId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> loadMerchantReviews(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/merchant-reviews',
      queryParameters: {'phone': _phone(phone)},
    );
    if (result is! List) return const [];
    return result
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> saveUserState(String phone, Map<String, dynamic> state) async {
    await ApiClient.instance.put(
      '/db/user-state',
      body: {
        'phone': _phone(phone),
        'state': AppStatePolicy.stripForRemotePersist(state),
      },
    );
  }

  Future<void> saveCustomerProfile(
    String phone,
    Map<String, dynamic> profile,
  ) async {
    await ApiClient.instance.put(
      '/db/customer-profile',
      body: {
        'phone': _phone(phone),
        ...profile,
      },
    );
  }

  Future<void> saveCustomerAddress(
    String phone,
    String address, {
    int sortOrder = 0,
  }) async {
    await ApiClient.instance.put(
      '/db/customer-address',
      body: {
        'phone': _phone(phone),
        'address': address,
        'sortOrder': sortOrder,
      },
    );
  }

  Future<void> deleteCustomerAddress(String phone, String address) async {
    await ApiClient.instance.delete(
      '/db/customer-address',
      queryParameters: {
        'phone': _phone(phone),
        'address': address,
      },
    );
  }

  Future<void> saveCustomerFavorite(
    String phone,
    String productId, {
    required bool isFavorite,
  }) async {
    await ApiClient.instance.put(
      '/db/customer-favorite',
      body: {
        'phone': _phone(phone),
        'productId': productId,
        'isFavorite': isFavorite,
      },
    );
  }

  Future<void> saveCustomerOrder(String phone, ActiveOrder order) async {
    await ApiClient.instance.put(
      '/db/customer-order',
      body: {
        'phone': _phone(phone),
        'order': order.toMap(),
      },
    );
  }

  Future<void> deleteMerchantProduct(String productId, {String? phone}) async {
    await ApiClient.instance.delete(
      '/db/merchant-product',
      queryParameters: {
        if (phone != null) 'phone': _phone(phone),
        'id': productId,
      },
    );
  }

  Future<void> submitMerchantReview({
    required String merchantPhone,
    required String customerPhone,
    required String customerName,
    required String orderId,
    required int stars,
    String? comment,
  }) async {
    await ApiClient.instance.post(
      '/db/merchant-review',
      body: {
        'merchantPhone': _phone(merchantPhone),
        'customerPhone': _phone(customerPhone),
        'customerName': customerName,
        'orderId': orderId,
        'stars': stars,
        if (comment != null) 'comment': comment,
      },
    );
  }

  Future<List<Map<String, dynamic>>> loadAllMerchants() async {
    final result = await ApiClient.instance.get('/db/admin/merchants');
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadAllDrivers() async {
    final result = await ApiClient.instance.get('/db/admin/drivers');
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> loadAllCouriers() async {
    final result = await ApiClient.instance.get('/db/admin/couriers');
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> toggleMerchantBazaarStatus({
    required String merchantPhone,
    required bool isBazaarMember,
  }) async {
    final result = await ApiClient.instance.put(
      '/db/admin/merchant-bazaar',
      body: {
        'merchantPhone': _phone(merchantPhone),
        'isBazaarMember': isBazaarMember,
      },
    );
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  }

  Future<void> toggleCourierApprovalStatus({
    required String courierPhone,
    required bool isApproved,
  }) async {
    await ApiClient.instance.put(
      '/db/admin/courier-approval',
      body: {
        'courierPhone': _phone(courierPhone),
        'isApproved': isApproved,
      },
    );
  }

  Future<void> toggleDriverApprovalStatus({
    required String driverPhone,
    required bool isApproved,
  }) async {
    await ApiClient.instance.put(
      '/db/admin/driver-approval',
      body: {
        'driverPhone': _phone(driverPhone),
        'isApproved': isApproved,
      },
    );
  }

  Future<void> rejectDriverApplication({
    required String driverPhone,
    required String reasonKey,
    String? rejectionMessageAr,
  }) async {
    await ApiClient.instance.put(
      '/db/admin/driver-rejection',
      body: {
        'driverPhone': _phone(driverPhone),
        'reasonKey': reasonKey,
        if (rejectionMessageAr != null) 'rejectionMessageAr': rejectionMessageAr,
      },
    );
  }

  Future<void> deleteDriverAccount(String adminPhone, String driverPhone) async {
    await ApiClient.instance.delete(
      '/db/admin/driver',
      queryParameters: {
        'phone': _phone(adminPhone),
        'driverPhone': _phone(driverPhone),
      },
    );
  }

  Future<void> rejectCourierApplication({
    required String courierPhone,
    required String reasonKey,
    String? rejectionMessageAr,
  }) async {
    await ApiClient.instance.put(
      '/db/admin/courier-rejection',
      body: {
        'courierPhone': _phone(courierPhone),
        'reasonKey': reasonKey,
        if (rejectionMessageAr != null) 'rejectionMessageAr': rejectionMessageAr,
      },
    );
  }

  Future<void> toggleMerchantFreezeStatus({
    required String merchantPhone,
    required bool isFrozen,
  }) async {
    await ApiClient.instance.put(
      '/db/admin/merchant-freeze',
      body: {
        'merchantPhone': _phone(merchantPhone),
        'isFrozen': isFrozen,
      },
    );
  }

  Future<void> toggleMerchantApprovalStatus({
    required String merchantPhone,
    required bool isApproved,
  }) async {
    await ApiClient.instance.put(
      '/db/admin/merchant-approval',
      body: {
        'merchantPhone': _phone(merchantPhone),
        'isApproved': isApproved,
      },
    );
  }

  Future<void> rejectMerchantApplication({
    required String merchantPhone,
    required String reasonKey,
    String? rejectionMessageAr,
  }) async {
    await ApiClient.instance.put(
      '/db/admin/merchant-rejection',
      body: {
        'merchantPhone': _phone(merchantPhone),
        'reasonKey': reasonKey,
        if (rejectionMessageAr != null) 'rejectionMessageAr': rejectionMessageAr,
      },
    );
  }
  Future<void> deleteAccount(String phone) async {
    await ApiClient.instance.delete(
      '/db/app-user',
      queryParameters: {'phone': _phone(phone)},
    );
  }

  // ── Taxi methods ──────────────────────────────────────────────────

  static List<TaxiRequest> _dedupeTaxiRequests(List<TaxiRequest> requests) {
    final byId = <String, TaxiRequest>{};
    for (final request in requests) {
      final id = request.id.trim();
      if (id.isEmpty) continue;
      byId[id] = request;
    }
    return byId.values.toList();
  }

  Future<List<TaxiRequest>> loadTaxiPool(String phone) async {
    final result = await ApiClient.instance.get('/db/taxi/incoming-requests');
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => TaxiRequest.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<TaxiRequest>> loadDriverTaxiOrders(String phone) async {
    final requests = <TaxiRequest>[];
    try {
      final active = await ApiClient.instance.get('/db/taxi/driver-active');
      if (active is Map) {
        requests.add(
          TaxiRequest.fromMap(Map<String, dynamic>.from(active)),
        );
      }
    } catch (_) {}
    try {
      final history = await ApiClient.instance.get('/db/taxi/driver-history');
      if (history is List) {
        for (final item in history) {
          if (item is Map) {
            requests.add(
              TaxiRequest.fromMap(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
    } catch (_) {}
    return _dedupeTaxiRequests(requests);
  }

  Future<List<TaxiRequest>> loadCustomerTaxiRequests(String phone) async {
    final requests = <TaxiRequest>[];
    try {
      final active = await ApiClient.instance.get('/db/taxi/active');
      if (active is Map) {
        requests.add(
          TaxiRequest.fromMap(Map<String, dynamic>.from(active)),
        );
      }
    } catch (_) {}
    try {
      final history = await ApiClient.instance.get('/db/taxi/history');
      if (history is List) {
        for (final item in history) {
          if (item is Map) {
            requests.add(
              TaxiRequest.fromMap(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
    } catch (_) {}
    return _dedupeTaxiRequests(requests);
  }

  Future<void> saveTaxiRequest(String phone, TaxiRequest request) async {
    await ApiClient.instance.put(
      '/db/taxi-request',
      body: {
        'phone': _phone(phone),
        'request': request.toMap(),
      },
    );
  }

  Future<void> acceptTaxiRequest(
    String phone,
    String requestId, {
    String? driverName,
    String? vehicleType,
  }) async {
    await ApiClient.instance.post(
      '/db/taxi/accept',
      body: {
        'requestId': requestId,
        if (driverName != null && driverName.isNotEmpty) 'driverName': driverName,
        if (vehicleType != null && vehicleType.isNotEmpty) 'vehicleModel': vehicleType,
      },
    );
  }

  Future<void> rejectTaxiRequest(String phone, String requestId) async {
    await ApiClient.instance.post(
      '/db/taxi/reject',
      body: {'requestId': requestId},
    );
  }

  Future<void> updateTaxiRequestStatus(
    String phone,
    String requestId, {
    required String statusKey,
    required String statusAr,
    required String statusEn,
  }) async {
    await ApiClient.instance.post(
      '/db/taxi/status',
      body: {
        'requestId': requestId,
        'statusKey': statusKey,
      },
    );
  }

  Future<String?> uploadMediaImage({
    required String imageBase64,
    String ownerType = 'user',
    String? ownerId,
    String role = 'gallery',
  }) async {
    final result = await ApiClient.instance.post(
      '/db/media/upload',
      body: {
        'imageBase64': imageBase64,
        'ownerType': ownerType,
        if (ownerId != null && ownerId.trim().isNotEmpty) 'ownerId': ownerId.trim(),
        'role': role,
      },
    );
    if (result is! Map) return null;
    final map = Map<String, dynamic>.from(result);
    final direct = map['url']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final urls = map['urls'];
    if (urls is Map) {
      final variants = Map<String, dynamic>.from(urls);
      for (final key in ['256', 'thumbnail', '512', 'original']) {
        final candidate = variants[key]?.toString().trim();
        if (candidate != null && candidate.isNotEmpty) return candidate;
      }
    }
    return null;
  }
}
