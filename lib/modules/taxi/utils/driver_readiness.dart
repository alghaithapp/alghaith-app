import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/notifications/push_notification_service.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/driver_profile_fields.dart';
import '../providers/taxi_provider.dart';

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

  /// تقييم الجاهزية مع محاولات إصلاح شائعة (توكن الإشعارات + الموقع).
  static Future<DriverReadinessStatus> evaluateReadiness({
    required AppProvider appProvider,
    required String phone,
    bool captureLocationIfMissing = true,
    bool retryPushToken = true,
  }) async {
    final notificationsOk = await checkNotificationsAuthorized();
    final push = PushNotificationService.instance;

    var pushTokenOk = push.hasToken;
    if (!pushTokenOk && phone.isNotEmpty) {
      pushTokenOk = await push.ensureUserBinding(phone);
    }
    if (!pushTokenOk && retryPushToken && phone.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      pushTokenOk = push.hasToken || await push.ensureUserBinding(phone);
    }

    final permission = await Geolocator.checkPermission();
    final locationPermissionOk = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    var profile = Map<String, dynamic>.from(appProvider.driverProfile ?? {});
    if (captureLocationIfMissing &&
        locationPermissionOk &&
        !_hasSavedLocation(profile)) {
      final pos = await captureCurrentPosition();
      if (pos != null) {
        profile['latitude'] = pos.latitude;
        profile['longitude'] = pos.longitude;
        profile['lat'] = pos.latitude;
        profile['lng'] = pos.longitude;
        await appProvider.setDriverProfile(profile);
      }
    }

    return fromProfile(
      profile: appProvider.driverProfile ?? profile,
      notificationsOk: notificationsOk,
      pushTokenOk: pushTokenOk,
      locationPermissionOk: locationPermissionOk,
    );
  }

  /// مصدر واحد لمزامنة «متصل / غير متصل» مع الخادم حسب الجاهزية الفعلية.
  static Future<DriverReadinessStatus> syncDriverOnlineFromReadiness({
    required AppProvider appProvider,
    required TaxiProvider taxiProvider,
    required String phone,
    bool captureLocationIfMissing = true,
  }) async {
    final status = await evaluateReadiness(
      appProvider: appProvider,
      phone: phone,
      captureLocationIfMissing: captureLocationIfMissing,
    );
    taxiProvider.setReadinessStatus(status);

    final profile = appProvider.driverProfile;
    final lat = (profile?['latitude'] ?? profile?['lat']) as num?;
    final lng = (profile?['longitude'] ?? profile?['lng']) as num?;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      taxiProvider.updateIncomingPollLocation(
        lat: lat.toDouble(),
        lng: lng.toDouble(),
      );
    }

    final shouldBeOnline = status.isReady;
    if (shouldBeOnline != taxiProvider.isOnline) {
      try {
        await taxiProvider.setOnline(shouldBeOnline);
      } catch (error, stack) {
        debugPrint('syncDriverOnlineFromReadiness failed: $error\n$stack');
      }
    }
    return status;
  }

  static String offlineHint(DriverReadinessStatus status) {
    final issues = status.issues;
    if (issues.isEmpty) return 'غير متصل';
    return issueTitle(issues.first);
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
