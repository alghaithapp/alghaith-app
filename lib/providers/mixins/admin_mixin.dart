import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/utils/phone_utils.dart';
import '../../services/supabase_service.dart';
import '../../core/storage/home_categories_cache.dart';
import '../../models/home_category_platform_override.dart';
import 'core_mixin.dart';
import 'persistence_mixin.dart';
import 'customer_mixin.dart';

mixin AdminMixin on AppCoreMixin, PersistenceMixin, CustomerMixin {
  // Admin state fields
  List<Map<String, dynamic>> _allMerchants = [];
  List<Map<String, dynamic>> _allCouriers = [];

  List<Map<String, dynamic>> get allMerchants =>
      List<Map<String, dynamic>>.unmodifiable(_allMerchants);
  List<Map<String, dynamic>> get allCouriers =>
      List<Map<String, dynamic>>.unmodifiable(_allCouriers);
  List<Map<String, dynamic>> _allDrivers = [];

  List<Map<String, dynamic>> get allDrivers =>
      List<Map<String, dynamic>>.unmodifiable(_allDrivers);
  Map<String, dynamic>? _adminReports;
  String? _adminReportsError;
  Map<String, dynamic>? get adminReports => _adminReports;
  String? get adminReportsError => _adminReportsError;

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

  Future<void> refreshAllDrivers() async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      _allDrivers = await SupabaseService.loadAllDrivers();
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_DRIVERS_ERROR: $error');
    }
  }

  Future<void> refreshAdminReports() async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      _adminReportsError = null;
      final previous = _adminReports == null
          ? null
          : Map<String, dynamic>.from(_adminReports!);
      _adminReports = await SupabaseService.loadAdminReports(phone);
      _notificationHub.onAdminReportsUpdated(previous, _adminReports);
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_REPORTS_ERROR: $error');
      _adminReportsError = error.toString();
      notifyListeners();
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
      final index = _allCouriers
          .indexWhere((c) => c['phone']?.toString() == courierPhone);
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

  Future<void> toggleDriverApproval(
    String driverPhone,
    bool isApproved,
  ) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      await SupabaseService.toggleDriverApprovalStatus(
        driverPhone: driverPhone,
        isApproved: isApproved,
      );
      final index = _allDrivers
          .indexWhere((d) => d['phone']?.toString() == driverPhone);
      if (index != -1) {
        _allDrivers[index] = Map<String, dynamic>.from(_allDrivers[index]);
        _allDrivers[index]['isApproved'] = isApproved;
      }
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_TOGGLE_DRIVER_ERROR: $error');
      rethrow;
    }
  }

  Future<void> rejectDriverApplication(
    String driverPhone,
    String reasonKey, {
    String? rejectionMessageAr,
  }) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      await SupabaseService.rejectDriverApplication(
        driverPhone: driverPhone,
        reasonKey: reasonKey,
        rejectionMessageAr: rejectionMessageAr,
      );
      await refreshAllDrivers();
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_REJECT_DRIVER_ERROR: $error');
      rethrow;
    }
  }

  Future<void> deleteDriverAccount(String driverPhone) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      await SupabaseService.deleteDriverAccount(phone, driverPhone);
      await refreshAllDrivers();
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_DELETE_DRIVER_ERROR: $error');
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

  Future<Map<String, dynamic>> toggleMerchantBazaarMember(
      String merchantPhone, bool isBazaarMember) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return const {};
    try {
      final result = await SupabaseService.toggleMerchantBazaarStatus(
        merchantPhone: merchantPhone,
        isBazaarMember: isBazaarMember,
      );
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

  Future<bool> setHomeCategoryPlatformEnabled(
    String categoryId,
    String platform,
    bool enabled,
  ) async {
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null) return false;

    final saveGeneration = ++_homeCategoriesSaveGeneration;
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
      if (saveGeneration != _homeCategoriesSaveGeneration) return true;
      _homeCategoryOverrides = saved;
      await HomeCategoriesCache.write(saved);
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('HOME_CATEGORIES_SAVE_ERROR: $error');
      if (saveGeneration != _homeCategoriesSaveGeneration) return false;
      _homeCategoryOverrides = previous;
      notifyListeners();
      return false;
    }
  }

  Future<void> handleTaxiStatusPush() async {
    if (!isDriver && !isCustomer) return;
    await refreshTaxiRequests();
  }
}
