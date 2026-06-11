import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// أنماط أزرار موحّدة — نص وأيقونات بيضاء على الخلفية البرتقالية.
abstract final class AppButtonStyles {
  static ButtonStyle accentFilled({
    BorderRadiusGeometry borderRadius =
        const BorderRadius.all(Radius.circular(14)),
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.45),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
      iconColor: Colors.white,
      padding: padding,
      minimumSize: minimumSize,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
    );
  }

  static ButtonStyle accentElevated({
    BorderRadiusGeometry borderRadius =
        const BorderRadius.all(Radius.circular(14)),
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.45),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
      iconColor: Colors.white,
      padding: padding,
      minimumSize: minimumSize,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      platform: TargetPlatform.iOS,
      useMaterial3: true,
      brightness: Brightness.light,
    );
    return base.copyWith(
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        surface: AppColors.card,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.scaffold,
      primaryColor: AppColors.primary,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w900,
          fontSize: 18,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: AppColors.accent,
        barBackgroundColor: AppColors.card,
      ),
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: AppButtonStyles.accentFilled()),
      elevatedButtonTheme:
          ElevatedButtonThemeData(style: AppButtonStyles.accentElevated()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: AppColors.accent,
        labelStyle: const TextStyle(fontFamily: 'Cairo'),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      platform: TargetPlatform.iOS,
      useMaterial3: true,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryLight,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        surface: const Color(0xFF1A1A1A),
      ),
      scaffoldBackgroundColor: const Color(0xFF111111),
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.accent,
      ),
      filledButtonTheme: FilledButtonThemeData(style: AppButtonStyles.accentFilled()),
      elevatedButtonTheme:
          ElevatedButtonThemeData(style: AppButtonStyles.accentElevated()),
    );
  }
}
