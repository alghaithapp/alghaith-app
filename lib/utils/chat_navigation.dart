import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import 'guest_gate.dart';
import 'helpers.dart';

/// فتح محادثة داخلية بين طرفين داخل التطبيق.
class ChatNavigation {
  ChatNavigation._();

  static Future<void> open(
    BuildContext context, {
    required String threadType,
    required String threadId,
    required String otherPartyName,
    String? receiverPhone,
  }) async {
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك لاستخدام المحادثة الداخلية.',
    )) {
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          threadType: threadType,
          threadId: threadId,
          otherPartyName: otherPartyName,
          receiverPhone: receiverPhone,
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
    return open(
      context,
      threadType: 'taxi',
      threadId: requestId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
    );
  }

  static Future<void> openStoreChat(
    BuildContext context, {
    required String merchantPhone,
    required String storeName,
  }) {
    final phone = merchantPhone.trim();
    return open(
      context,
      threadType: 'store',
      threadId: phone,
      otherPartyName: storeName,
      receiverPhone: phone,
    );
  }

  static Future<void> openSupportChat(
    BuildContext context, {
    required String userPhone,
  }) {
    final phone = userPhone.trim();
    return open(
      context,
      threadType: 'support',
      threadId: phone,
      otherPartyName: 'الدعم الفني',
      receiverPhone: AppHelpers.supportWhatsAppNumber,
    );
  }
}
