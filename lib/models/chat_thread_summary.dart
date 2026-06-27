class ChatThreadSummary {
  final String threadType;
  final String threadId;
  final String? otherPartyPhone;
  final String? otherPartyName;
  final String? threadTitle;
  final String? contextLabel;
  final String lastMessage;
  final DateTime? lastAt;
  final int unreadCount;
  final bool hasUnread;

  const ChatThreadSummary({
    required this.threadType,
    required this.threadId,
    this.otherPartyPhone,
    this.otherPartyName,
    this.threadTitle,
    this.contextLabel,
    required this.lastMessage,
    this.lastAt,
    this.unreadCount = 0,
    this.hasUnread = false,
  });

  factory ChatThreadSummary.fromMap(Map<String, dynamic> map) {
    return ChatThreadSummary(
      threadType: (map['thread_type'] ?? map['threadType'] ?? 'order').toString(),
      threadId: (map['thread_id'] ?? map['threadId'] ?? '').toString(),
      otherPartyPhone:
          (map['other_party_phone'] ?? map['otherPartyPhone'])?.toString(),
      otherPartyName:
          (map['other_party_name'] ?? map['otherPartyName'])?.toString(),
      threadTitle: (map['thread_title'] ?? map['threadTitle'])?.toString(),
      contextLabel:
          (map['context_label'] ?? map['contextLabel'])?.toString(),
      lastMessage: (map['last_message'] ?? map['lastMessage'] ?? '').toString(),
      lastAt: DateTime.tryParse(
        (map['last_at'] ?? map['lastAt'] ?? '').toString(),
      ),
      unreadCount: _readInt(map['unread_count'] ?? map['unreadCount']),
      hasUnread: _readBool(map['has_unread'] ?? map['hasUnread']) ||
          _readInt(map['unread_count'] ?? map['unreadCount']) > 0,
    );
  }

  static bool _readBool(dynamic value) => value == true;

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get displayTitle {
    final name = otherPartyName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final phone = otherPartyPhone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    switch (threadType) {
      case 'store':
        return 'زبون';
      case 'taxi':
        return 'محادثة تكسي';
      case 'order':
        return 'محادثة طلب';
      default:
        return 'محادثة';
    }
  }
}
