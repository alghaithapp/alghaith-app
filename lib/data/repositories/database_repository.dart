import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/phone_utils.dart';
import '../../models/app_models.dart';
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
    return result
        .map((item) => ActiveOrder.fromMap(
              Map<String, dynamic>.from(item['order_payload'] as Map),
            ))
        .toList();
  }

  Future<RemoteAccountBundle> loadAccountBundle(String phone) async {
    final normalized = _phone(phone);
    final results = await Future.wait([
      loadAppUser(normalized),
      loadCustomerProfile(normalized),
      loadMerchantProfile(normalized),
      loadUserState(normalized),
      loadCustomerAddresses(normalized),
      loadCustomerFavoriteIds(normalized),
      loadCustomerOrders(normalized),
      loadMerchantProducts(normalized),
    ]).timeout(AppConfig.restoreTimeout);

    return RemoteAccountBundle(
      appUser: results[0] as Map<String, dynamic>?,
      customerProfile: results[1] as Map<String, dynamic>?,
      merchantProfile: results[2] as Map<String, dynamic>?,
      userState: results[3] as Map<String, dynamic>?,
      addresses: results[4] as List<String>,
      favoriteIds: results[5] as List<String>,
      orders: results[6] as List<ActiveOrder>,
      products: results[7] as List<Map<String, dynamic>>,
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

  Future<void> toggleMerchantFreezeStatus({
    required String merchantPhone,
    required bool isFrozen,
  }) async {
    await ApiClient.instance.put('/db/admin/merchant-freeze', body: {
      'merchantPhone': _phone(merchantPhone),
      'isFrozen': isFrozen,
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

  Future<void> deleteAccount(String phone) async {
    await ApiClient.instance.delete(
      '/db/app-user',
      queryParameters: {'phone': _phone(phone)},
    );
  }
}
