import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../utils/call_navigation.dart';
import '../utils/chat_navigation.dart';
import '../utils/guest_gate.dart';

/// أزرار تواصل داخلية: مراسلة + اتصال صوتي (Agora).
class InternalContactButtons extends StatelessWidget {
  final String threadType;
  final String threadId;
  final String otherPartyName;
  final String? receiverPhone;
  final String chatLabel;
  final String callLabel;
  final String? callerName;

  const InternalContactButtons({
    super.key,
    required this.threadType,
    required this.threadId,
    required this.otherPartyName,
    this.receiverPhone,
    this.chatLabel = 'مراسلة',
    this.callLabel = 'اتصال',
    this.callerName,
  });

  factory InternalContactButtons.order({
    required String orderId,
    required String otherPartyName,
    String? receiverPhone,
    String chatLabel = 'مراسلة',
    String callLabel = 'اتصال',
    String? callerName,
  }) {
    return InternalContactButtons(
      threadType: 'order',
      threadId: orderId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
      chatLabel: chatLabel,
      callLabel: callLabel,
      callerName: callerName,
    );
  }

  factory InternalContactButtons.taxi({
    required String requestId,
    required String otherPartyName,
    String? receiverPhone,
    String chatLabel = 'مراسلة',
    String callLabel = 'اتصال',
    String? callerName,
  }) {
    return InternalContactButtons(
      threadType: 'taxi',
      threadId: requestId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
      chatLabel: chatLabel,
      callLabel: callLabel,
      callerName: callerName,
    );
  }

  factory InternalContactButtons.store({
    required String merchantPhone,
    required String storeName,
    String chatLabel = 'مراسلة',
    String callLabel = 'اتصال',
    String? callerName,
  }) {
    final phone = merchantPhone.trim();
    return InternalContactButtons(
      threadType: 'store',
      threadId: phone,
      otherPartyName: storeName,
      receiverPhone: phone,
      chatLabel: chatLabel,
      callLabel: callLabel,
      callerName: callerName,
    );
  }

  Future<void> _openChat(BuildContext context) async {
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك لاستخدام المحادثة الداخلية.',
    )) {
      return;
    }
    await ChatNavigation.open(
      context,
      threadType: threadType,
      threadId: threadId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
    );
  }

  Future<void> _openCall(BuildContext context) async {
    final phone = receiverPhone?.trim() ?? '';
    if (phone.isEmpty) return;
    await CallNavigation.openOutgoing(
      context,
      threadType: threadType,
      threadId: threadId,
      otherPartyName: otherPartyName,
      receiverPhone: phone,
      callerName: callerName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCall = (receiverPhone?.trim().isNotEmpty ?? false);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openChat(context),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: Text(
              chatLabel,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        if (canCall) ...[
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _openCall(context),
              icon: const Icon(Icons.call, size: 16),
              label: Text(
                callLabel,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
