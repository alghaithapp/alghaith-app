import '../models/chat_thread_summary.dart';

/// عناوين المحادثات للمستخدم — تبقى واضحة حتى بعد انتهاء الطلب.
class ChatThreadLabels {
  ChatThreadLabels._();

  static String contextLabel(ChatThreadSummary thread) {
    final fromServer = thread.contextLabel?.trim();
    if (fromServer != null && fromServer.isNotEmpty) return fromServer;
    switch (thread.threadType) {
      case 'store':
        return 'محادثة متجر';
      case 'taxi':
        return 'رحلة تكسي';
      case 'order':
        return 'طلب #${shortId(thread.threadId)}';
      default:
        return 'محادثة داخل التطبيق';
    }
  }

  static String title(ChatThreadSummary thread) {
    final fromServer = thread.threadTitle?.trim();
    if (fromServer != null && fromServer.isNotEmpty) return fromServer;
    return thread.displayTitle;
  }

  static String subtitle(ChatThreadSummary thread) {
    return '${contextLabel(thread)} • ${thread.lastMessage}';
  }

  static String chatScreenSubtitle({
    required String threadType,
    required String threadId,
    String? contextLabel,
  }) {
    final label = contextLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    switch (threadType) {
      case 'store':
        return 'محادثة متجر — تبقى محفوظة داخل التطبيق';
      case 'taxi':
        return 'محادثة تكسي — رحلة $threadId';
      case 'order':
        return 'محادثة طلب — #${shortId(threadId)}';
      default:
        return 'تواصل داخل التطبيق فقط';
    }
  }

  static String shortId(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 8) return trimmed;
    return trimmed.substring(trimmed.length - 8);
  }
}
