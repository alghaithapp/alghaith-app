import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_image.dart';

/// صورة شخصية للزبون أو الكابتن مع بديل بالحرف الأول.
class TaxiPartyAvatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final double radius;

  const TaxiPartyAvatar({
    super.key,
    this.photoUrl,
    required this.displayName,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl?.trim() ?? '';
    final initial = displayName.trim().isNotEmpty ? displayName.trim()[0] : '?';

    if (photo.isNotEmpty) {
      return AppImage(
        imageData: photo,
        width: radius * 2,
        height: radius * 2,
        borderRadius: BorderRadius.circular(radius),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: radius * 0.78,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
