import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../widgets/internal_contact_buttons.dart';

/// أزرار تواصل داخلية لإعلانات الكتالوج.
class CatalogContactButtons extends StatelessWidget {
  final ListItem item;
  final String? inquiryMessage;

  const CatalogContactButtons({
    super.key,
    required this.item,
    this.inquiryMessage,
  });

  String? get _merchantPhone {
    final phone = item.merchantPhone?.trim() ?? '';
    return phone.isNotEmpty ? phone : null;
  }

  @override
  Widget build(BuildContext context) {
    final merchantPhone = _merchantPhone;
    if (merchantPhone == null) {
      return const Text(
        'لا يتوفر تواصل مع التاجر لهذا الإعلان حالياً.',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          color: Colors.grey,
        ),
      );
    }

    return InternalContactButtons.store(
      merchantPhone: merchantPhone,
      storeName: item.merchantStoreName?.trim().isNotEmpty == true
          ? item.merchantStoreName!.trim()
          : item.nameAr,
      chatLabel: 'مراسلة التاجر',
      callLabel: 'اتصال',
    );
  }
}
