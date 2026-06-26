import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../utils/call_navigation.dart';
import '../utils/chat_navigation.dart';
import '../utils/guest_gate.dart';
import '../utils/merchant_profile_fields.dart';

/// أزرار تواصل داخلية — مراسلة + مكالمة صوتية داخل التطبيق فقط.
class InternalContactButtons extends StatelessWidget {
  final String threadType;
  final String threadId;
  final String otherPartyName;
  final String? receiverPhone;
  final String chatLabel;
  final String callLabel;
  final Map<String, dynamic>? merchantProfile;

  const InternalContactButtons({
    super.key,
    required this.threadType,
    required this.threadId,
    required this.otherPartyName,
    this.receiverPhone,
    this.chatLabel = 'مراسلة',
    this.callLabel = 'اتصال',
    this.merchantProfile,
  });

  factory InternalContactButtons.order({
    required String orderId,
    required String otherPartyName,
    String? receiverPhone,
    Map<String, dynamic>? merchantProfile,
    String chatLabel = 'مراسلة',
    String callLabel = 'اتصال',
  }) {
    return InternalContactButtons(
      threadType: 'order',
      threadId: orderId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
      merchantProfile: merchantProfile,
      chatLabel: chatLabel,
      callLabel: callLabel,
    );
  }

  factory InternalContactButtons.taxi({
    required String requestId,
    required String otherPartyName,
    String? receiverPhone,
    String chatLabel = 'مراسلة',
    String callLabel = 'اتصال',
  }) {
    return InternalContactButtons(
      threadType: 'taxi',
      threadId: requestId,
      otherPartyName: otherPartyName,
      receiverPhone: receiverPhone,
      chatLabel: chatLabel,
      callLabel: callLabel,
    );
  }

  factory InternalContactButtons.store({
    required String merchantPhone,
    required String storeName,
    Map<String, dynamic>? merchantProfile,
    String chatLabel = 'مراسلة',
    String callLabel = 'اتصال',
  }) {
    final phone = merchantPhone.trim();
    return InternalContactButtons(
      threadType: 'store',
      threadId: phone,
      otherPartyName: storeName,
      receiverPhone: phone,
      merchantProfile: merchantProfile,
      chatLabel: chatLabel,
      callLabel: callLabel,
    );
  }

  bool get _canCall {
    if (threadType == 'taxi' && threadId.trim().isNotEmpty) {
      return MerchantProfileFields.isAcceptingCustomerCalls(merchantProfile);
    }
    return (receiverPhone?.trim().isNotEmpty ?? false) &&
        MerchantProfileFields.isAcceptingCustomerCalls(merchantProfile);
  }

  String? get _callsBlockedMessage =>
      MerchantProfileFields.callsUnavailableMessageAr(merchantProfile);

  Future<void> _openChat(BuildContext context) async {
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
      merchantProfile: merchantProfile,
    );
  }

  Future<void> _startCall(BuildContext context) async {
    final phone = receiverPhone?.trim() ?? '';
    if (phone.isEmpty && threadType != 'taxi') return;

    final blocked = _callsBlockedMessage;
    if (blocked != null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blocked,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك لإجراء مكالمة داخل التطبيق.',
    )) {
      return;
    }

    await CallNavigation.openOutgoing(
      context,
      threadType: threadType,
      threadId: threadId,
      otherPartyName: otherPartyName,
      receiverPhone: phone.isNotEmpty ? phone : null,
      merchantProfile: merchantProfile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final blockedMessage = _callsBlockedMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
            if (_canCall) ...[
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _startCall(context),
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
        ),
        if (blockedMessage != null &&
            (receiverPhone?.trim().isNotEmpty ?? false)) ...[
          const SizedBox(height: 8),
          Text(
            blockedMessage,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
