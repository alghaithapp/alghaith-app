import 'package:flutter/widgets.dart';

/// ثوابت تصميم موحّدة (حواف، مسافات) لتوحيد مظهر الشاشات.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// حشوة الصفحات الافتراضية.
  static const EdgeInsets pagePadding = EdgeInsets.all(lg);
}

/// أنصاف أقطار الحواف الموحّدة.
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(md));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}
