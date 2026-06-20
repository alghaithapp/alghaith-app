import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/supabase_service.dart';
import '../../utils/driver_profile_fields.dart';
import 'core_mixin.dart';
import 'persistence_mixin.dart';

mixin DriverMixin on AppCoreMixin, PersistenceMixin {
  void setDriverType(String type) {
    _driverType = type == 'delivery' ? 'delivery' : 'taxi';
    notifyListeners();
  }

  void _normalizeDriverProfileForRole() {
    if (_userRole != 'driver' || _driverProfile == null) return;
    _driverType = 'taxi';
    final currentServices = _driverProfile?['services'];
    final deliveryEnabled = currentServices is Map && currentServices['delivery'] == true;
    _driverProfile = {
      ..._driverProfile!,
      'type': 'taxi',
      'services': {'taxi': true, 'delivery': deliveryEnabled},
    };
  }

  Future<void> setDriverProfile(Map<String, dynamic> profile) async {
    final wasApproved = DriverProfileFields.isApproved(_driverProfile);
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
      await SupabaseService.saveUserState(_authPhone!, _buildRemoteState());
    }
    notifyListeners();
  }

  Future<void> setDriverAvailability(bool available) async {
    await setDriverProfile({'available': available});
  }

  Future<void> setDriverServiceEnabled(String service, bool enabled) async {
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

  void _notifyDriverApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  }) {
    if (!hasDriverProfile) return;

    final nowApproved = isDriverApproved;
    final nowRejected = DriverProfileFields.isRejected(_driverProfile);
    final rejectionMessage =
        DriverProfileFields.rejectionMessage(_driverProfile);

    if (nowApproved && !wasApproved) {
      _notificationHub.onDriverApproved();
      _queueUnreadPromptForRole('driver');
      return;
    }

    if (nowRejected &&
        (!wasRejected || rejectionMessage != previousRejectionMessage)) {
      _notificationHub.onDriverRejected(rejectionMessage);
      _queueUnreadPromptForRole('driver');
    }
  }
}
