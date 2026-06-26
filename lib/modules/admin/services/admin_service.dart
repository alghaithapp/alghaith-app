import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../services/supabase_service.dart';
import '../../../core/storage/home_categories_cache.dart';
import '../../../models/home_category_platform_override.dart';
import '../../../models/app_models.dart';
import '../../../core/catalog/marketplace_catalog.dart';
import '../../../utils/platform_key.dart';

class AdminService extends ChangeNotifier {
  // ── Admin state ────────────────────────────────────────────────
  List<Map<String, dynamic>> _allMerchants = [];
  List<Map<String, dynamic>> _allCouriers = [];
  List<Map<String, dynamic>> _allDrivers = [];
  Map<String, dynamic>? _adminReports;
  String? _adminReportsError;

  // ── Home categories state ─────────────────────────────────────
  Map<String, HomeCategoryPlatformOverride> _homeCategoryOverrides = {};
  int _homeCategoriesSaveGeneration = 0;

  // ── Cross-domain state (set by AppProvider) ────────────────────
  String? _authPhone;
  String? _customerPhone;
  String? _userRole;

  // ── Getters ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> get allMerchants =>
      List<Map<String, dynamic>>.unmodifiable(_allMerchants);
  List<Map<String, dynamic>> get allCouriers =>
      List<Map<String, dynamic>>.unmodifiable(_allCouriers);
  List<Map<String, dynamic>> get allDrivers =>
      List<Map<String, dynamic>>.unmodifiable(_allDrivers);
  Map<String, dynamic>? get adminReports => _adminReports;
  String? get adminReportsError => _adminReportsError;

  bool get isAdmin => _userRole == 'admin';

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

  bool homeCategoryEnabledOnPlatform(
      String categoryId, String platform) {
    final override = _homeCategoryOverrides[categoryId];
    if (override != null) {
      final value = override.isEnabledOn(platform);
      if (value != null) return value;
    }
    return true;
  }

