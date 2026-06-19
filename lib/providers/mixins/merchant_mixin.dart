import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/supabase_service.dart';
import '../../services/image_storage_service.dart';
import '../../models/app_models.dart';
import '../../utils/merchant_profile_fields.dart';
import '../../utils/merchant_product_sections.dart';
import '../../models/merchant_product_section.dart';
import '../../core/notifications/notification_hub.dart';
import 'core_mixin.dart';
import 'persistence_mixin.dart';
import 'auth_mixin.dart';
import 'customer_mixin.dart';

mixin MerchantMixin on AppCoreMixin, AuthMixin, CustomerMixin, PersistenceMixin {
  // Merchant store ───────────────────────────────────────────────
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
              (storeData['logoImage'] as String?)?.trim() ?? '',
      'phone': (storeData['phone'] as String?)?.trim() ?? '',
      'whatsapp': (storeData['whatsapp'] as String?)?.trim() ?? '',
      'address': MerchantProfileFields.addressFromMap(storeData).isNotEmpty
          ? MerchantProfileFields.addressFromMap(storeData)
          : (storeData['address'] as String?)?.trim() ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'openTime': MerchantProfileFields.formatTimeDisplay(
              storeData['openTime'] ?? storeData['open_time']) ?? '',
      'closeTime': MerchantProfileFields.formatTimeDisplay(
              storeData['closeTime'] ?? storeData['close_time']) ?? '',
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
    await _persistMerchantStoreAndState();
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
    if (!merchantServiceIds.contains(serviceId)) return;
    _merchantStore!['activeServiceId'] = serviceId;
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
    _merchantStore!['activeServiceId'] = normalized;
    final existingCategory =
        (_merchantStore?['category'] as String?)?.trim() ?? '';
    _merchantStore!['category'] =
        existingCategory.isNotEmpty ? existingCategory : updated.first;
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

  // Merchant items ───────────────────────────────────────────────
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

  // Merchant products ────────────────────────────────────────────
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
      unawaited(_persistMerchantItems());
    }
  }

  Future<void> updateProduct(ListItem updatedItem) async {
    final index = _items.indexWhere((item) => item.id == updatedItem.id);
    if (index == -1) return;
    final wasAvailable = _items[index].isAvailable;
    _items[index] = updatedItem;
    if (wasAvailable && !updatedItem.isAvailable) {
      _notificationHub.onProductUnavailable(updatedItem.nameAr);
    }
    await _persistMerchantItems();
    await _persistLocalBackup();
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    // حذف من قاعدة البيانات أولاً — بشكل متزامن مع معالجة الأخطاء
    if (_authPhone != null && _authPhone!.isNotEmpty) {
      try {
        await SupabaseService.deleteMerchantProduct(id, phone: _authPhone);
      } catch (error) {
        debugPrint('DELETE_PRODUCT_REMOTE_ERROR: $error');
        // لا نمسح المنتج محلياً إذا فشل الحذف عن بعد
        rethrow;
      }
    }
    _items.removeWhere((item) => item.id == id);
    await _persistMerchantItems();
    await _persistLocalBackup();
    notifyListeners();
  }

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

  // Merchant persistence helpers ─────────────────────────────────
  Future<void> _persistMerchantStore() async {
    if (_merchantStore == null || _isRestoring || _isLoggingIn) return;

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
        if (_merchantStore?['rejectionReasonKey'] != null)
          'rejection_reason_key':
              _merchantStore?['rejectionReasonKey']?.toString(),
        if (_merchantStore?['rejectionMessageAr'] != null)
          'rejection_message_ar':
              _merchantStore?['rejectionMessageAr']?.toString(),
        'is_approved': MerchantProfileFields.isApproved(_merchantStore),
        'approval_status': MerchantProfileFields.approvalStatus(_merchantStore),
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

  Future<void> _persistMerchantOffers() async {
    if (_authPhone == null || _authPhone!.isEmpty) return;
    await SupabaseService.saveUserState(_authPhone!, _buildRemoteState());
  }

  Future<void> _persistMerchantReviews() async {
    if (_authPhone == null || _authPhone!.isEmpty) return;
    await SupabaseService.saveUserState(_authPhone!, _buildRemoteState());
  }

  // Merchant offers ──────────────────────────────────────────────
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

  // Merchant store apply methods ─────────────────────────────────
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
      'isFrozen':
          MerchantProfileFields.boolValue(row['is_frozen'], fallback: false),
      'isBazaarMember': MerchantProfileFields.boolValue(row['is_bazaar_member'],
          fallback: false),
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

  void loadInitialData(List<ListItem> initialItems) {
    _items = initialItems;
    _applyFavoriteSelections();
    unawaited(_persistMerchantItems());
    notifyListeners();
  }

  /// واجهة عامة لـ _refreshMerchantIncomingOrders (معرّفة في AuthMixin).
  Future<void> refreshMerchantIncomingOrders() =>
      _refreshMerchantIncomingOrders();

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
}
