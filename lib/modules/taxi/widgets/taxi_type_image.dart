import 'package:flutter/material.dart';

import '../models/taxi_request.dart';

/// صورة نوع التنقل مع أيقونة احتياطية إذا تعذّر تحميل الملف.
class TaxiTypeImage extends StatelessWidget {
  final TaxiType type;
  final double width;
  final double height;
  final BoxFit fit;
  final bool showBackground;

  const TaxiTypeImage({
    super.key,
    required this.type,
    this.width = 56,
    this.height = 56,
    this.fit = BoxFit.contain,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      type.imageAsset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Icon(
        type.icon,
        color: type.accentColor,
        size: width * 0.5,
      ),
    );

    if (!showBackground) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: image,
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: type.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: image,
    );
  }
}
