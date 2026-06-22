import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/supabase_service.dart';
import '../../utils/driver_profile_fields.dart';

class DriverService extends ChangeNotifier {
  // ── Driver state ───────────────────────────────────────────────
  Map<String, dynamic>? _driverProfile;
  String? _driverType;

  // ── Cross-domain state (set by AppProvider) ────────────────────
  String? _authPhone;
  String? _userRole;

  // ── Getters ─────────────────────────────────────────────────────
  Map<String, dynamic>? get driverProfile => _driverProfile;
  String? get driverType => _driverType;
  bool get hasDriverProfile =>
      _driverProfile != null &&
      (_driverProfile?['name']?.toString().trim().isNotEmpty ?? false);
  bool get isDriverApproved =>
      DriverProfileFields.isApproved(_driverProfile);
  bool get isDriver => _userRole == 'driver';

  bool get driverAcceptsTaxi =>
      _userRole == 'driver' || _driverServiceEnabled('taxi');
  bool get driverAcceptsDelivery =>
      _userRole == 'driver' && _driverServiceEnabled('delivery');
  bool get driverAcceptsBoth =>
      _userRole == 'driver' &&
      _driverServiceEnabled('taxi') &&
      _driverServiceEnabled('delivery');

  String get driverDisplayName {
    final name = DriverProfileFields.name(_driverProfile);
    if (name.isNotEmpty) return name;
    return 'سائق الغيث';
  }

  String get driverServiceModeLabelAr {
    if (_userRole != 'driver') return '';
    if (driverAcceptsBoth) return 'سائق تكسي + توصيل';
    if (driverAcceptsDelivery) return 'سائق توصيل';
    return 'سائق تكسي';
  }

  String get driverServiceModeLabelEn {
    if (_userRole != 'driver') return '';
    if (driverAcceptsBoth) return 'Taxi + Delivery';
    if (driverAcceptsDelivery) return 'Delivery Driver';
    return 'Taxi Driver';
  }

  // ── Cross-domain setters ──────────────────────────────────────
  void updateAuthPhone(String? phone) => _authPhone = phone;
  void updateUserRole(String? role) => _userRole = role;

  // ── Methods ────────────────────────────────────────────────────
  void setDriverType(String type) {
    _driverType = type == 'delivery' ? 'delivery' : 'taxi';
    notifyListeners();
  }

  // Used by AuthService via setUserRole
  void normalizeDriverProfileForRole() {
    if (_userRole != 'driver' || _driverProfile == null) return;
    final currentServices = _driverProfile?['services'];
    final deliveryEnabled =
        currentServices is Map && currentServices['delivery'] == true;
    _driverProfile = {
      ..._driverProfile!,
      'type': 'taxi',
      'services': {'taxi': true, 'delivery': deliveryEnabled},
    };
  }

  Future<void> setDriverProfile(Map<String, dynamic> profile) async {
    final wasApproved =
        DriverProfileFields.isApproved(_driverProfile);
    final normalized = Map<String, dynamic>.from(profile);
    normalized['type'] = 'taxi';
    normalized['services'] = profile['services'] ??
        _driverProfile?['services'] ??
        {'taxi': true, 'delivery': false};
    _driverType = 'taxi';
    normalized.remove('isApproved');
    normalized.remove('approvalStatus');
    normalized.remove('rejectionReasonKey');
    normalized.remove('rejectionMessageAr');
    normalized.remove('rejectedAt');

    _driverProfile = {
      ...?_driverProfile,
      ...normalized,
      'isApproved': wasApproved,
    };
    if (!wasApproved) {
      _driverProfile!['approvalStatus'] = 'pending';
      _driverProfile!.remove('rejectionReasonKey');
      _driverProfile!.remove('rejectionMessageAr');
      _driverProfile!.remove('rejectedAt');
    }
    if (_authPhone != null && _authPhone!.isNotEmpty) {
      await SupabaseService.saveUserState(
          _authPhone!, _buildRemoteState());
      await _persistLocalBackup();
    }
    notifyListeners();
  }

  Future<void> setDriverAvailability(bool available) async {
    await setDriverProfile({'available': available});
  }

  Future<void> setDriverServiceEnabled(
      String service, bool enabled) async {
    if (service != 'taxi' && service != 'delivery') return;
    final currentServices = Map<String, dynamic>.from(
      (_driverProfile?['services'] is Map)
          ? (_driverProfile!['services'] as Map)
          : {},
    );
    currentServices[service] = enabled;
    if (service == 'delivery' && enabled) {
      currentServices['taxi'] = true;
    }
    await setDriverProfile({
      'type': 'taxi',
      'services': currentServices,
    });
  }

  void notifyDriverApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  }) {
    _notifyDriverApprovalTransition(
      wasApproved: wasApproved,
      wasRejected: wasRejected,
      previousRejectionMessage: previousRejectionMessage,
    );
  }

  void _notifyDriverApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  }) {
    if (!hasDriverProfile) return;

    final nowApproved = isDriverApproved;
    final nowRejected =
        DriverProfileFields.isRejected(_driverProfile);
    final rejectionMessage =
        DriverProfileFields.rejectionMessage(_driverProfile);

    if (nowApproved && !wasApproved) {
      notifyListeners();
      return;
    }

    if (nowRejected &&
        (!wasRejected ||
            rejectionMessage != previousRejectionMessage)) {
      notifyListeners();
    }
  }

  // ── Internal helpers ──────────────────────────────────────────
  bool _driverServiceEnabled(String service) {
    final services = _driverProfile?['services'];
    if (services is Map) {
      final value = services[service];
      if (value is bool) return value;
    }
    switch (_driverType) {
      case 'delivery':
        return service == 'delivery';
      case 'both':
        return true;
      case 'taxi':
      default:
        return service == 'taxi';
    }
  }

  Map<String, dynamic> _buildRemoteState() {
    return {
      'driverType': _driverType,
      'driverProfile': _driverProfile,
    };
  }

  Future<void> _persistLocalBackup() async {}
}
