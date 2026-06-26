import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../services/supabase_service.dart';
import '../../../services/image_storage_service.dart';
import '../../../models/app_models.dart';
import '../../../models/app_notification.dart';
import '../../../models/merchant_models.dart';
import '../../../models/merchant_product_section.dart';
import '../../../utils/merchant_profile_fields.dart';
import '../../../utils/merchant_product_sections.dart';
import '../../../utils/merchant_service_labels.dart';
import '../../../core/notifications/notification_hub.dart';
import '../../../core/orders/order_adjustment.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/phone_utils.dart';

class MerchantService extends ChangeNotifier {
  // ── Merchant store state ───────────────────────────────────────
  Map<String, dynamic>? _merchantStore;
  List<ListItem> _items = [];

  // ── Offers & reviews ──────────────────────────────────────────
  List<MerchantOffer> _merchantOffers = [];
  List<MerchantReview> _merchantReviews = [];

  // ── Orders ─────────────────────────────────────────────────────
  List<ActiveOrder> _orders = [];
  List<ActiveOrder> _merchantIncomingOrders = [];

  // ── Cross-domain state (set by AppProvider) ────────────────────
  String? _authPhone;
  String? _customerPhone;
  String? _customerName;
  String? _userRole;
  String? _sessionToken;
  bool? _merchantProfileOnServer;

  late final NotificationHub _notificationHub =
      NotificationHub(_emitNotification);

  // ── Getters ─────────────────────────────────────────────────────
  Map<String, dynamic>? get merchantStore => _merchantStore;
  List<MerchantOffer> get merchantOffers =>
      List<MerchantOffer>.unmodifiable(_merchantOffers);
  List<MerchantReview> get merchantReviews =>
      List<MerchantReview>.unmodifiable(_merchantReviews);
  List<ActiveOrder> get merchantIncomingOrders =>
      List<ActiveOrder>.unmodifiable(_merchantIncomingOrders);
  List<ActiveOrder> get orders => _orders;

  String get merchantStoreName =>
      MerchantProfileFields.storeNameOrEmpty(_merchantStore);
  String get merchantCategoryId =>
      (_merchantStore?['category'] as String?)?.trim() ?? '';
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
    final explicit =
        (_merchantStore?['whatsapp'] as String?)?.trim() ?? '';
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

  String get merchantOpenTime =>
      MerchantProfileFields.timeFromMap(_merchantStore, isOpen: true);
  String get merchantCloseTime =>
      MerchantProfileFields.timeFromMap(_merchantStore, isOpen: false);

  bool get isMerchantStoreOpen =>
      MerchantProfileFields.boolValue(
          _merchantStore?['isOpen'] ?? _merchantStore?['is_open'],
          fallback: true);
  bool get hasCompletedMerchantProfile =>
      _merchantStore != null && merchantStoreName.isNotEmpty;
  bool get isMerchantApproved =>
      MerchantProfileFields.isApproved(_merchantStore);
  bool? get merchantProfileOnServer => _merchantProfileOnServer;
  bool get isMerchantProfileServerCheckPending =>
      _merchantProfileOnServer == null;
  bool get isMerchantProfileOnServer => _merchantProfileOnServer == true;
  bool get needsMerchantProfileResubmit =>
      hasCompletedMerchantProfile &&
      !isMerchantApproved &&
      _merchantProfileOnServer == false;
  bool get shouldShowMerchantPendingApproval =>
      hasCompletedMerchantProfile &&
      !isMerchantApproved &&
      _merchantProfileOnServer == true;
  bool get canUseMerchantAccount =>
      hasCompletedMerchantProfile && isMerchantApproved;
  bool get isBazaarApproved =>
      MerchantProfileFields.boolValue(
          _merchantStore?['isBazaarMember'] ?? _merchantStore?['is_bazaar_member'],
          fallback: false);
  bool get isMerchant => _userRole == 'merchant';

  String? get merchantProfileImageBase64 {
    final store = _merchantStore;
    if (store == null) return null;
    final value =
        store['profileImageBase64'] ?? store['profile_image_base64'];
    final text = value?.toString().trim();
    return text != null && text.isNotEmpty ? text : null;
  }

