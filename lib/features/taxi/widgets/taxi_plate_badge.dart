import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// لوحة مركبة عراقية — رقم السائق الحقيقي.
class TaxiPlateBadge extends StatelessWidget {
  final String plateNumber;

  const TaxiPlateBadge({
    super.key,
    required this.plateNumber,
  });

  @override
  Widget build(BuildContext context) {
    final plate = plateNumber.trim().isNotEmpty ? plateNumber.trim() : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCFC4C5)),
      ),
      child: Column(
        children: [
          Text(
            plate,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          Container(
            height: 1,
            width: 48,
            color: const Color(0xFFCFC4C5),
            margin: const EdgeInsets.symmetric(vertical: 3),
          ),
          const Text(
            'العراق',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
