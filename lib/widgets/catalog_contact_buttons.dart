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

  String? get _callPhone {
    if (item.merchantShowPhoneToCustomers == false) return null;
    final phone = item.merchantPhone?.trim() ?? '';
    return phone.isNotEmpty ? phone : null;
  }

  String? get _whatsAppPhone {
    if (item.merchantShowWhatsAppToCustomers == false) return null;
    final whatsapp = item.merchantWhatsApp?.trim() ?? '';
    if (whatsapp.isNotEmpty) return whatsapp;
    final phone = item.merchantPhone?.trim() ?? '';
    return phone.isNotEmpty ? phone : null;
  }

  String get _defaultInquiry =>
      'مرحبًا، أريد الاستفسار عن ${item.nameAr}';

  @override
  Widget build(BuildContext context) {
    final callPhone = _callPhone;
    final whatsappPhone = _whatsAppPhone;
    final message = inquiryMessage ?? _defaultInquiry;

    if (callPhone == null && whatsappPhone == null) {
      return const Text(
        'التاجر أخفى وسائل التواصل لهذا الإعلان.',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          color: Colors.grey,
        ),
      );
    }

    return Row(
      children: [
        if (whatsappPhone != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                if (!GuestGate.requireAccount(
                  context,
                  message: 'سجّل دخولك للتواصل مع التاجر.',
                )) {
                  return;
                }
                AppHelpers.launchWhatsApp(whatsappPhone, message);
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
        if (whatsappPhone != null && callPhone != null) const SizedBox(width: 10),
        if (callPhone != null)
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                if (!GuestGate.requireAccount(
                  context,
                  message: 'سجّل دخولك للتواصل مع التاجر.',
                )) {
                  return;
                }
                AppHelpers.makePhoneCall(callPhone);
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