  List<String> get merchantWorkSampleImagesBase64 {
    final store = _merchantStore;
    if (store == null) return const [];
    final value = store['workSampleImagesBase64'] ??
        store['work_sample_images_base64'];
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
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

  bool requiresMerchantLocationForService(String serviceId) =>
      serviceId == 'restaurant' || serviceId == 'product';

  bool canPublishForService(String serviceId) {
    if (!isMerchantServiceEnabled(serviceId)) return false;
    return !requiresMerchantLocationForService(serviceId) ||
        (merchantLatitude != null && merchantLongitude != null);
  }

  void assertCanPublishForService(String serviceId) {
    if (!isMerchantServiceEnabled(serviceId)) {
      throw StateError('هذه الخدمة موقوفة حالياً. فعّلها من إعدادات المتجر أولاً.');
    }
    if (canPublishForService(serviceId)) return;
    throw StateError(
      'يرجى تحديد موقع المتجر على الخريطة قبل نشر المنتجات.',
    );
  }

  int get merchantDeliveryFee => merchantActiveServiceId == 'professionals'
      ? 0
      : merchantActiveServiceId == 'restaurant'
          ? 0
          : MerchantProfileFields.intValue(
              _merchantStore?['deliveryFee'] ?? _merchantStore?['delivery_fee']);

  String get merchantDeliveryAreas =>
      (_merchantStore?['deliveryAreas'] as String?)?.trim() ?? '';

  double get merchantRating {
    final storedRating =
        (_merchantStore?['rating'] as num?)?.toDouble();
    if (storedRating != null && storedRating > 0) return storedRating;
    return _averageMerchantRatingFromReviews();
  }

  List<MerchantProductSection> get merchantProductSections =>
      MerchantProductSections.parseFromStore(_merchantStore);

  String? merchantProductSectionName(String? sectionId) =>
      MerchantProductSections.nameForId(merchantProductSections, sectionId);

  String? get merchantProfileImageUrl =>
      _merchantStore?['profileImageUrl'] as String?;

  List<String> get merchantServiceIds {
    final ids = <String>{};
    final serviceIds = _merchantStore?['serviceIds'];
    if (serviceIds is List) {
      for (final item in serviceIds) {
        final value = item.toString().trim();
        if (value.isNotEmpty) ids.add(value);
      }
    }
    final serviceIdsSnake = _merchantStore?['service_ids'];
    if (serviceIdsSnake is List) {
      for (final item in serviceIdsSnake) {
        final value = item.toString().trim();
        if (value.isNotEmpty) ids.add(value);
      }
    }
    final categoryId = merchantCategoryId;
    if (categoryId.isNotEmpty) ids.add(categoryId);
    final primary =
        (_merchantStore?['primary_service_id'] as String?)?.trim() ?? '';
    if (primary.isNotEmpty) ids.add(primary);
    if (ids.isNotEmpty) return ids.toList();
    return const ['product'];
  }

  String get merchantActiveServiceId {
    final ids = merchantServiceIds;
    final activeCamel =
        (_merchantStore?['activeServiceId'] as String?)?.trim() ?? '';
    final activeSnake =
        (_merchantStore?['active_service_id'] as String?)?.trim() ?? '';
    final preferred =
        activeCamel.isNotEmpty ? activeCamel : activeSnake;
    if (preferred.isNotEmpty) {
      if (ids.contains(preferred)) return preferred;
      // احترم الخدمة المحفوظة حتى لو قائمة service_ids قديمة.
      return normalizeMerchantServiceId(preferred);
    }
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

  Map<String, bool> get merchantServiceEnabledMap =>
      MerchantProfileFields.serviceEnabledMapForIds(
        merchantServiceIds,
        _merchantStore,
      );

  bool isMerchantServiceEnabled(String serviceId) {
    final id = serviceId.trim();
    if (id.isEmpty) return true;
    return merchantServiceEnabledMap[id] ?? true;
  }

  void _writeServiceEnabledMap(Map<String, bool> map) {
    if (_merchantStore == null) return;
    final payload = MerchantProfileFields.serviceEnabledPayload(map);
    _merchantStore!['serviceEnabled'] = payload;
    _merchantStore!['service_enabled'] = payload;
  }

  MerchantServiceLabels get merchantActiveLabels =>
      merchantServiceLabels(merchantActiveServiceId);
  MerchantServiceLabels get merchantLabels => merchantActiveLabels;

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
      _merchantIncomingOrders
          .where((o) => o.statusKey == 'completed').length;
  int get merchantAcceptedOrdersCount => _merchantIncomingOrders
      .where((o) =>
          o.statusKey == 'accepted' ||
          o.statusKey == 'delivering' ||
          o.statusKey == 'completed')
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

  int get totalSales => _merchantIncomingOrders
      .where((o) =>
          o.statusKey == 'accepted' || o.statusKey == 'delivering')
      .fold(0, (sum, item) => sum + item.price);

  int get productCount => _items.length;

  // ── Cross-domain setters ──────────────────────────────────────
  void updateAuthPhone(String? phone) => _authPhone = phone;
  void updateCustomerPhone(String? phone) => _customerPhone = phone;
  void updateCustomerName(String name) => _customerName = name;
  void updateUserRole(String? role) => _userRole = role;
  void updateSessionToken(String? token) => _sessionToken = token;
  void updateOrders(List<ActiveOrder> orders) => _orders = orders;

  // ── Merchant store ─────────────────────────────────────────────
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
    final activeServiceId =
        (storeData['activeServiceId'] as String?)?.trim() ??
            (normalizedServiceIds.isNotEmpty
                ? normalizedServiceIds.first
                : '');
    final latitude = _toDoubleValue(storeData['latitude']) ??
        _toDoubleValue(storeData['lat']);
    final longitude = _toDoubleValue(storeData['longitude']) ??
        _toDoubleValue(storeData['lng']);
    final nextStore = {
      ...storeData,
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
              (storeData['logoImage'] as String?)?.trim() ?? '',
      'phone': (storeData['phone'] as String?)?.trim() ?? '',
      'whatsapp': (storeData['whatsapp'] as String?)?.trim() ?? '',
      'address': MerchantProfileFields.addressFromMap(storeData).isNotEmpty
          ? MerchantProfileFields.addressFromMap(storeData)
          : (storeData['address'] as String?)?.trim() ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'openTime': MerchantProfileFields.formatTimeDisplay(
              storeData['openTime'] ?? storeData['open_time']),
      'closeTime': MerchantProfileFields.formatTimeDisplay(
              storeData['closeTime'] ?? storeData['close_time']),
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
    };
    _merchantStore = {...nextStore};
    if (!wasApproved) {
      _merchantStore!['isApproved'] = false;
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
    try {
      await _persistMerchantStoreAndState();
    } catch (error) {
      _markMerchantProfileOnServer(false);
      rethrow;
    }
  }

  Future<void> updateMerchantStore(Map<String, dynamic> updates) async {
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
    await _persistMerchantStoreAndState();
  }

  Future<void> toggleMerchantOpenStatus() async {
    if (_merchantStore == null) return;
    _merchantStore!['isOpen'] = !isMerchantStoreOpen;
    _notificationHub.onMerchantStoreOpenChanged(isMerchantStoreOpen);
    notifyListeners();
    await _persistMerchantStoreAndState();
  }

  Future<void> setMerchantActiveService(String serviceId) async {
    if (_merchantStore == null) return;
    final normalized = normalizeMerchantServiceId(serviceId.trim());
    if (normalized.isEmpty) return;

    var ids = merchantServiceIds;
    if (!ids.contains(normalized)) {
      ids = <String>[...ids, normalized];
      _merchantStore!['serviceIds'] = ids;
      _merchantStore!['service_ids'] = ids;
    }

    _merchantStore!['activeServiceId'] = normalized;
    _merchantStore!['active_service_id'] = normalized;
    notifyListeners();
    await _persistMerchantStoreAndState();
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
    _merchantStore!['service_ids'] = updated;
    _merchantStore!['activeServiceId'] = normalized;
    _merchantStore!['active_service_id'] = normalized;
    final enabled = Map<String, bool>.from(merchantServiceEnabledMap);
    enabled[normalized] = true;
    _writeServiceEnabledMap(enabled);
    final existingCategory =
        (_merchantStore?['category'] as String?)?.trim() ?? '';
    _merchantStore!['category'] =
        existingCategory.isNotEmpty ? existingCategory : updated.first;
    notifyListeners();
    await _persistMerchantStoreAndState();
  }

  Future<void> setMerchantServiceEnabled(
    String serviceId,
    bool enabled,
  ) async {
    if (_merchantStore == null) return;
    final normalized = serviceId.trim();
    if (normalized.isEmpty) return;
    if (!merchantServiceIds.contains(normalized)) return;
    final updated = Map<String, bool>.from(merchantServiceEnabledMap);
    updated[normalized] = enabled;
    _writeServiceEnabledMap(updated);
    notifyListeners();
    await _persistMerchantStoreAndState();
  }

  Future<void> removeMerchantService(String serviceId) async {
    if (_merchantStore == null) return;
    final normalized = serviceId.trim();
    if (normalized.isEmpty) return;
    final current = merchantServiceIds;
    if (current.length <= 1) {
      throw StateError('SERVICE_REMOVE_LAST');
    }
    if (!current.contains(normalized)) return;

    final updated = current.where((id) => id != normalized).toList();
    _merchantStore!['serviceIds'] = updated;
    _merchantStore!['service_ids'] = updated;

    final enabled = Map<String, bool>.from(merchantServiceEnabledMap)
      ..remove(normalized);
    _writeServiceEnabledMap(enabled);

    final active = merchantActiveServiceId;
    if (active == normalized) {
      _merchantStore!['activeServiceId'] = updated.first;
      _merchantStore!['active_service_id'] = updated.first;
    }

    final category = (_merchantStore?['category'] as String?)?.trim() ?? '';
    if (category == normalized) {
      _merchantStore!['category'] = updated.first;
      _merchantStore!['primary_service_id'] = updated.first;
      _merchantStore!['primaryServiceId'] = updated.first;
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

  // ── Merchant items ─────────────────────────────────────────────
  Future<void> addProduct(ListItem item) async {
    assertCanPublishForService(item.category);
    if (item.category == 'bazar_ghaith' && !isBazaarApproved) {
      throw StateError(
        'يلزم حصولك على موافقة الإدارة قبل النشر داخل قسم بازار ومطاعم الغيث.',
      );
    }

    var finalItem = item;
    if (item.category == 'used') {
      finalItem = item.copyWith(isApproved: false);
    }

    _items.insert(0, finalItem);
    _items = _dedupeMerchantItemsById(_items);
    notifyListeners();
    final phone = _normalizeStoredPhone(_authPhone ?? merchantPhone);
    if (phone.isEmpty) return;
    try {
      try {
        await _ensureMerchantProfileSynced();
      } catch (error) {
        debugPrint(
            'MERCHANT_PROFILE_SYNC_SKIPPED_ON_ADD_PRODUCT: $error');
      }
      await SupabaseService.saveMerchantProduct(
        phone,
        _productRowFromListItem(finalItem),
      );
      await _persistLocalBackup();
    } catch (error) {
      debugPrint('SAVE_PRODUCT_REMOTE_ERROR: $error');
      unawaited(_persistMerchantItems());
    }
  }

  Future<void> updateProduct(ListItem updatedItem) async {
    final index = _items.indexWhere((item) => item.id == updatedItem.id);
    if (index == -1) return;
    final previous = _items[index];
    final wasAvailable = previous.isAvailable;
    _items[index] = updatedItem;
    if (wasAvailable && !updatedItem.isAvailable) {
      _notificationHub.onProductUnavailable(updatedItem.nameAr);
    }
    notifyListeners();

    try {
      final phone = _normalizeStoredPhone(_authPhone ?? merchantPhone);
      if (phone.isNotEmpty) {
        await SupabaseService.saveMerchantProduct(
          phone,
          _productRowFromListItem(updatedItem),
        );
      }
      await _persistLocalBackup();
    } catch (error) {
      debugPrint('UPDATE_PRODUCT_REMOTE_ERROR: $error');
      _items[index] = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    final phone = _merchantSessionPhone();
    if (phone != null && phone.isNotEmpty) {
      try {
        await SupabaseService.deleteMerchantProduct(id, phone: phone);
      } catch (error) {
        debugPrint('DELETE_PRODUCT_REMOTE_ERROR: $error');
        rethrow;
      }
    }
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
    await _persistMerchantCatalogState();
  }

  String? _merchantSessionPhone() =>
      _trimmedOrNull(_authPhone) ??
      _trimmedOrNull(_customerPhone) ??
      _trimmedOrNull(merchantPhone);

  Future<void> syncMerchantCatalogToCloud() async {
    final phone = _merchantSessionPhone();
    if (phone == null) {
      throw StateError(
          'لا يوجد رقم هاتف مرتبط بالجلسة. أعد تسجيل الدخول.');
    }
    if (_sessionToken == null || _sessionToken!.trim().isEmpty) {
      throw StateError(
          'جلسة الدخول منتهية أو غير متاحة. أعد تسجيل الدخول.');
    }
    try {
      await _syncMerchantDataBeforeLeavingMerchantMode();
      _notificationHub.onMerchantCatalogSynced();
    } catch (error) {
      _notificationHub.onMerchantCatalogSyncFailed(error.toString());
      rethrow;
    }
  }

  void loadInitialData(
    List<ListItem> initialItems, {
    bool persist = false,
  }) {
    _items = _dedupeMerchantItemsById(initialItems);
    _applyFavoriteSelections();
    if (persist) {
      unawaited(_persistMerchantItems());
    }
    notifyListeners();
  }

  List<ListItem> _dedupeMerchantItemsById(List<ListItem> items) {
    final seen = <String>{};
    final unique = <ListItem>[];
    for (final item in items) {
      final id = item.id.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      unique.add(item);
    }
    return unique;
  }

  // ── Merchant offers ──────────────────────────────────────────
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
    final index =
        _merchantOffers.indexWhere((offer) => offer.id == offerId);
    if (index == -1) return;
    _merchantOffers[index] = _merchantOffers[index]
        .copyWith(isActive: !_merchantOffers[index].isActive);
    await _persistMerchantOffers();
    notifyListeners();
  }

  Future<void> deleteMerchantOffer(String offerId) async {
    _merchantOffers.removeWhere((offer) => offer.id == offerId);
    final phone = _merchantSessionPhone();
    if (phone != null && phone.isNotEmpty) {
      await SupabaseService.deleteMerchantOffer(phone, offerId);
    }
    notifyListeners();
  }

  Future<void> replyMerchantReview(String reviewId, String reply) async {
    final index =
        _merchantReviews.indexWhere((review) => review.id == reviewId);
    if (index == -1) return;
    final phone = _merchantSessionPhone();
    if (phone != null && phone.isNotEmpty) {
      final row = await SupabaseService.replyMerchantReview(
        phone,
        reviewId,
        reply,
      );
      _merchantReviews[index] = MerchantReview.fromMap(row);
    } else {
      _merchantReviews[index] = _merchantReviews[index].copyWith(
        reply: reply.trim(),
      );
    }
    _notificationHub.onMerchantReviewReplied(reviewId);
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
      customerName: _customerName != null && _customerName!.isNotEmpty
          ? _customerName!
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

    _orders[index] = updated;
    await _persistCustomerOrder(updated);
    notifyListeners();
  }

  Future<bool> respondToOrderAdjustment(
    String orderId, {
    required bool approve,
  }) async {
    final index = _orders.indexWhere((item) => item.id == orderId);
    if (index == -1) return false;
    final order = _orders[index];
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
      _orders[index] = updated;
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
    _orders[index] = updated;
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

  // ── Incoming orders ──────────────────────────────────────────
  Future<void> refreshMerchantIncomingOrders() =>
      _refreshMerchantIncomingOrders();

  Future<void> _refreshMerchantIncomingOrders() async {
    if (!SupabaseService.isConfigured) return;
    try {
      final phone = _normalizeStoredPhone(
          _authPhone ?? _customerPhone ?? merchantPhone);
      if (phone.isEmpty) return;
      final orders =
          await SupabaseService.loadMerchantIncomingOrders(phone);
      _merchantIncomingOrders = orders;
      notifyListeners();
    } catch (error) {
      debugPrint('MERCHANT_INCOMING_ORDERS_ERROR: $error');
    }
  }

  void replaceIncomingOrder(ActiveOrder order) {
    final index =
        _merchantIncomingOrders.indexWhere((o) => o.id == order.id);
    if (index == -1) return;
    _merchantIncomingOrders[index] = order;
    notifyListeners();
  }

  // ── Persistence helpers ──────────────────────────────────────
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
      'neighborhood': item.neighborhood,
      'facade': item.facade,
      'bedrooms': item.bedrooms,
      'bathrooms': item.bathrooms,
      'area_square_meter': item.areaSquareMeter,
      'floor_count': item.floorCount,
      'listing_mode': item.listingMode,
      if (item.galleryImagesBase64.isNotEmpty)
        'gallery_images_base64': item.galleryImagesBase64,
      'prep_minutes': item.prepMinutes,
      'is_available': item.isAvailable,
      'is_approved': item.isApproved,
    };
  }

  Future<void> _persistMerchantStore() async {
    if (_merchantStore == null) return;

    if (merchantStoreName.isEmpty) {
      return;
    }

    try {
      final phone =
          _normalizeStoredPhone(_authPhone ?? merchantPhone);
      if (phone.isEmpty) return;

      final category =
          (_merchantStore?['category']?.toString() ?? '').trim();
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
        'address':
            MerchantProfileFields.addressFromMap(_merchantStore),
        'latitude':
            _merchantStore?['latitude'] ?? _merchantStore?['lat'],
        'longitude':
            _merchantStore?['longitude'] ?? _merchantStore?['lng'],
        if (openTime != null) 'open_time': openTime,
        if (closeTime != null) 'close_time': closeTime,
        'delivery_areas': _merchantStore?['deliveryAreas'] ??
            _merchantStore?['delivery_areas'],
        'delivery_fee': _merchantStore?['deliveryFee'] ??
            _merchantStore?['delivery_fee'],
        'is_open': _merchantStore?['isOpen'] ??
            _merchantStore?['is_open'] ?? true,
        'service_ids': serviceIds,
        'active_service_id': _merchantStore?['activeServiceId'],
        'service_enabled': MerchantProfileFields.serviceEnabledPayload(
          merchantServiceEnabledMap,
        ),
        'restaurant_category': _merchantStore?['restaurantCategory'],
        'professional_category_id':
            _merchantStore?['professionalCategoryId'],
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
          profileRef:
              _merchantStore?['profileImageBase64']?.toString() ??
                  _merchantStore?['profile_image_base64']?.toString(),
          coverRef: _merchantStore?['coverImageBase64']?.toString() ??
              _merchantStore?['cover_image_url']?.toString() ??
              _merchantStore?['coverImage']?.toString(),
          logoRef: _merchantStore?['logoImageBase64']?.toString() ??
              _merchantStore?['logo_image_url']?.toString() ??
              _merchantStore?['logoImage']?.toString(),
          workSamples: merchantWorkSampleImagesBase64,
        ),
        if (_merchantStore?['rejectionReasonKey'] != null)
          'rejection_reason_key':
              _merchantStore?['rejectionReasonKey']?.toString(),
        if (_merchantStore?['rejectionMessageAr'] != null)
          'rejection_message_ar':
              _merchantStore?['rejectionMessageAr']?.toString(),
        'is_approved':
            MerchantProfileFields.isApproved(_merchantStore),
        'approval_status':
            MerchantProfileFields.approvalStatus(_merchantStore),
      });
      await _confirmMerchantProfileOnServerAfterSave();
    } catch (error) {
      debugPrint('Merchant store sync failed: $error');
      _markMerchantProfileOnServer(false);
      rethrow;
    }
  }

