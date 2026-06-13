import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// مفتاح المنصة الحالية — يُستخدم في إعدادات الأقسام عن بُعد.
abstract final class PlatformKey {
  static const String android = 'android';
  static const String ios = 'ios';
  static const String web = 'web';
  static const String defaultKey = 'default';

  static const List<String> adminPlatforms = [android, ios];

  static String get current {
    if (kIsWeb) return web;
    try {
      if (Platform.isAndroid) return android;
      if (Platform.isIOS) return ios;
    } catch (_) {}
    return defaultKey;
  }
}
