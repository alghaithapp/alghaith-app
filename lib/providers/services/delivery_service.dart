import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/supabase_service.dart';
import '../../utils/courier_profile_fields.dart';

class DeliveryService extends ChangeNotifier {
  // ── Delivery state ─────────────────────────────────────────────
  Map<String, dynamic>? _courierProfile;

  // ── Cross-domain state (set by AppProvider) ────────────────────
  String? _authPhone;
  String? _customerPhone;
  String? _userRole;

  // ── Getters ─────────────────────────────────────────────────────
  Map<String, dynamic>? get courierProfile => _courierProfile;
  bool get hasCourierProfile =>
      CourierProfileFields.isComplete(_courierProfile);
  bool get isCourierApproved =>
      CourierProfileFields.isApproved(_courierProfile);
  bool get canUseCourierAccount => hasCourierProfile && isCourierApproved;
  bool get isDelivery => _userRole == 'delivery';

  String get deliveryCourierName {
    final name = _courierProfile?['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return 'مندوب التوصيل';
  }

  String get courierPhone {
    final phone = _courierProfile?['phone']?.toString().trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return _authPhone ?? _customerPhone ?? '';
  }

  bool get isCourierAvailable {
    final value = _courierProfile?['available'];
    if (value is bool) return value;
    return true;
  }

  // ── Cross-domain setters ──────────────────────────────────────
  void updateAuthPhone(String? phone) => _authPhone = phone;
  void updateCustomerPhone(String? phone) => _customerPhone = phone;
  void updateUserRole(String? role) => _userRole = role;

  /// تحميل ملف المندوب من بيانات السيرفر (دون حفظ)
  void loadProfileFromRemoteState(Map<String, dynamic>? state) {
    if (state == null) return;
    final cp = state['courierProfile'];
    if (cp is Map) {
      _courierProfile = Map<String, dynamic>.from(cp);
    }
  }

  // ── Methods ────────────────────────────────────────────────────
  Future<void> setCourierProfile(Map<String, dynamic> profile) async {
    final wasApproved =
        CourierProfileFields.isApproved(_courierProfile);
    final next = Map<String, dynamic>.from(profile);
    next.remove('isApproved');
    next.remove('approvalStatus');
    next.remove('rejectionReasonKey');
    next.remove('rejectionMessageAr');
    next.remove('rejectedAt');
    _courierProfile = {
      ...?_courierProfile,
      ...next,
      'isApproved': wasApproved,
    };
    if (!wasApproved) {
      _courierProfile!['approvalStatus'] = 'pending';
      _courierProfile!.remove('rejectionReasonKey');
      _courierProfile!.remove('rejectionMessageAr');
      _courierProfile!.remove('rejectedAt');
    }
    final phone =
        _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone != null) {
      await SupabaseService.saveUserState(phone, _buildRemoteState());
    }
    await _persistLocalBackup();
    notifyListeners();
  }

  Future<void> setCourierAvailability(bool available) async {
    await setCourierProfile({'available': available});
  }

  void notifyCourierApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  }) {
    _notifyCourierApprovalTransition(
      wasApproved: wasApproved,
      wasRejected: wasRejected,
      previousRejectionMessage: previousRejectionMessage,
    );
  }

  void _notifyCourierApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  }) {
    if (!hasCourierProfile) return;

    final nowApproved = isCourierApproved;
    final nowRejected =
        CourierProfileFields.isRejected(_courierProfile);
    final rejectionMessage =
        CourierProfileFields.rejectionMessage(_courierProfile);

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

  Future<void> refreshCourierApprovalIfNeeded() async {
    if (_userRole != 'delivery' || !hasCourierProfile || isCourierApproved) {
      return;
    }
    if (_onRefreshAccountFromCloud != null) {
      await _onRefreshAccountFromCloud!();
    }
  }

  Future<void> handleCourierStatusPush() async {
    if (_userRole != 'delivery' || !hasCourierProfile) return;
    if (_onRefreshAccountFromCloud != null) {
      await _onRefreshAccountFromCloud!();
    }
  }

  // ── Callbacks (set by AppProvider) ────────────────────────────
  Future<void> Function()? _onRefreshAccountFromCloud;

  void setOnRefreshAccountFromCloud(Future<void> Function() cb) =>
      _onRefreshAccountFromCloud = cb;

  // ── Internal helpers ──────────────────────────────────────────
  Map<String, dynamic> _buildRemoteState() {
    return {
      'courierProfile': _courierProfile,
    };
  }

  Future<void> _persistLocalBackup() async {}

  String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
