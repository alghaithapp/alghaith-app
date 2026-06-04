import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ألوان واجهة الشريط السفلي — مصدر واحد للأزرار الرئيسية.
abstract final class AppBottomNavStyle {
  static Color get activeColor => AppColors.accent;

  static List<Color> get primaryGradientColors => [
        AppColors.accentDark,
        AppColors.accent,
        AppColors.accentLight,
      ];

  static LinearGradient get primaryGradient => LinearGradient(
        colors: primaryGradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static BoxDecoration primaryButtonDecoration({double radius = 28}) {
    return BoxDecoration(
      gradient: primaryGradient,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.35),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static Widget primaryActionButton({
    required VoidCallback onPressed,
    required Widget child,
    double radius = 28,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 18),
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          width: double.infinity,
          decoration: primaryButtonDecoration(radius: radius),
          padding: padding,
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
