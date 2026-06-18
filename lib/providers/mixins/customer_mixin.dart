import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/catalog/marketplace_catalog.dart';
import '../../core/catalog/marketplace_stats.dart';
import '../../core/storage/catalog_cache.dart';
import '../../services/supabase_service.dart';
import '../../services/image_storage_service.dart';
import '../../models/app_models.dart';
import '../../models/app_notification.dart';
import '../../utils/merchant_profile_fields.dart';
import 'core_mixin.dart';
import 'persistence_mixin.dart';

mixin CustomerMixin on AppCoreMixin, PersistenceMixin {
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

  Future<void> refreshCustomerCatalog({bool force = false}) async {
    if (!SupabaseService.isConfigured) return;

    if (!force &&
        _lastCatalogFetch != null &&
        DateTime.now().difference(_lastCatalogFetch!) <
            const Duration(minutes: 5)) {
      return;
    }

    try {
      final rows = await SupabaseService.loadCatalog();
      if (rows.isNotEmpty) {
        final newItems = rows
            .map(_listItemFromCatalogRow)
            .where((item) =>
                item.category != 'used' ||
                item.isApproved)
            .toList();

        _catalogItems = newItems;
        _lastCatalogFetch = DateTime.now();
        unawaited(CatalogCache.writeCatalog(rows));
      } else {
        _catalogItems = _buildLocalCatalogFallback();
      }
      _applyFavoriteSelections();
      notifyListeners();
    } catch (error) {
      debugPrint('CATALOG_LOAD_ERROR: $error');
      if (_catalogItems.isEmpty) {
        _catalogItems = _buildLocalCatalogFallback();
        _applyFavoriteSelections();
        notifyListeners();
      }
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

  void _applyFavoriteSelections() {
    final target = isCustomer ? _catalogItems : _items;
    if (target.isEmpty) return;
    for (final item in target) {
      item.isFavorite = _favoriteItemIds.contains(item.id);
    }
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

  ListItem listItemFromStoreProduct(
    Map<String, dynamic> product,
    Map<String, dynamic> profile,
  ) {
    final visiblePhone = MerchantProfileFields.customerVisiblePhone(profile);
    final visibleWhatsApp =
        MerchantProfileFields.customerVisibleWhatsApp(profile);
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
    final primaryService = profile['primary_service_id']?.toString() ?? '';
    final serviceIds = profile['service_ids'];
    bool isBazar = primaryService == 'bazar_ghaith';
    if (!isBazar && serviceIds is List) {
      isBazar = serviceIds.map((e) => e.toString()).contains('bazar_ghaith');
    }
    return item.copyWith(
      category: isBazar ? 'bazar_ghaith' : item.category,
      isFavorite: _favoriteItemIds.contains(item.id),
    );
  }

  ListItem _listItemFromCatalogRow(Map<String, dynamic> row) {
    return _listItemFromProductRow(row).copyWith(
      merchantPhone:
          row['merchant_phone']?.toString() ?? row['phone']?.toString(),
      merchantWhatsApp: row['merchant_customer_whatsapp']?.toString() ??
          row['merchant_whatsapp']?.toString(),
      merchantShowPhoneToCustomers:
          row['merchant_show_phone_to_customers'] is bool
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
      originalCategory: row['category']?.toString() ?? 'restaurant',
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

  Future<void> _persistCustomerOrder(ActiveOrder order) async {
    final phone = _trimmedOrNull(_authPhone);
    if (phone == null) return;
    await SupabaseService.saveCustomerOrder(phone, order);
  }
}
