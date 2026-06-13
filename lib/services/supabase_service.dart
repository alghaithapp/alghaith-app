import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../data/repositories/database_repository.dart';
import '../models/app_models.dart';
import '../models/home_category_platform_override.dart';

/// واجهة توافقية — كل عمليات قاعدة البيانات تمر عبر Railway backend.
class SupabaseService {
  const SupabaseService._();

  static final _db = DatabaseRepository.instance;

  static bool get isConfigured => AppConfig.isBackendConfigured;

  static Future<void> initialize() async {
    AppConfig.validate(throwOnError: kReleaseMode);
    debugPrint(
      'SupabaseService: backend=${AppConfig.normalizedDatabaseUrl}',
    );
  }

  static void setSessionToken(String? token) {
    ApiClient.instance.setSessionToken(token);
  }

  static Future<Map<String, dynamic>?> loadAppUser(String phone) =>
      _db.loadAppUser(phone);

  static Future<Map<String, dynamic>?> loadMerchantProfile(String phone) =>
      _db.loadMerchantProfile(phone);

  static Future<List<Map<String, dynamic>>> loadMerchantProducts(
          String phone) =>
      _db.loadMerchantProducts(phone);

  static Future<Map<String, dynamic>?> loadUserState(String phone) =>
      _db.loadUserState(phone);

  static Future<List<Map<String, dynamic>>> loadProfessionalProfiles({
    String? professionId,
  }) =>
      _db.loadProfessionalProfiles(professionId: professionId);

  static Future<List<Map<String, dynamic>>> loadShoppingStores({
    String? subCategoryId,
  }) =>
      _db.loadShoppingStores(subCategoryId: subCategoryId);

  static Future<List<Map<String, dynamic>>> loadRestaurantStores({
    String? subCategoryId,
  }) =>
      _db.loadRestaurantStores(subCategoryId: subCategoryId);

  static Future<List<Map<String, dynamic>>> loadServiceStores({
    required String serviceId,
    String? productCategory,
    String? subCategoryId,
    String? marketplaceCategory,
  }) =>
      _db.loadServiceStores(
        serviceId: serviceId,
        productCategory: productCategory,
        subCategoryId: subCategoryId,
        marketplaceCategory: marketplaceCategory,
      );

  static Future<List<Map<String, dynamic>>> loadOffersCatalog() =>
      _db.loadOffersCatalog();

  static Future<Map<String, dynamic>> loadMarketplaceStats() =>
      _db.loadMarketplaceStats();

  static Future<Map<String, dynamic>> validatePromoCode({
    required String code,
    required int subtotalIqd,
  }) =>
      _db.validatePromoCode(code: code, subtotalIqd: subtotalIqd);

  static Future<List<Map<String, dynamic>>> loadCatalog({
    String? category,
    String? subCategoryId,
  }) =>
      _db.loadCatalog(category: category, subCategoryId: subCategoryId);

  static Future<List<ActiveOrder>> loadMerchantIncomingOrders(String phone) =>
      _db.loadMerchantIncomingOrders(phone);

