import 'package:flutter/material.dart';

/// تأكيد إلغاء الرحلة — بدون سبب وبدون موافقة السائق.
Future<bool?> showTaxiCancelDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'إلغاء الرحلة',
        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'هل تريد إلغاء الرحلة؟',
        style: TextStyle(fontFamily: 'Cairo', fontSize: 15),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('رجوع', style: TextStyle(fontFamily: 'Cairo')),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(
            'نعم، إلغاء',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.red),
          ),
        ),
      ],
    ),
  );
}
