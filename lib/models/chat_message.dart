class ChatMessage {
  final String id;
  final String threadType;
  final String threadId;
  final String senderPhone;
  final String? receiverPhone;
  final String? senderName;
  final String messageType;
  final String content;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.threadType,
    required this.threadId,
    required this.senderPhone,
    this.receiverPhone,
    this.senderName,
    this.messageType = 'text',
    required this.content,
    this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: (map['id'] ?? '').toString(),
      threadType: (map['thread_type'] ?? map['threadType'] ?? 'order').toString(),
      threadId: (map['thread_id'] ?? map['threadId'] ?? map['order_id'] ?? map['orderId'] ?? '').toString(),
      senderPhone: (map['sender_phone'] ?? map['senderPhone'] ?? '').toString(),
      receiverPhone: (map['receiver_phone'] ?? map['receiverPhone'])?.toString(),
      senderName: (map['sender_name'] ?? map['senderName'])?.toString(),
      messageType: (map['message_type'] ?? map['messageType'] ?? 'text').toString(),
      content: (map['content'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['created_at'] ?? map['createdAt'] ?? '').toString()),
    );
  }
}
