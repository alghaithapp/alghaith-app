import 'package:flutter/material.dart';

/// ألوان هوية الغيث — تركوازي + برتقالي (بانر الأجهزة الكهربائية).
abstract final class AppColors {
  /// تركوازي غامق — عناوين، شريط علوي، عناصر رئيسية.
  static const Color primary = Color(0xFF145B66);
  static const Color primaryDark = Color(0xFF0F4F5C);
  static const Color primaryLight = Color(0xFF1A6B78);

  /// برتقالي ذهبي — أزرار، تبويب نشط، شارات، CTA.
  static const Color accent = Color(0xFFF5A01D);
  static const Color accentDark = Color(0xFFDB8E15);
  static const Color accentLight = Color(0xFFFFB830);

  static const Color scaffold = Color(0xFFF2F2F7);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);

  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);

  static List<Color> get accentGradient => [
        accentDark,
        accent,
        accentLight,
      ];

  static LinearGradient get accentGradientLinear => const LinearGradient(
        colors: [accentDark, accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

/// للملفات التي كانت تستخدم kAppBrandRed.
const Color kAppBrandRed = AppColors.accent;
