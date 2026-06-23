class VoiceCallLog {
  final String id;
  final String threadType;
  final String threadId;
  final String callerPhone;
  final String receiverPhone;
  final String? callerName;
  final String direction;
  final String status;
  final int durationSeconds;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const VoiceCallLog({
    required this.id,
    required this.threadType,
    required this.threadId,
    required this.callerPhone,
    required this.receiverPhone,
    this.callerName,
    required this.direction,
    required this.status,
    required this.durationSeconds,
    this.startedAt,
    this.endedAt,
  });

  factory VoiceCallLog.fromMap(Map<String, dynamic> map) {
    return VoiceCallLog(
      id: map['id']?.toString() ?? '',
      threadType: (map['thread_type'] ?? map['threadType'] ?? 'order').toString(),
      threadId: (map['thread_id'] ?? map['threadId'] ?? '').toString(),
      callerPhone: (map['caller_phone'] ?? map['callerPhone'] ?? '').toString(),
      receiverPhone: (map['receiver_phone'] ?? map['receiverPhone'] ?? '').toString(),
      callerName: (map['caller_name'] ?? map['callerName'])?.toString(),
      direction: (map['direction'] ?? 'outgoing').toString(),
      status: (map['status'] ?? 'ended').toString(),
      durationSeconds: _readInt(map['duration_seconds'] ?? map['durationSeconds']),
      startedAt: DateTime.tryParse((map['started_at'] ?? map['startedAt'] ?? '').toString()),
      endedAt: DateTime.tryParse((map['ended_at'] ?? map['endedAt'] ?? '').toString()),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String statusLabelAr(bool isOutgoing) {
    switch (status) {
      case 'connected':
      case 'ended':
        return isOutgoing ? 'مكالمة صادرة' : 'مكالمة واردة';
      case 'missed':
      case 'no_answer':
        return isOutgoing ? 'لم يرد' : 'مكالمة فائتة';
      case 'failed':
        return 'فشل الاتصال';
      case 'ringing':
      case 'initiated':
        return 'جاري الاتصال';
      default:
        return 'مكالمة';
    }
  }

  String durationLabel() {
    final seconds = durationSeconds;
    if (seconds <= 0) return '—';
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    if (minutes <= 0) return '$remain ث';
    return '$minutes:${remain.toString().padLeft(2, '0')}';
  }
}
