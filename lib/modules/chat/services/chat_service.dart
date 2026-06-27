import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/chat_message.dart';
import '../../../models/chat_thread_summary.dart';

class ChatService {
  static Future<List<ChatMessage>> fetchMessages({
    required String threadType,
    required String threadId,
    int limit = 30,
    int offset = 0,
    String? after,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
    };
    if (offset > 0) params['offset'] = offset.toString();
    if (after != null && after.isNotEmpty) params['after'] = after;

    final data = await ApiClient.instance.get(
      '/db/chat/$threadType/$threadId',
      queryParameters: params.isEmpty ? null : params,
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => ChatMessage.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<ChatThreadSummary>> fetchInbox() async {
    final data = await ApiClient.instance.get('/db/chat/inbox/threads');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => ChatThreadSummary.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<void> deleteThread({
    required String threadType,
    required String threadId,
    String? otherPartyPhone,
  }) async {
    await ApiClient.instance.delete(
      '/db/chat/$threadType/$threadId',
      queryParameters: {
        if (otherPartyPhone != null && otherPartyPhone.trim().isNotEmpty)
          'otherPartyPhone': otherPartyPhone.trim(),
      },
    );
  }

  static Future<void> markThreadRead({
    required String threadType,
    required String threadId,
    String? otherPartyPhone,
  }) async {
    await ApiClient.instance.post(
      '/db/chat/$threadType/$threadId/read',
      body: {
        if (otherPartyPhone != null && otherPartyPhone.trim().isNotEmpty)
          'otherPartyPhone': otherPartyPhone.trim(),
      },
    );
  }

  static Future<ChatMessage> sendMessage({
    required String threadType,
    required String threadId,
    required String content,
    String? receiverPhone,
    String? senderName,
    String messageType = 'text',
  }) async {
    final data = await ApiClient.instance.post(
      '/db/chat/$threadType/$threadId',
      body: {
        'content': content,
        if (receiverPhone != null && receiverPhone.trim().isNotEmpty)
          'receiverPhone': receiverPhone.trim(),
        if (senderName != null && senderName.trim().isNotEmpty)
          'senderName': senderName.trim(),
        'messageType': messageType,
      },
    );
    if (data is! Map) {
      throw ApiException('تعذر إرسال الرسالة.');
    }
    return ChatMessage.fromMap(Map<String, dynamic>.from(data));
  }
}
