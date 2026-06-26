import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../utils/call_navigation.dart';
import '../../../utils/chat_navigation.dart';
import '../../../utils/guest_gate.dart';
import '../../../utils/helpers.dart';
import '../providers/taxi_provider.dart';
import 'taxi_driver_contact_buttons.dart';

/// مراسلة + زر اتصال موحّد (داخلي أو خارج التطبيق).
class TaxiPartyContactButtons extends StatelessWidget {
  final String requestId;
  final String otherPartyName;
  final String? externalPhone;
  final String chatLabel;
  final String callLabel;

  const TaxiPartyContactButtons({
    super.key,
    required this.requestId,
    required this.otherPartyName,
    this.externalPhone,
    this.chatLabel = 'مراسلة',
    this.callLabel = 'اتصال',
  });

  String _resolveChatThreadId(BuildContext context) {
    try {
      final active = context.read<TaxiProvider>().currentRequest;
      if (active != null &&
          !active.isCompleted &&
          !active.isCancelled &&
          active.id.trim().isNotEmpty) {
        return active.id.trim();
      }
    } catch (_) {}
    return requestId.trim();
  }

  Future<void> _openChat(BuildContext context) async {
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك لاستخدام المحادثة الداخلية.',
    )) {
      return;
    }
    final tripId = _resolveChatThreadId(context);
    if (tripId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن فتح المحادثة — لا يوجد طلب تكسي نشط.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }
    await ChatNavigation.openTaxiChat(
      context,
      requestId: tripId,
      otherPartyName: otherPartyName,
      receiverPhone: externalPhone,
    );
  }

  Future<void> _showCallOptions(BuildContext context) async {
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك لإجراء مكالمة.',
    )) {
      return;
    }

    final phone = externalPhone?.trim() ?? '';
    final choice = await showModalBottomSheet<_TaxiCallChoice>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختر نوع الاتصال',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _CallChoiceTile(
              icon: Icons.phone_in_talk_rounded,
              title: 'اتصال داخل التطبيق',
              subtitle: 'مكالمة صوتية عبر الغيث',
              onTap: () => Navigator.pop(ctx, _TaxiCallChoice.internal),
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              _CallChoiceTile(
                icon: Icons.phone_rounded,
                title: 'اتصال خارجي',
                subtitle: 'عبر تطبيق الهاتف',
                onTap: () => Navigator.pop(ctx, _TaxiCallChoice.external),
              ),
            ],
          ],
        ),
      ),
    );

    if (!context.mounted || choice == null) return;

    switch (choice) {
      case _TaxiCallChoice.internal:
        await CallNavigation.openTaxiCall(
          context,
          requestId: requestId,
          otherPartyName: otherPartyName,
          receiverPhone: phone,
        );
      case _TaxiCallChoice.external:
        await AppHelpers.makePhoneCall(phone);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showCallOptions(context),
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
    );
  }
}

enum _TaxiCallChoice { internal, external }

class _CallChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CallChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// للتوافق — يستخدم زر الاتصال الموحّد مع واتساب منفصل إن وُجد رقم.
class TaxiCustomerContactSection extends StatelessWidget {
  final String requestId;
  final String driverName;
  final String? driverPhone;

  const TaxiCustomerContactSection({
    super.key,
    required this.requestId,
    required this.driverName,
    this.driverPhone,
  });

  @override
  Widget build(BuildContext context) {
    final phone = driverPhone?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaxiPartyContactButtons(
          requestId: requestId,
          otherPartyName: driverName,
          externalPhone: phone.isNotEmpty ? phone : null,
        ),
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 8),
          TaxiDriverContactButtons(
            driverPhone: phone,
            driverName: driverName,
            showCallButton: false,
          ),
        ],
      ],
    );
  }
}