  Future<void> Function()? requestSessionBackup;

  Future<void> _persistMerchantStoreAndState() async {
    await _persistMerchantStore();
    await requestSessionBackup?.call();
    await _persistLocalBackup();
  }

  Future<void> _persistMerchantItems() async {
    try {
      await _ensureMerchantProfileSynced();
    } catch (error) {
      debugPrint(
          'MERCHANT_PROFILE_SYNC_SKIPPED_WHILE_SAVING_ITEMS: $error');
    }
    final phone = _normalizeStoredPhone(_merchantSessionPhone() ?? '');
    if (phone.isNotEmpty) {
      for (final item in _items) {
        await SupabaseService.saveMerchantProduct(
            phone, _productRowFromListItem(item));
      }
    }
    await _persistMerchantCatalogState();
  }

  Future<void> _persistMerchantCatalogState() async {
    await requestSessionBackup?.call();
    await _persistLocalBackup();
  }

  Future<void> hydrateMerchantProfileFromCloud() async {
    if (hasCompletedMerchantProfile) return;
    final phone = _merchantSessionPhone();
    if (phone == null || phone.isEmpty) return;
    try {
      final row = await SupabaseService.loadMerchantProfile(phone);
      if (row == null || row.isEmpty) return;
      if (MerchantProfileFields.storeNameOrEmpty(row).isEmpty) return;
      applyMerchantStoreSnapshot(row);
      notifyListeners();
    } catch (error) {
      debugPrint('HYDRATE_MERCHANT_PROFILE: $error');
    }
  }

