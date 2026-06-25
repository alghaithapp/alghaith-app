import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../utils/helpers.dart';

/// تواصل الزبون مع السائق عبر الهاتف وواتساب (رقم السائق مباشرة).
class TaxiDriverContactButtons extends StatelessWidget {
  final String? driverPhone;
  final String driverName;

  const TaxiDriverContactButtons({
    super.key,
    required this.driverPhone,
    this.driverName = 'السائق',
  });

  String? get _phone {
    final value = driverPhone?.trim() ?? '';
    return value.isNotEmpty ? value : null;
  }

  Future<void> _callDriver() async {
    final phone = _phone;
    if (phone == null) return;
    await AppHelpers.makePhoneCall(phone);
  }

  Future<void> _whatsappDriver() async {
    final phone = _phone;
    if (phone == null) return;
    final name = driverName.trim().isNotEmpty ? driverName.trim() : 'السائق';
    await AppHelpers.launchWhatsApp(
      phone,
      'مرحباً $name، أنا زبون رحلة تكسي في تطبيق الغيث.',
    );
  }

  void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'رقم السائق غير متوفر حالياً',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = _phone != null;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: hasPhone
                ? _callDriver
                : () => _showUnavailable(context),
            icon: const Icon(Icons.phone, size: 18),
            label: const Text(
              'اتصال',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(
                color: hasPhone ? AppColors.primary : Colors.grey.shade300,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: hasPhone
                ? _whatsappDriver
                : () => _showUnavailable(context),
            icon: const Icon(Icons.chat, size: 18),
            label: const Text(
              'واتساب',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
