import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../services/chat_thread_refresh.dart';
import '../../../utils/guest_gate.dart';
import '../../../utils/helpers.dart';

/// فتح محادثة داخلية بين طرفين داخل التطبيق.
class ChatNavigation {
  ChatNavigation._();

  static Future<void> open(
    BuildContext context, {
    required String threadType,
    required String threadId,
    required String otherPartyName,
    String? receiverPhone,
    Map<String, dynamic>? merchantProfile,
  }) async {
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك لاستخدام المحادثة الداخلية.',
    )) {
      return;
    }
    if (!context.mounted) return;
    final trimmedThreadId = threadId.trim();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          key: ValueKey('chat:$threadType:$trimmedThreadId'),
          threadType: threadType,
          threadId: trimmedThreadId,
          otherPartyName: otherPartyName,
          receiverPhone: receiverPhone,
          merchantProfile: merchantProfile,
        ),
      ),
    );
  }

  static Future<void> openOrderChat(
    BuildContext context, {
    required String orderId,
    required String otherPartyName,
    String? receiverPhone,
  }) {
    return open(
      context,
      threadType: 'order',
      threadId: orderId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
    );
  }

  static Future<void> openTaxiChat(
    BuildContext context, {
    required String requestId,
    required String otherPartyName,
    String? receiverPhone,
  }) {
    final threadId = requestId.trim();
    if (threadId.isEmpty) {
      if (!context.mounted) return Future.value();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن فتح المحادثة — معرّف الرحلة غير متوفر.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return Future.value();
    }
    return open(
      context,
      threadType: 'taxi',
      threadId: threadId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
    );
  }

  static Future<void> openStoreChat(
    BuildContext context, {
    required String merchantPhone,
    required String storeName,
    Map<String, dynamic>? merchantProfile,
  }) {
    final phone = merchantPhone.trim();
    return open(
      context,
      threadType: 'store',
      threadId: phone,
      otherPartyName: storeName,
      receiverPhone: phone,
      merchantProfile: merchantProfile,
    );
  }

  static Future<void> openSupportChat(BuildContext context) {
    return AppHelpers.launchWhatsApp(
      AppHelpers.supportWhatsAppNumber,
      'مرحباً، أحتاج مساعدة في تطبيق الغيث',
    );
  }

  static Future<void> handlePushData(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final eventKey = data['eventKey']?.toString() ?? '';
    if (eventKey != 'chat:new') return;

    final threadType = data['threadType']?.toString() ?? 'order';
    final threadId = data['threadId']?.toString() ?? '';
    if (threadId.isEmpty) return;

    final senderName = data['senderName']?.toString().trim();
    final senderPhone = data['senderPhone']?.toString().trim();

    final refreshed = ChatThreadRefreshHub.instance.notifyIfActive(
      threadType: threadType,
      threadId: threadId,
    );
    if (refreshed) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'رسالة جديدة من ${senderName?.isNotEmpty == true ? senderName! : 'مراسل'}',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    await open(
      context,
      threadType: threadType,
      threadId: threadId,
      otherPartyName: senderName?.isNotEmpty == true ? senderName! : 'مراسل',
      receiverPhone: senderPhone?.isNotEmpty == true ? senderPhone : null,
    );
  }
}
