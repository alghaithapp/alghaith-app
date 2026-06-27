import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/utils/phone_utils.dart';

/// يراقب المكالمات الواردة عبر الـ API عندما يكون التطبيق مفتوحاً
/// (بديل/مكمّل لـ FCM — مهم عندما يكون الطرفان داخل التطبيق).
class IncomingCallWatcher {
  IncomingCallWatcher._();

  static final IncomingCallWatcher instance = IncomingCallWatcher._();

  Timer? _timer;
  String? _boundPhone;
  final Set<String> _handledCallIds = {};
  void Function(Map<String, dynamic> data)? onIncomingCall;

  bool get isActive => _timer != null;

  void bind(String phone) {
    final normalized = PhoneUtils.normalize(phone);
    if (normalized.isEmpty) return;
    if (_boundPhone == normalized && _timer != null) return;

    unbind();
    _boundPhone = normalized;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_poll());
    });
    unawaited(_poll());
    debugPrint('IncomingCallWatcher: bound to $normalized');
  }

  void unbind() {
    _timer?.cancel();
    _timer = null;
    _boundPhone = null;
    _handledCallIds.clear();
  }

  Future<void> _poll() async {
    final phone = _boundPhone;
    if (phone == null || phone.isEmpty) return;

    try {
      final data = await ApiClient.instance.get('/db/voice/pending');
      if (data is! List) return;

      for (final item in data) {
        if (item is! Map) continue;
        final record = Map<String, dynamic>.from(item);
        final callId = record['id']?.toString() ?? '';
        if (callId.isEmpty || _handledCallIds.contains(callId)) continue;

        final receiverPhone = record['receiver_phone']?.toString() ?? '';
        if (!PhoneUtils.overlap(receiverPhone, phone)) continue;

        final status = record['status']?.toString() ?? '';
        if (status != 'ringing') continue;

        _handledCallIds.add(callId);
        if (_handledCallIds.length > 32) {
          _handledCallIds.remove(_handledCallIds.first);
        }

        onIncomingCall?.call({
          'eventKey': 'call:incoming',
          'threadType': record['thread_type']?.toString() ?? 'order',
          'threadId': record['thread_id']?.toString() ?? '',
          'channelName': record['channel_name']?.toString() ?? '',
          'callerName': record['caller_name']?.toString() ?? 'متصل',
          'callerPhone': record['caller_phone']?.toString() ?? '',
          'callLogId': callId,
        });
        break;
      }
    } catch (error) {
      debugPrint('IncomingCallWatcher poll error: $error');
    }
  }
}