  Future<void> ensureMerchantProfileSynced() async {
    await hydrateMerchantProfileFromCloud();
    if (_merchantStore == null || merchantStoreName.isEmpty) return;
    await _persistMerchantStore();
    await _confirmMerchantProfileOnServerAfterSave();
  }

  void resetMerchantProfileServerStatus() {
    _merchantProfileOnServer = null;
    notifyListeners();
  }

  void _markMerchantProfileOnServer(bool onServer) {
    _merchantProfileOnServer = onServer;
    if (_merchantStore != null) {
      _merchantStore!['profileOnServer'] = onServer;
    }
    notifyListeners();
  }

  void _mergeMerchantApprovalFromServerRow(Map<String, dynamic> row) {
    if (_merchantStore == null) return;
    _merchantStore!['approvalStatus'] =
        MerchantProfileFields.approvalStatus(row);
    _merchantStore!['approval_status'] =
        MerchantProfileFields.approvalStatus(row);
    _merchantStore!['isApproved'] = MerchantProfileFields.isApproved(row);
    _merchantStore!['is_approved'] = MerchantProfileFields.isApproved(row);
    final rejectionKey = row['rejection_reason_key'] ?? row['rejectionReasonKey'];
    final rejectionMessage =
        row['rejection_message_ar'] ?? row['rejectionMessageAr'];
    if (rejectionKey != null) {
      _merchantStore!['rejectionReasonKey'] = rejectionKey.toString();
    }
    if (rejectionMessage != null) {
      _merchantStore!['rejectionMessageAr'] = rejectionMessage.toString();
    }
  }

