import 'dart:convert';

import '../../../models/chat_message.dart';

class ChatMessagePresenter {
  ChatMessagePresenter._();

  static bool isCall(ChatMessage message) => message.messageType == 'call';

  static bool isSticker(ChatMessage message) => message.messageType == 'sticker';

  static bool isImage(ChatMessage message) => message.messageType == 'image';

  static Map<String, dynamic>? callPayload(ChatMessage message) {
    if (!isCall(message)) return null;
    try {
      final decoded = jsonDecode(message.content);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static String callLabel(ChatMessage message, {required bool isMine}) {
    final data = callPayload(message);
    if (data == null) return 'مكالمة صوتية';

    final status = data['status']?.toString() ?? 'ended';
    final duration = int.tryParse('${data['durationSeconds'] ?? 0}') ?? 0;
    final durationText = duration > 0 ? ' · ${_formatDuration(duration)}' : '';

    if (isMine) {
      switch (status) {
        case 'missed':
        case 'no_answer':
          return 'مكالمة صادرة · لم يرد';
        case 'failed':
          return 'مكالمة صادرة · فشل الاتصال';
        default:
          return 'مكالمة صادرة$durationText';
      }
    }

    switch (status) {
      case 'missed':
      case 'no_answer':
        return 'مكالمة فائتة';
      case 'failed':
        return 'مكالمة واردة · فشل الاتصال';
      default:
        return 'مكالمة واردة$durationText';
    }
  }

  static String inboxPreview(ChatMessage message) {
    if (isSticker(message)) return 'ملصق';
    if (isImage(message)) return 'صورة';
    if (isCall(message)) {
      return callLabel(message, isMine: false).replaceAll('واردة', 'صوتية');
    }
    return message.content;
  }

  static String _formatDuration(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    if (minutes <= 0) return '$seconds ث';
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
