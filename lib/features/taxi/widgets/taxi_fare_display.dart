import 'package:flutter/material.dart';
import '../models/taxi_request.dart';
import '../../../core/theme/app_colors.dart';

/// يعرض نوع الخدمة (اقتصادي/سوبر) مع السعر
class TaxiFareDisplay extends StatelessWidget {
  final TaxiType taxiType;
  final int fareEconomic;
  final int fareSuper;
  final TaxiType? selectedType;
  final ValueChanged<TaxiType>? onChanged;

  const TaxiFareDisplay({
    super.key,
    required this.taxiType,
    required this.fareEconomic,
    required this.fareSuper,
    this.selectedType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FareOptionCard(
          taxiType: TaxiType.economic,
          label: 'اقتصادي',
          description: '4 مقاعد، قياسي',
          icon: Icons.local_taxi,
          fare: fareEconomic,
          isSelected: selectedType == TaxiType.economic ||
              (onChanged == null && taxiType == TaxiType.economic),
          onTap: onChanged != null ? () => onChanged!(TaxiType.economic) : null,
        ),
        const SizedBox(height: 8),
        _FareOptionCard(
          taxiType: TaxiType.superTaxiType,
          label: 'سوبر',
          description: 'حديث (2020+)، تقييم عالي',
          icon: Icons.directions_car,
          fare: fareSuper,
          isSelected: selectedType == TaxiType.superTaxiType ||
              (onChanged == null && taxiType == TaxiType.superTaxiType),
          onTap: onChanged != null ? () => onChanged!(TaxiType.superTaxiType) : null,
        ),
      ],
    );
  }
}

class _FareOptionCard extends StatelessWidget {
  final TaxiType taxiType;
  final String label, description;
  final IconData icon;
  final int fare;
  final bool isSelected;
  final VoidCallback? onTap;

  const _FareOptionCard({
    required this.taxiType,
    required this.label,
    required this.description,
    required this.icon,
    required this.fare,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? AppColors.accent : Colors.grey.shade300;
    final bgColor =
        isSelected ? AppColors.accent.withOpacity(0.05) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 28,
                color: label == 'سوبر' ? Colors.black87 : AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    description,
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
      ),
    );
  }
}