  Future<bool> _confirmMerchantProfileOnServerAfterSave() async {
    final onServer = await refreshMerchantProfileServerStatus(
      mergeApprovalFields: false,
    );
    if (!onServer) {
      _markMerchantProfileOnServer(false);
    }
    return onServer;
  }

  Future<bool> refreshMerchantProfileServerStatus({
    bool mergeApprovalFields = true,
  }) async {
    final phone = _merchantSessionPhone();
    if (phone == null || phone.isEmpty) {
      _markMerchantProfileOnServer(false);
      return false;
    }
    try {
      final row = await SupabaseService.loadMerchantProfile(phone);
      final onServer = row != null &&
          MerchantProfileFields.storeNameOrEmpty(row).isNotEmpty;
      _markMerchantProfileOnServer(onServer);
      if (onServer && mergeApprovalFields && row != null) {
        _mergeMerchantApprovalFromServerRow(row);
        notifyListeners();
      }
      return onServer;
    } catch (error) {
      debugPrint('MERCHANT_SERVER_STATUS: $error');
      if (error is ApiException && error.statusCode == 401) {
        _markMerchantProfileOnServer(false);
        return false;
      }
      return _merchantProfileOnServer == true;
    }
  }

  Future<bool> resubmitMerchantProfileToServer() async {
    if (!hasCompletedMerchantProfile) {
      throw StateError('لا توجد بيانات متجر لإرسالها.');
    }
    final phone = _merchantSessionPhone();
    if (phone == null || phone.isEmpty) {
      throw StateError(
          'لا يوجد رقم هاتف مرتبط بالجلسة. أعد تسجيل الدخول.');
    }
    if (_sessionToken == null || _sessionToken!.trim().isEmpty) {
      throw StateError(
          'انتهت جلسة الدخول. أعد تسجيل الدخول برمز التحقق ثم حاول مجدداً.');
    }
    await _persistMerchantStoreAndState();
    final onServer = await refreshMerchantProfileServerStatus();
    if (!onServer) {
      throw StateError(
          'لم يُؤكَّد وصول الطلب للسيرفر. تحقق من الإنترنت وحاول مرة أخرى.');
    }
    return true;
  }

