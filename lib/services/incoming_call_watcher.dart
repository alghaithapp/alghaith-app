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
  final Map<String, String> _activeCalls = {}; // callId -> status
  void Function(Map<String, dynamic> data)? onIncomingCall;
  void Function(String callId)? onCallCancelled;

  bool get isActive => _timer != null;

  void bind(String phone) async {
    final normalized = PhoneUtils.normalize(phone);
    if (normalized.isEmpty) return;
    if (_boundPhone == normalized && _timer != null) return;

    unbind();
    _boundPhone = normalized;

    // جلب المكالمات النشطة عند الربط
    try {
      final initial = await ApiClient.instance.get('/db/voice/pending');
      if (initial is List) {
        for (final item in initial) {
          if (item is! Map) continue;
          final r = Map<String, dynamic>.from(item);
          final id = r['id']?.toString() ?? '';
          final st = r['status']?.toString() ?? '';
          final recv = r['receiver_phone']?.toString() ?? '';
          if (id.isNotEmpty && PhoneUtils.overlap(recv, normalized) && st == 'ringing') {
            _activeCalls[id] = st;
          }
        }
      }
    } catch (_) {}

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
    _activeCalls.clear();
  }

  Future<void> _poll() async {
    final phone = _boundPhone;
    if (phone == null || phone.isEmpty) return;

    try {
      final data = await ApiClient.instance.get('/db/voice/pending');
      if (data is! List) return;

      final seenInResponse = <String>{};

      for (final item in data) {
        if (item is! Map) continue;
        final record = Map<String, dynamic>.from(item);
        final callId = record['id']?.toString() ?? '';
        if (callId.isEmpty) continue;
        seenInResponse.add(callId);

        final receiverPhone = record['receiver_phone']?.toString() ?? '';
        if (!PhoneUtils.overlap(receiverPhone, phone)) continue;

        final status = record['status']?.toString() ?? '';
        _activeCalls[callId] = status;

        // مكالمة جديدة
        if (status == 'ringing' && !_handledCallIds.contains(callId)) {
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
      }

      // تحقق من المكالمات اللي كانت ringing وانتهت (ألغاها المتصل)
      final cancelledIds = <String>[];
      for (final entry in _activeCalls.entries) {
        if (entry.value == 'ringing' && !seenInResponse.contains(entry.key)) {
          cancelledIds.add(entry.key);
        }
      }
      for (final id in cancelledIds) {
        _activeCalls.remove(id);
        _handledCallIds.remove(id);
        onCallCancelled?.call(id);
      }
    } catch (error) {
      debugPrint('IncomingCallWatcher poll error: $error');
    }
  }
}
