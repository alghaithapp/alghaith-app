import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/phone_utils.dart';
import '../../models/app_models.dart';
import '../../models/home_category_platform_override.dart';
import '../../services/image_storage_service.dart';
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
    final result = await ApiClient.instance.get('/db/offers-catalog');
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

  List<TaxiRequest> _mapTaxiRows(dynamic result) {
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => TaxiRequest.fromMap(
              Map<String, dynamic>.from(item['request_payload'] as Map),
            ))
        .toList();
  }

  Future<List<TaxiRequest>> loadCustomerTaxiRequests(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/customer-taxi-requests',
      queryParameters: {'phone': _phone(phone)},
    );
    return _mapTaxiRows(result);
  }

  Future<List<TaxiRequest>> loadTaxiPool(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/taxi-pool',
      queryParameters: {'phone': _phone(phone)},
    );
    return _mapTaxiRows(result);
  }

  Future<List<TaxiRequest>> loadDriverTaxiOrders(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/driver-taxi-orders',
      queryParameters: {'phone': _phone(phone)},
    );
    return _mapTaxiRows(result);
  }

  Future<void> saveTaxiRequest(String phone, TaxiRequest request) async {
    await ApiClient.instance.put('/db/taxi-request', body: {
      'phone': _phone(phone),
      'request': request.toMap(),
    });
  }

  Future<void> acceptTaxiRequest(
    String driverPhone,
    String requestId, {
    String? driverName,
    String? vehicleType,
  }) async {
    await ApiClient.instance.put('/db/taxi-request/accept', body: {
      'phone': _phone(driverPhone),
      'requestId': requestId,
      if (driverName != null && driverName.trim().isNotEmpty)
        'driverName': driverName.trim(),
      if (vehicleType != null && vehicleType.trim().isNotEmpty)
        'vehicleType': vehicleType.trim(),
    });
  }

  Future<void> updateTaxiRequestStatus(
    String actorPhone,
    String requestId, {
    required String statusKey,
    String? statusAr,
    String? statusEn,
  }) async {
    await ApiClient.instance.put('/db/taxi-request/status', body: {
      'phone': _phone(actorPhone),
      'requestId': requestId,
      'statusKey': statusKey,
      if (statusAr != null) 'statusAr': statusAr,
      if (statusEn != null) 'statusEn': statusEn,
    });
  }

  Future<void> rejectTaxiRequest(String driverPhone, String requestId) async {
    await ApiClient.instance.put('/db/taxi-request/reject', body: {
      'phone': _phone(driverPhone),
      'requestId': requestId,
    });
  }

  Future<Map<String, dynamic>> loadAdminReports(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/admin/reports',
      queryParameters: {'phone': _phone(phone)},
    );
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return const {};
  }

  Future<List<Map<String, dynamic>>> loadRealEstateListings({
    String? subCategoryId,
    String? listingMode,
  }) async {
    final result = await ApiClient.instance.get(
      '/db/real-estate-listings',
      queryParameters: {
        if (subCategoryId != null && subCategoryId.trim().isNotEmpty)
          'subCategoryId': subCategoryId.trim(),
        if (listingMode != null && listingMode.trim().isNotEmpty)
          'listingMode': listingMode.trim(),
      },
    );
    if (result is! List) return const [];
    return result
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>?> loadCustomerProfile(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/customer-profile',
      queryParameters: {'phone': _phone(phone)},
    );
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  Future<List<String>> loadCustomerAddresses(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/customer-addresses',
      queryParameters: {'phone': _phone(phone)},
    );
    if (result is! List) return const [];
    return result.map((item) => item['address_text'].toString()).toList();
  }

  Future<List<String>> loadCustomerFavoriteIds(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/customer-favorites',
      queryParameters: {'phone': _phone(phone)},
    );
    if (result is! List) return const [];
    return result.map((item) => item['product_id'].toString()).toList();
  }

  Future<List<ActiveOrder>> loadCustomerOrders(String phone) async {
    final result = await ApiClient.instance.get(
      '/db/customer-orders',
      queryParameters: {'phone': _phone(phone)},
    );
    if (result is! List) return const [];
    final orders = <ActiveOrder>[];
    for (final item in result) {
      if (item is! Map) continue;
      final payload = item['order_payload'];
      if (payload is! Map) continue;
      try {
        orders.add(
          ActiveOrder.fromMap(Map<String, dynamic>.from(payload)),
        );
      } catch (error) {
        debugPrint('loadCustomerOrders skipped bad row: $error');
      }
    }
    return orders;
  }

  Future<T?> _safeBundleLoad<T>(
    String label,
    Future<T> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (error) {
      debugPrint('loadAccountBundle/$label failed: $error');
      return null;
    }
  }

  Future<RemoteAccountBundle> loadAccountBundle(String phone) async {
    final normalized = _phone(phone);
    final results = await Future.wait([
      _safeBundleLoad('appUser', () => loadAppUser(normalized)),
      _safeBundleLoad('customerProfile', () => loadCustomerProfile(normalized)),
      _safeBundleLoad('merchantProfile', () => loadMerchantProfile(normalized)),
      _safeBundleLoad('userState', () => loadUserState(normalized)),
      _safeBundleLoad('addresses', () => loadCustomerAddresses(normalized)),
      _safeBundleLoad('favoriteIds', () => loadCustomerFavoriteIds(normalized)),
      _safeBundleLoad('orders', () => loadCustomerOrders(normalized)),
      _safeBundleLoad('products', () => loadMerchantProducts(normalized)),
    ]).timeout(AppConfig.restoreTimeout);

    return RemoteAccountBundle(
      appUser: results[0] as Map<String, dynamic>?,
      customerProfile: results[1] as Map<String, dynamic>?,
      merchantProfile: results[2] as Map<String, dynamic>?,
      userState: results[3] as Map<String, dynamic>?,
      addresses: (results[4] as List<String>?) ?? const [],
      favoriteIds: (results[5] as List<String>?) ?? const [],
      orders: (results[6] as List<ActiveOrder>?) ?? const [],
      products: (results[7] as List<Map<String, dynamic>>?) ?? const [],
    );
  }

  Future<void> saveAppUser(
    String phone, {
    String? fullName,
    String? role,
    String? accountType,
    String? avatarBase64,
  }) async {
    await ApiClient.instance.put('/db/app-user', body: {
      'phone': _phone(phone),
      if (fullName != null) 'full_name': fullName,
      if (role != null) 'role': role,
      if (accountType != null) 'account_type': accountType,
      ...ImageStorageService.customerAvatarFields(avatarBase64),
    });
  }

  Future<void> saveMerchantProfile(
    String phone,
    Map<String, dynamic> profile,
  ) async {
    await ApiClient.instance.put('/db/merchant-profile', body: {
      'phone': _phone(phone),
      ...profile,
    });
  }

  Future<void> saveMerchantProduct(
    String phone,
    Map<String, dynamic> product,
  ) async {
    await ApiClient.instance.put('/db/merchant-product', body: {
      'phone': _phone(phone),
      ...product,
    });
  }

  Future<void> saveUserState(String phone, Map<String, dynamic> state) async {
    await ApiClient.instance.put('/db/user-state', body: {
      'phone': _phone(phone),
      'state': state,
    });
  }

  Future<void> saveCustomerProfile(
    String phone,
    Map<String, dynamic> profile,
  ) async {
    await ApiClient.instance.put('/db/customer-profile', body: {
      'phone': _phone(phone),
      ...profile,
    });
  }

  Future<void> saveCustomerAddress(
    String phone,
    String address, {
    int sortOrder = 0,
  }) async {
    await ApiClient.instance.put('/db/customer-address', body: {
      'phone': _phone(phone),
      'address': address,
      'sort_order': sortOrder,
    });
  }

  Future<void> deleteCustomerAddress(String phone, String address) async {
    await ApiClient.instance.delete(
      '/db/customer-address',
      queryParameters: {'phone': _phone(phone), 'address': address},
    );
  }

  Future<void> saveCustomerFavorite(
    String phone,
    String productId, {
    required bool isFavorite,
  }) async {
    await ApiClient.instance.put('/db/customer-favorite', body: {
      'phone': _phone(phone),
      'productId': productId,
      'isFavorite': isFavorite,
    });
  }

  Future<void> saveCustomerOrder(String phone, ActiveOrder order) async {
    await ApiClient.instance.put('/db/customer-order', body: {
      'phone': _phone(phone),
      'order': order.toMap(),
    });
  }

  Future<void> deleteMerchantProduct(String productId, {String? phone}) async {
    await ApiClient.instance.delete(
      '/db/merchant-product',
      queryParameters: {
        'id': productId,
        if (phone != null && phone.trim().isNotEmpty) 'phone': _phone(phone),
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
    await ApiClient.instance.post('/db/merchant-review', body: {
      'merchantPhone': _phone(merchantPhone),
      'customerPhone': _phone(customerPhone),
      'customerName': customerName,
      'orderId': orderId,
      'stars': stars,
      'comment': comment,
    });
  }

  Future<List<Map<String, dynamic>>> loadAllMerchants() async {
    final result = await ApiClient.instance.get('/db/admin/merchants');
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

  Future<Map<String, HomeCategoryPlatformOverride>> loadHomeCategoriesConfig() async {
    final result = await ApiClient.instance.get('/app/home-categories');
    final overrides = <String, HomeCategoryPlatformOverride>{};
    if (result is Map) {
      final raw = result['overrides'];
      if (raw is Map) {
        raw.forEach((key, value) {
          final id = key?.toString().trim() ?? '';
          final parsed = HomeCategoryPlatformOverride.fromDynamic(value);
          if (id.isNotEmpty && parsed != null) {
            overrides[id] = parsed;
          }
        });
      }
    }
    return overrides;
  }

  Future<Map<String, HomeCategoryPlatformOverride>> saveHomeCategoriesConfig({
    required String phone,
    required Map<String, HomeCategoryPlatformOverride> overrides,
  }) async {
    final payload = <String, Map<String, bool>>{};
    overrides.forEach((id, value) {
      payload[id] = value.toJson();
    });
    final result = await ApiClient.instance.put(
      '/db/admin/home-categories',
      body: {
        'phone': _phone(phone),
        'overrides': payload,
      },
    );
    final saved = <String, HomeCategoryPlatformOverride>{};
    if (result is Map && result['overrides'] is Map) {
      (result['overrides'] as Map).forEach((key, value) {
        final id = key?.toString().trim() ?? '';
        final parsed = HomeCategoryPlatformOverride.fromDynamic(value);
        if (id.isNotEmpty && parsed != null) {
          saved[id] = parsed;
        }
      });
    }
    return saved;
  }

  Future<Map<String, dynamic>> toggleMerchantBazaarStatus({
    required String merchantPhone,
    required bool isBazaarMember,
  }) async {
    final result = await ApiClient.instance.put('/db/admin/merchant-bazaar', body: {
      'merchantPhone': _phone(merchantPhone),
      'isBazaarMember': isBazaarMember,
    });
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return const {};
  }

  Future<void> toggleCourierApprovalStatus({
    required String courierPhone,
    required bool isApproved,
  }) async {
    await ApiClient.instance.put('/db/admin/courier-approval', body: {
      'courierPhone': _phone(courierPhone),
      'isApproved': isApproved,
    });
  }

  Future<void> rejectCourierApplication({
    required String courierPhone,
    required String reasonKey,
    String? rejectionMessageAr,
  }) async {
    await ApiClient.instance.put('/db/admin/courier-rejection', body: {
      'courierPhone': _phone(courierPhone),
      'reasonKey': reasonKey,
      if (rejectionMessageAr != null && rejectionMessageAr.trim().isNotEmpty)
        'rejectionMessageAr': rejectionMessageAr.trim(),
    });
  }

  Future<void> toggleMerchantFreezeStatus({
    required String merchantPhone,
    required bool isFrozen,
  }) async {
    await ApiClient.instance.put('/db/admin/merchant-freeze', body: {
      'merchantPhone': _phone(merchantPhone),
      'isFrozen': isFrozen,
    });
  }

  Future<void> toggleMerchantApprovalStatus({
    required String merchantPhone,
    required bool isApproved,
  }) async {
    await ApiClient.instance.put('/db/admin/merchant-approval', body: {
      'merchantPhone': _phone(merchantPhone),
      'isApproved': isApproved,
    });
  }

  Future<void> rejectMerchantApplication({
    required String merchantPhone,
    required String reasonKey,
    String? rejectionMessageAr,
  }) async {
    await ApiClient.instance.put('/db/admin/merchant-rejection', body: {
      'merchantPhone': _phone(merchantPhone),
      'reasonKey': reasonKey,
      if (rejectionMessageAr != null && rejectionMessageAr.trim().isNotEmpty)
        'rejectionMessageAr': rejectionMessageAr.trim(),
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

  Future<void> deleteAccount(String phone) async {
    await ApiClient.instance.delete(
      '/db/app-user',
      queryParameters: {'phone': _phone(phone)},
    );
  }
}
