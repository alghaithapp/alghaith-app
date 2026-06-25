import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../models/taxi_favorite_place.dart';
import '../providers/taxi_provider.dart';

/// اختصارات الأماكن المفضلة في شاشة طلب التكسي.
class TaxiFavoritePlacesRow extends StatelessWidget {
  final ValueChanged<TaxiFavoritePlace> onSelected;

  const TaxiFavoritePlacesRow({
    super.key,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final places = context.watch<TaxiProvider>().favoritePlaces;
    if (places.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'عناوينك المحفوظة',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: places.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final place = places[index];
              return ActionChip(
                avatar: const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                label: Text(
                  place.label,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
                onPressed: () => onSelected(place),
              );
            },
          ),
        ),
      ],
    );
  }
}
