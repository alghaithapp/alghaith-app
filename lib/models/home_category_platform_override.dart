import '../utils/platform_key.dart';

/// إعداد ظهور قسم في الصفحة الرئيسية لكل منصة.
class HomeCategoryPlatformOverride {
  const HomeCategoryPlatformOverride({
    this.defaultValue,
    this.android,
    this.ios,
    this.web,
  });

  final bool? defaultValue;
  final bool? android;
  final bool? ios;
  final bool? web;

  bool? valueForPlatform(String platform) {
    switch (platform) {
      case PlatformKey.android:
        return android;
      case PlatformKey.ios:
        return ios;
      case PlatformKey.web:
        return web;
      case PlatformKey.defaultKey:
        return defaultValue;
      default:
        return null;
    }
  }

  HomeCategoryPlatformOverride withPlatform(String platform, bool enabled) {
    switch (platform) {
      case PlatformKey.android:
        return HomeCategoryPlatformOverride(
          defaultValue: defaultValue,
          android: enabled,
          ios: ios,
          web: web,
        );
      case PlatformKey.ios:
        return HomeCategoryPlatformOverride(
          defaultValue: defaultValue,
          android: android,
          ios: enabled,
          web: web,
        );
      case PlatformKey.web:
        return HomeCategoryPlatformOverride(
          defaultValue: defaultValue,
          android: android,
          ios: ios,
          web: enabled,
        );
      default:
        return HomeCategoryPlatformOverride(
          defaultValue: enabled,
          android: android,
          ios: ios,
          web: web,
        );
    }
  }

  Map<String, bool> toJson() {
    final out = <String, bool>{};
    if (defaultValue != null) out[PlatformKey.defaultKey] = defaultValue!;
    if (android != null) out[PlatformKey.android] = android!;
    if (ios != null) out[PlatformKey.ios] = ios!;
    if (web != null) out[PlatformKey.web] = web!;
    return out;
  }

  static HomeCategoryPlatformOverride? fromDynamic(dynamic raw) {
    if (raw == null) return null;
    if (raw is bool) {
      return HomeCategoryPlatformOverride(defaultValue: raw);
    }
    if (raw is! Map) return null;
    bool? readBool(dynamic value) {
      if (value == true) return true;
      if (value == false) return false;
      return null;
    }
    return HomeCategoryPlatformOverride(
      defaultValue: readBool(raw[PlatformKey.defaultKey] ?? raw['default']),
      android: readBool(raw[PlatformKey.android]),
      ios: readBool(raw[PlatformKey.ios]),
      web: readBool(raw[PlatformKey.web]),
    );
  }

  /// هل القسم مفعّل على المنصة المحددة؟ يُرجع null إن لم يُعرَّف خيار.
  bool? isEnabledOn(String platform) {
    final direct = valueForPlatform(platform);
    if (direct != null) return direct;
    if (platform != PlatformKey.defaultKey && defaultValue != null) {
      return defaultValue;
    }
    return null;
  }
}
