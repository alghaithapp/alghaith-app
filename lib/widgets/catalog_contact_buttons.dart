import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/app_models.dart';
import '../utils/guest_gate.dart';
import '../utils/helpers.dart';

/// أزرار تواصل مباشر لإعلانات الكتالوج (واتساب + اتصال).
class CatalogContactButtons extends StatelessWidget {
  final ListItem item;
  final String? inquiryMessage;

  const CatalogContactButtons({
    super.key,
    required this.item,
    this.inquiryMessage,
  });

  String? get _phone {
    final phone = item.merchantPhone?.trim() ?? '';
    return phone.isNotEmpty ? phone : null;
  }

  String get _defaultInquiry =>
      'مرحبًا، أريد الاستفسار عن ${item.nameAr}';

  void _showNoPhoneSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'رقم التواصل غير متوفر في هذا الإعلان.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone;
    final message = inquiryMessage ?? _defaultInquiry;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: phone == null
                ? () => _showNoPhoneSnackBar(context)
                : () {
                    if (!GuestGate.requireAccount(
                      context,
                      message: 'سجّل دخولك للتواصل مع التاجر.',
                    )) {
                      return;
                    }
                    AppHelpers.launchWhatsApp(phone, message);
                  },
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text(
              'واتساب',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF5A01D),
              side: const BorderSide(color: Color(0xFFF5A01D)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: phone == null
                ? () => _showNoPhoneSnackBar(context)
                : () {
                    if (!GuestGate.requireAccount(
                      context,
                      message: 'سجّل دخولك للتواصل مع التاجر.',
                    )) {
                      return;
                    }
                    AppHelpers.makePhoneCall(phone);
                  },
            icon: const Icon(Icons.call_outlined, size: 18),
            label: const Text(
              'اتصال',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            style: AppButtonStyles.accentFilled(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}