  static Future<void> updateIncomingOrderStatus(
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
  }) =>
      _db.updateIncomingOrderStatus(
        merchantPhone,
        orderId,
        statusKey: statusKey,
        statusAr: statusAr,
        statusEn: statusEn,
        noteAr: noteAr,
        noteEn: noteEn,
        deliveryStatusKey: deliveryStatusKey,
        deliveryStatusAr: deliveryStatusAr,
        deliveryStatusEn: deliveryStatusEn,
        lineItems: lineItems,
        price: price,
        itemsCount: itemsCount,
        itemsNameAr: itemsNameAr,
        itemsNameEn: itemsNameEn,
        originalPrice: originalPrice,
        itemsSubtotalIqd: itemsSubtotalIqd,
        deliveryFeeIqd: deliveryFeeIqd,
        promoDiscountIqd: promoDiscountIqd,
        merchantDecisionAt: merchantDecisionAt,
        isPriceLocked: isPriceLocked,
      );

  static Future<List<ActiveOrder>> loadDeliveryPool(String phone) =>
      _db.loadDeliveryPool(phone);

  static Future<List<ActiveOrder>> loadCourierOrders(String phone) =>
      _db.loadCourierOrders(phone);

  static Future<void> acceptDeliveryOrder(
    String courierPhone,
    String orderId, {
    String? courierName,
  }) =>
      _db.acceptDeliveryOrder(
        courierPhone,
        orderId,
        courierName: courierName,
      );

  static Future<void> updateDeliveryOrderStatus(
    String courierPhone,
    String orderId, {
    required String deliveryStatusKey,
    String? deliveryStatusAr,
    String? deliveryStatusEn,
  }) =>
      _db.updateDeliveryOrderStatus(
        courierPhone,
        orderId,
        deliveryStatusKey: deliveryStatusKey,
        deliveryStatusAr: deliveryStatusAr,
        deliveryStatusEn: deliveryStatusEn,
      );

  static Future<void> rejectDeliveryOrder(
    String courierPhone,
    String orderId,
  ) =>
      _db.rejectDeliveryOrder(courierPhone, orderId);

  static Future<Map<String, dynamic>> loadAdminReports(String phone) =>
      _db.loadAdminReports(phone);

  static Future<Map<String, HomeCategoryPlatformOverride>> loadHomeCategoriesConfig() =>
      _db.loadHomeCategoriesConfig();

  static Future<Map<String, HomeCategoryPlatformOverride>> saveHomeCategoriesConfig({
    required String phone,
    required Map<String, HomeCategoryPlatformOverride> overrides,
  }) =>
      _db.saveHomeCategoriesConfig(phone: phone, overrides: overrides);

  static Future<List<Map<String, dynamic>>> loadRealEstateListings({
    String? subCategoryId,
    String? listingMode,
  }) =>
      _db.loadRealEstateListings(
        subCategoryId: subCategoryId,
        listingMode: listingMode,
      );

  static Future<Map<String, dynamic>?> loadCustomerProfile(String phone) =>
      _db.loadCustomerProfile(phone);

  static Future<List<String>> loadCustomerAddresses(String phone) =>
      _db.loadCustomerAddresses(phone);

  static Future<List<String>> loadCustomerFavoriteIds(String phone) =>
      _db.loadCustomerFavoriteIds(phone);

  static Future<List<ActiveOrder>> loadCustomerOrders(String phone) =>
      _db.loadCustomerOrders(phone);

  static Future<void> saveAppUser(
    String phone, {
    String? fullName,
    String? role,
    String? accountType,
    String? avatarBase64,
  }) =>
      _db.saveAppUser(
        phone,
        fullName: fullName,
        role: role,
        accountType: accountType,
        avatarBase64: avatarBase64,
      );

  static Future<void> saveMerchantProfile(
    String phone,
    Map<String, dynamic> profile,
  ) =>
      _db.saveMerchantProfile(phone, profile);

  static Future<void> saveMerchantProduct(
    String phone,
    Map<String, dynamic> product,
  ) =>
      _db.saveMerchantProduct(phone, product);

  static Future<void> saveUserState(String phone, Map<String, dynamic> state) =>
      _db.saveUserState(phone, state);

  static Future<void> saveCustomerProfile(
    String phone,
    Map<String, dynamic> profile,
  ) =>
      _db.saveCustomerProfile(phone, profile);

  static Future<void> saveCustomerAddress(
    String phone,
    String address, {
    int sortOrder = 0,
  }) =>
      _db.saveCustomerAddress(phone, address, sortOrder: sortOrder);

  static Future<void> deleteCustomerAddress(String phone, String address) =>
      _db.deleteCustomerAddress(phone, address);

  static Future<void> saveCustomerFavorite(
    String phone,
    String productId, {
    required bool isFavorite,
  }) =>
      _db.saveCustomerFavorite(phone, productId, isFavorite: isFavorite);

  static Future<void> saveCustomerOrder(String phone, ActiveOrder order) =>
      _db.saveCustomerOrder(phone, order);

  static Future<void> deleteMerchantProduct(String productId,
          {String? phone}) =>
      _db.deleteMerchantProduct(productId, phone: phone);

  static Future<void> submitMerchantReview({
    required String merchantPhone,
    required String customerPhone,
    required String customerName,
    required String orderId,
    required int stars,
    String? comment,
  }) =>
      _db.submitMerchantReview(
        merchantPhone: merchantPhone,
        customerPhone: customerPhone,
        customerName: customerName,
        orderId: orderId,
        stars: stars,
        comment: comment,
      );

  static Future<List<Map<String, dynamic>>> loadAllMerchants() =>
      _db.loadAllMerchants();

  static Future<List<Map<String, dynamic>>> loadAllCouriers() =>
      _db.loadAllCouriers();

  static Future<Map<String, dynamic>> toggleMerchantBazaarStatus({
    required String merchantPhone,
    required bool isBazaarMember,
  }) =>
      _db.toggleMerchantBazaarStatus(
        merchantPhone: merchantPhone,
        isBazaarMember: isBazaarMember,
      );

  static Future<void> toggleCourierApprovalStatus({
    required String courierPhone,
    required bool isApproved,
  }) =>
      _db.toggleCourierApprovalStatus(
        courierPhone: courierPhone,
        isApproved: isApproved,
      );

  static Future<void> rejectCourierApplication({
    required String courierPhone,
    required String reasonKey,
    String? rejectionMessageAr,
  }) =>
      _db.rejectCourierApplication(
        courierPhone: courierPhone,
        reasonKey: reasonKey,
        rejectionMessageAr: rejectionMessageAr,
      );

  static Future<void> toggleMerchantFreezeStatus({
    required String merchantPhone,
    required bool isFrozen,
  }) =>
      _db.toggleMerchantFreezeStatus(
        merchantPhone: merchantPhone,
        isFrozen: isFrozen,
      );

  static Future<void> toggleMerchantApprovalStatus({
    required String merchantPhone,
    required bool isApproved,
  }) =>
      _db.toggleMerchantApprovalStatus(
        merchantPhone: merchantPhone,
        isApproved: isApproved,
      );

  static Future<void> rejectMerchantApplication({
    required String merchantPhone,
    required String reasonKey,
    String? rejectionMessageAr,
  }) =>
      _db.rejectMerchantApplication(
        merchantPhone: merchantPhone,
        reasonKey: reasonKey,
        rejectionMessageAr: rejectionMessageAr,
      );

  static Future<void> saveDeviceToken({
    required String phone,
    required String token,
    required String platform,
  }) =>
      _db.saveDeviceToken(
        phone: phone,
        token: token,
        platform: platform,
      );

  static Future<void> deleteDeviceToken({
    required String phone,
    required String token,
  }) =>
      _db.deleteDeviceToken(phone: phone, token: token);

  static Future<void> markPushInboxOpened({required String phone}) =>
      _db.markPushInboxOpened(phone: phone);

  static Future<void> deleteAccount(String phone) => _db.deleteAccount(phone);
}
