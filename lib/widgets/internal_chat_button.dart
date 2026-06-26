import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../utils/chat_navigation.dart';
import '../utils/guest_gate.dart';

/// زر محادثة داخلية موحّد.
class InternalChatButton extends StatelessWidget {
  final String threadType;
  final String threadId;
  final String otherPartyName;
  final String? receiverPhone;
  final String label;
  final bool expanded;
  final EdgeInsetsGeometry? padding;

  const InternalChatButton({
    super.key,
    required this.threadType,
    required this.threadId,
    required this.otherPartyName,
    this.receiverPhone,
    this.label = 'مراسلة',
    this.expanded = true,
    this.padding,
  });

  factory InternalChatButton.order({
    required String orderId,
    required String otherPartyName,
    String? receiverPhone,
    String label = 'مراسلة',
    bool expanded = true,
  }) {
    return InternalChatButton(
      threadType: 'order',
      threadId: orderId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
      label: label,
      expanded: expanded,
    );
  }

  factory InternalChatButton.taxi({
    required String requestId,
    required String otherPartyName,
    String? receiverPhone,
    String label = 'مراسلة السائق',
    bool expanded = true,
  }) {
    return InternalChatButton(
      threadType: 'taxi',
      threadId: requestId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
      label: label,
      expanded: expanded,
    );
  }

  factory InternalChatButton.store({
    required String merchantPhone,
    required String storeName,
    String label = 'مراسلة',
    bool expanded = true,
  }) {
    return InternalChatButton(
      threadType: 'store',
      threadId: merchantPhone.trim(),
      otherPartyName: storeName,
      receiverPhone: merchantPhone.trim(),
      label: label,
      expanded: expanded,
    );
  }

  Future<void> _open(BuildContext context) async {
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك لاستخدام المحادثة الداخلية.',
    )) {
      return;
    }
    if (threadType == 'taxi') {
      await ChatNavigation.openTaxiChat(
        context,
        requestId: threadId,
        otherPartyName: otherPartyName,
        receiverPhone: receiverPhone,
      );
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

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(Icons.chat_bubble_outline, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      ),
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