  // ── Cross-domain setters ──────────────────────────────────────
  void updateAuthPhone(String? phone) => _authPhone = phone;
  void updateCustomerPhone(String? phone) => _customerPhone = phone;
  void updateUserRole(String? role) => _userRole = role;
  // ── Methods ────────────────────────────────────────────────────
  Future<void> refreshAllMerchants() async {
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      _allMerchants = await SupabaseService.loadAllMerchants();
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_MERCHANTS_ERROR: $error');
    }
  }

  Future<void> refreshAllCouriers() async {
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      _allCouriers = await SupabaseService.loadAllCouriers();
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_COURIERS_ERROR: $error');
    }
  }

  Future<void> refreshAllDrivers() async {
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      _allDrivers = await SupabaseService.loadAllDrivers();
      notifyListeners();
    } catch (error) {
      debugPrint('ADMIN_DRIVERS_ERROR: $error');
    }
  }

  Future<void> refreshAdminReports() async {
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      _adminReportsError = null;
      _adminReports =
          await SupabaseService.loadAdminReports(phone);
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
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
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
        if (_onRestoreRemoteSession != null) {
          await _onRestoreRemoteSession!(selfPhone);
        }
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
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
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
        if (_onRestoreRemoteSession != null) {
          await _onRestoreRemoteSession!(selfPhone);
        }
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
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      await SupabaseService.toggleCourierApprovalStatus(
        courierPhone: courierPhone,
        isApproved: isApproved,
      );
      final index = _allCouriers.indexWhere(
          (c) => c['phone']?.toString() == courierPhone);
      if (index != -1) {
        _allCouriers[index] =
            Map<String, dynamic>.from(_allCouriers[index]);
        _allCouriers[index]['isApproved'] = isApproved;
      }
      final selfPhone = _trimmedOrNull(_authPhone);
      if (selfPhone != null &&
          PhoneUtils.variants(selfPhone).contains(
            PhoneUtils.normalize(courierPhone),
          )) {
        if (_onRestoreRemoteSession != null) {
          await _onRestoreRemoteSession!(selfPhone);
        }
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
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
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
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      await SupabaseService.toggleDriverApprovalStatus(
        driverPhone: driverPhone,
        isApproved: isApproved,
      );
      final index = _allDrivers.indexWhere(
          (d) => d['phone']?.toString() == driverPhone);
      if (index != -1) {
        _allDrivers[index] =
            Map<String, dynamic>.from(_allDrivers[index]);
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
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
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
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
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

  Future<void> toggleMerchantFrozen(
      String merchantPhone, bool isFrozen) async {
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return;
    try {
      await SupabaseService.toggleMerchantFreezeStatus(
        merchantPhone: merchantPhone,
        isFrozen: isFrozen,
      );
      final index = _allMerchants.indexWhere(
          (m) => m['phone'] == merchantPhone);
      if (index != -1) {
        _allMerchants[index] =
            Map<String, dynamic>.from(_allMerchants[index]);
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
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null || !SupabaseService.isConfigured) return const {};
    try {
      final result = await SupabaseService.toggleMerchantBazaarStatus(
        merchantPhone: merchantPhone,
        isBazaarMember: isBazaarMember,
      );
      final index = _allMerchants.indexWhere(
          (m) => m['phone'] == merchantPhone);
      if (index != -1) {
        _allMerchants[index] =
            Map<String, dynamic>.from(_allMerchants[index]);
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
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone == null) return false;

    final saveGeneration = ++_homeCategoriesSaveGeneration;
    final previous =
        Map<String, HomeCategoryPlatformOverride>.from(
            _homeCategoryOverrides);
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
    if (_isDriverOrCustomer) {
      if (_onRefreshTaxiRequests != null) {
        await _onRefreshTaxiRequests!();
      }
    }
  }

  bool get _isDriverOrCustomer =>
      _userRole == 'driver' || _userRole == 'customer';

  // ── Home categories config ─────────────────────────────────────
  void applyHomeCategoryOverrides(
      Map<String, HomeCategoryPlatformOverride> overrides) {
    _homeCategoryOverrides = overrides;
  }

  Future<void> refreshHomeCategoriesConfig() async {
    if (!SupabaseService.isConfigured) return;
    final loadGeneration = _homeCategoriesSaveGeneration;
    try {
      final overrides =
          await SupabaseService.loadHomeCategoriesConfig();
      if (loadGeneration != _homeCategoriesSaveGeneration) return;
      _homeCategoryOverrides = overrides;
      await HomeCategoriesCache.write(overrides);
      notifyListeners();
    } catch (error) {
      debugPrint('HOME_CATEGORIES_CONFIG_ERROR: $error');
    }
  }

  // ── Callbacks (set by AppProvider) ────────────────────────────
  Future<void> Function(String phone)? _onRestoreRemoteSession;
  Future<void> Function()? _onRefreshTaxiRequests;

  void setOnRestoreRemoteSession(
          Future<void> Function(String phone) cb) =>
      _onRestoreRemoteSession = cb;
  void setOnRefreshTaxiRequests(Future<void> Function() cb) =>
      _onRefreshTaxiRequests = cb;

  // ── Data apply methods ─────────────────────────────────────────
  void applyAdminState({
    List<Map<String, dynamic>>? allMerchants,
    List<Map<String, dynamic>>? allCouriers,
    List<Map<String, dynamic>>? allDrivers,
    Map<String, dynamic>? adminReports,
    Map<String, HomeCategoryPlatformOverride>? homeCategoryOverrides,
  }) {
    if (allMerchants != null) _allMerchants = allMerchants;
    if (allCouriers != null) _allCouriers = allCouriers;
    if (allDrivers != null) _allDrivers = allDrivers;
    if (adminReports != null || adminReports == null) {
      _adminReports = adminReports;
    }
    if (homeCategoryOverrides != null) {
      _homeCategoryOverrides = homeCategoryOverrides;
    }
  }

  // ── Utility methods ─────────────────────────────────────────────
  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
