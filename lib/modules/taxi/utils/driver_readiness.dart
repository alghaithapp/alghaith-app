import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/notifications/push_notification_service.dart';
import '../../../utils/driver_profile_fields.dart';

enum DriverReadinessIssue {
  notificationsDenied,
  pushTokenMissing,
  locationDenied,
  locationMissing,
  taxiTypeMissing,
  taxiServiceDisabled,
}

class DriverReadinessStatus {
  final bool notificationsOk;
  final bool pushTokenOk;
  final bool locationPermissionOk;
  final bool locationSaved;
  final bool taxiTypeOk;
  final bool taxiServiceOk;

  const DriverReadinessStatus({
    required this.notificationsOk,
    required this.pushTokenOk,
    required this.locationPermissionOk,
    required this.locationSaved,
    required this.taxiTypeOk,
    required this.taxiServiceOk,
  });

  bool get isReady =>
      notificationsOk &&
      pushTokenOk &&
      locationPermissionOk &&
      locationSaved &&
      taxiTypeOk &&
      taxiServiceOk;

  List<DriverReadinessIssue> get issues {
    final result = <DriverReadinessIssue>[];
    if (!notificationsOk) result.add(DriverReadinessIssue.notificationsDenied);
    if (!pushTokenOk) result.add(DriverReadinessIssue.pushTokenMissing);
    if (!locationPermissionOk) result.add(DriverReadinessIssue.locationDenied);
    if (locationPermissionOk && !locationSaved) {
      result.add(DriverReadinessIssue.locationMissing);
    }
    if (!taxiTypeOk) result.add(DriverReadinessIssue.taxiTypeMissing);
    if (!taxiServiceOk) result.add(DriverReadinessIssue.taxiServiceDisabled);
    return result;
  }
}

abstract final class DriverReadiness {
  static bool _taxiServiceEnabled(Map<String, dynamic>? profile) {
    final services = profile?['services'];
    if (services is Map) {
      final value = services['taxi'];
      if (value is bool) return value;
    }
    return true;
  }

  static bool _hasSavedLocation(Map<String, dynamic>? profile) {
    final lat = (profile?['latitude'] ?? profile?['lat']) as num?;
    final lng = (profile?['longitude'] ?? profile?['lng']) as num?;
    return lat != null && lng != null && lat != 0 && lng != 0;
  }

  static DriverReadinessStatus fromProfile({
    required Map<String, dynamic>? profile,
    required bool notificationsOk,
    required bool pushTokenOk,
    required bool locationPermissionOk,
  }) {
    return DriverReadinessStatus(
      notificationsOk: notificationsOk,
      pushTokenOk: pushTokenOk,
      locationPermissionOk: locationPermissionOk,
      locationSaved: _hasSavedLocation(profile),
      taxiTypeOk: DriverProfileFields.taxiType(profile).isNotEmpty,
      taxiServiceOk: _taxiServiceEnabled(profile),
    );
  }

  static Future<bool> checkNotificationsAuthorized() async {
    final push = PushNotificationService.instance;
    if (!push.isFirebaseConfigured) return false;
    if (await push.areNotificationsAuthorized()) return true;

    if (await Permission.notification.isGranted) return true;
    return false;
  }

  static Future<bool> requestNotifications() async {
    final push = PushNotificationService.instance;
    if (!push.isFirebaseConfigured) return false;

    var granted = await push.requestNotificationsPermission();
    if (!granted) {
      final status = await Permission.notification.request();
      granted = status.isGranted;
    }
    return granted || await checkNotificationsAuthorized();
  }

  static Future<LocationPermission> ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  static Future<Position?> captureCurrentPosition() async {
    final permission = await ensureLocationPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 10));
  }

  static ({Map<String, dynamic> profile, bool changed}) ensureProfileDefaults(
    Map<String, dynamic>? profile,
  ) {
    final next = Map<String, dynamic>.from(profile ?? {});
    var changed = false;

    if (DriverProfileFields.taxiType(next).isEmpty) {
      next['taxiType'] = 'economic';
      changed = true;
    }

    final services = Map<String, dynamic>.from(
      next['services'] is Map ? next['services'] as Map : {},
    );
    if (services['taxi'] != true) {
      services['taxi'] = true;
      next['services'] = services;
      changed = true;
    }

    if (next['available'] != true) {
      next['available'] = true;
      changed = true;
    }

    return (profile: next, changed: changed);
  }

  static String issueTitle(DriverReadinessIssue issue) {
    switch (issue) {
      case DriverReadinessIssue.notificationsDenied:
        return 'فعّل الإشعارات';
      case DriverReadinessIssue.pushTokenMissing:
        return 'اربط جهازك بالإشعارات';
      case DriverReadinessIssue.locationDenied:
        return 'اسمح بالوصول للموقع';
      case DriverReadinessIssue.locationMissing:
        return 'حدّث موقعك الحالي';
      case DriverReadinessIssue.taxiTypeMissing:
        return 'حدد نوع مركبتك';
      case DriverReadinessIssue.taxiServiceDisabled:
        return 'فعّل خدمة التكسي';
    }
  }

  static String issueDescription(DriverReadinessIssue issue) {
    switch (issue) {
      case DriverReadinessIssue.notificationsDenied:
        return 'لن تصلك طلبات الرحلات على الهاتف بدون إذن الإشعارات.';
      case DriverReadinessIssue.pushTokenMissing:
        return 'التطبيق لم يحفظ توكن الإشعارات بعد. أعد المحاولة أو أعد فتح التطبيق.';
      case DriverReadinessIssue.locationDenied:
        return 'النظام يحتاج موقعك لإرسال الطلبات القريبة منك فقط.';
      case DriverReadinessIssue.locationMissing:
        return 'لم يُحفظ موقعك بعد. اضغط لتحديث الموقع الآن.';
      case DriverReadinessIssue.taxiTypeMissing:
        return 'اختر نوع التكسي (اقتصادي / تكتك / واز) ليتطابق مع طلبات الزبائن.';
      case DriverReadinessIssue.taxiServiceDisabled:
        return 'خدمة التكسي معطّلة في حسابك. فعّلها لاستقبال الطلبات.';
    }
  }
}
