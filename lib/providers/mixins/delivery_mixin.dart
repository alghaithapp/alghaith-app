import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/supabase_service.dart';
import '../../utils/courier_profile_fields.dart';
import 'core_mixin.dart';
import 'persistence_mixin.dart';

mixin DeliveryMixin on AppCoreMixin, PersistenceMixin {
  Future<void> setCourierProfile(Map<String, dynamic> profile) async {
    final wasApproved = CourierProfileFields.isApproved(_courierProfile);
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
    final phone = _trimmedOrNull(_authPhone) ?? _trimmedOrNull(_customerPhone);
    if (phone != null) {
      await SupabaseService.saveUserState(phone, _buildRemoteState());
    }
    await _persistLocalBackup();
    notifyListeners();
  }

  Future<void> setCourierAvailability(bool available) async {
    await setCourierProfile({'available': available});
  }

  void _notifyCourierApprovalTransition({
    required bool wasApproved,
    required bool wasRejected,
    required String previousRejectionMessage,
  }) {
    if (!hasCourierProfile) return;

    final nowApproved = isCourierApproved;
    final nowRejected = CourierProfileFields.isRejected(_courierProfile);
    final rejectionMessage =
        CourierProfileFields.rejectionMessage(_courierProfile);

    if (nowApproved && !wasApproved) {
      _notificationHub.onCourierApproved();
      _queueUnreadPromptForRole('delivery');
      return;
    }

    if (nowRejected &&
        (!wasRejected || rejectionMessage != previousRejectionMessage)) {
      _notificationHub.onCourierRejected(rejectionMessage);
      _queueUnreadPromptForRole('delivery');
    }
  }

  Future<void> refreshCourierApprovalIfNeeded() async {
    if (_userRole != 'delivery' || !hasCourierProfile || isCourierApproved) {
      return;
    }
    await refreshAccountFromCloud();
  }

  Future<void> handleCourierStatusPush() async {
    if (_userRole != 'delivery' || !hasCourierProfile) return;
    await refreshAccountFromCloud();
  }
}
