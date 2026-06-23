import 'package:flutter/material.dart';
import '../models/taxi_request.dart';
import '../widgets/taxi_type_image.dart';
import '../../../core/theme/app_colors.dart';

/// يعرض أجرة نوع التنقل المحدد
class TaxiFareDisplay extends StatelessWidget {
  final int fare;
  final TaxiType taxiType;

  const TaxiFareDisplay({
    super.key,
    required this.fare,
    this.taxiType = TaxiType.economic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: Row(
        children: [
          TaxiTypeImage(type: taxiType, width: 48, height: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taxiType.labelAr,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  taxiType.subtitleAr,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$fare د.ع',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