  Future<void> persistMerchantStoreAndStateForAuth() async {
    await _persistMerchantStoreAndState();
  }

  Future<void> syncMerchantDataBeforeLeavingMerchantModeForAuth() async {
    await _syncMerchantDataBeforeLeavingMerchantMode();
  }

  Future<void> persistMerchantItemsForAuth() async {
    await _persistMerchantItems();
  }

  Future<void> _ensureMerchantProfileSynced() async {
    await ensureMerchantProfileSynced();
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

  Future<void> _persistMerchantOffers() async {
    final phone = _merchantSessionPhone();
    if (phone == null) return;
    for (final offer in _merchantOffers) {
      await SupabaseService.saveMerchantOffer(phone, offer.toMap());
    }
  }

  void loadOffersFromLocalBackup(List<MerchantOffer> offers) {
    if (offers.isEmpty) return;
    _merchantOffers = List<MerchantOffer>.from(offers);
    notifyListeners();
  }

  Future<void> hydrateMerchantEngagementFromCloud() async {
    final phone = _merchantSessionPhone();
    if (phone == null || phone.isEmpty) return;
    try {
      final offers = await SupabaseService.loadMerchantOffers(phone);
      if (offers.isNotEmpty) {
        _merchantOffers = offers
            .map((row) => MerchantOffer.fromMap(row))
            .toList();
      }
      final reviews = await SupabaseService.loadMerchantReviews(phone);
      if (reviews.isNotEmpty) {
        _merchantReviews = reviews
            .map((row) => MerchantReview.fromMap(row))
            .toList();
      }
      notifyListeners();
    } catch (error) {
      debugPrint('HYDRATE_MERCHANT_ENGAGEMENT: $error');
    }
  }

  Future<void> _persistCustomerOrder(ActiveOrder order) async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null) return;
    await SupabaseService.saveCustomerOrder(phone, order);
  }

  // ── Snapshot apply ─────────────────────────────────────────────
  void applyMerchantStoreSnapshot(Map<String, dynamic> snapshot) {
    if (snapshot.isEmpty) return;
    _applyMerchantStoreSnapshot(snapshot);
  }

  Map<String, dynamic> _normalizeMerchantSnapshot(
    Map<String, dynamic> snapshot,
  ) {
    final copy = Map<String, dynamic>.from(snapshot);
    final looksLikeRemoteRow = copy.containsKey('store_name') ||
        copy.containsKey('service_ids') ||
        copy.containsKey('is_approved') ||
        copy.containsKey('approval_status');
    if (looksLikeRemoteRow) {
      return _mapMerchantProfileRow(copy);
    }
    final resolvedName = MerchantProfileFields.storeNameOrEmpty(copy);
    if (resolvedName.isNotEmpty &&
        (copy['name']?.toString().trim() ?? '').isEmpty) {
      copy['name'] = resolvedName;
    }
    return copy;
  }

  void _applyMerchantStoreSnapshot(Map<String, dynamic> snapshot) {
    if (snapshot.isEmpty) return;
    final previousStore = _merchantStore == null
        ? null
        : Map<String, dynamic>.from(_merchantStore!);
    final wasApproved =
        MerchantProfileFields.isApproved(previousStore);
    final wasRejected =
        MerchantProfileFields.isRejected(previousStore);
    final previousRejectionMessage =
        MerchantProfileFields.rejectionMessage(previousStore);

    _merchantStore = _normalizeMerchantSnapshot(snapshot);
    final looksLikeRemoteRow = snapshot.containsKey('store_name') ||
        snapshot.containsKey('service_ids') ||
        snapshot.containsKey('is_approved') ||
        snapshot.containsKey('approval_status');
    if (looksLikeRemoteRow &&
        MerchantProfileFields.storeNameOrEmpty(snapshot).isNotEmpty) {
      _markMerchantProfileOnServer(true);
    }
    _notifyMerchantApprovalTransition(
      wasApproved: wasApproved,
      wasRejected: wasRejected,
      previousRejectionMessage: previousRejectionMessage,
    );
    unawaited(_restoreMerchantItems());
  }

  Future<void> _restoreMerchantItems() async {
    final phone = _merchantSessionPhone();
    if (phone == null || phone.isEmpty) return;
    try {
      final rows = await SupabaseService.loadMerchantProducts(phone);
      if (rows.isEmpty) return;
      _items = _dedupeMerchantItemsById(
        rows.map((row) => ListItem.fromMap(row)).toList(),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('RESTORE_MERCHANT_ITEMS_ERROR: $e');
    }
  }

  Map<String, dynamic> mapMerchantProfileRow(
      Map<String, dynamic> row) {
    return _mapMerchantProfileRow(row);
  }

  Map<String, dynamic> _mapMerchantProfileRow(
      Map<String, dynamic> row) {
    return {
      ...row,
      'name': row['store_name']?.toString() ?? '',
      'description': row['description']?.toString() ?? '',
      'category': _resolveMerchantPrimaryCategoryFromRow(row),
      'phone': row['phone']?.toString() ?? '',
      'whatsapp': row['whatsapp']?.toString() ?? '',
      'address': row['address']?.toString() ?? '',
      'latitude':
          _toDoubleValue(row['latitude']) ?? _toDoubleValue(row['lat']),
      'longitude':
          _toDoubleValue(row['longitude']) ?? _toDoubleValue(row['lng']),
      'openTime':
          MerchantProfileFields.formatTimeDisplay(row['open_time']),
      'closeTime':
          MerchantProfileFields.formatTimeDisplay(row['close_time']),
      'open_time':
          MerchantProfileFields.formatTimeDisplay(row['open_time']),
      'close_time':
          MerchantProfileFields.formatTimeDisplay(row['close_time']),
      'deliveryFee': row['delivery_fee'] is num
          ? (row['delivery_fee'] as num).toInt()
          : 0,
      'deliveryAreas': row['delivery_areas']?.toString() ?? '',
      'isOpen': MerchantProfileFields.boolValue(
          row['is_open'], fallback: true),
      'isFrozen': MerchantProfileFields.boolValue(
          row['is_frozen'], fallback: false),
      'isBazaarMember': MerchantProfileFields.boolValue(
          row['is_bazaar_member'], fallback: false),
      'isApproved': (row['is_approved'] ?? row['isApproved']) == null
          ? null
          : MerchantProfileFields.boolValue(
              row['is_approved'] ?? row['isApproved'],
              fallback: false,
            ),
      'approvalStatus': row['approval_status']?.toString() ??
          row['approvalStatus']?.toString(),
      'rejectionReasonKey': row['rejection_reason_key']?.toString() ??
          row['rejectionReasonKey']?.toString(),
      'rejectionMessageAr': row['rejection_message_ar']?.toString() ??
          row['rejectionMessageAr']?.toString(),
      'serviceIds': _decodeStringList(row['service_ids']),
      'activeServiceId': row['active_service_id']?.toString(),
      'serviceEnabled': MerchantProfileFields.serviceEnabledPayload(
        MerchantProfileFields.serviceEnabledMapForIds(
          _decodeStringList(row['service_ids']),
          row,
        ),
      ),
      'service_enabled': row['service_enabled'] ?? row['serviceEnabled'],
      'restaurantCategory': row['restaurant_category']?.toString(),
      'professionalCategoryId':
          row['professional_category_id']?.toString(),
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
      'product_sections':
          row['product_sections'] ?? row['productSections'],
    };
  }

  String _resolveMerchantPrimaryCategoryFromRow(
      Map<String, dynamic> row) {
    final primary =
        row['primary_service_id']?.toString().trim() ?? '';
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

  void _notifyMerchantApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  }) {
    if (!hasCompletedMerchantProfile) return;

    final nowApproved = isMerchantApproved;
    final nowRejected =
        MerchantProfileFields.isRejected(_merchantStore);
    final rejectionMessage =
        MerchantProfileFields.rejectionMessage(_merchantStore);

    if (nowApproved && !wasApproved) {
      _notificationHub.onMerchantProfileActivated();
      return;
    }

    if (nowRejected &&
        (!wasRejected ||
            rejectionMessage != previousRejectionMessage)) {
      _notificationHub.onMerchantRejected(rejectionMessage);
    }
  }

  void _applyFavoriteSelections() {}
  Future<void> _persistLocalBackup() async {}

  // ── Notification helpers ──────────────────────────────────────
  String _emitNotification({
    required String title,
    required String body,
    required String audience,
    String? orderNumber,
    NotificationCategory category = NotificationCategory.system,
    NotificationPriority priority = NotificationPriority.normal,
    String? eventKey,
  }) {
    return '';
  }

  // ── Utility methods ─────────────────────────────────────────────
  bool _isMerchantRejectedOrder(ActiveOrder order) {
    if (order.statusKey != 'cancelled') return false;
    final noteAr = order.noteAr.trim();
    final noteEn = order.noteEn.trim();
    return noteAr.startsWith('سبب الرفض:') ||
        noteEn.startsWith('Rejected reason:');
  }

  double? _orderResponseMinutes(ActiveOrder order) {
    final isMerchantDecision = order.statusKey == 'accepted' ||
        order.statusKey == 'delivering' ||
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

  double _averageMerchantRatingFromReviews() {
    if (_merchantReviews.isEmpty) return 0.0;
    final validReviews =
        _merchantReviews.where((review) => review.stars > 0).toList();
    if (validReviews.isEmpty) return 0.0;
    final total =
        validReviews.fold<int>(0, (sum, review) => sum + review.stars);
    return total / validReviews.length;
  }

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _normalizeStoredPhone(String phone) =>
      PhoneUtils.normalize(phone);

  double? _toDoubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
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
}
