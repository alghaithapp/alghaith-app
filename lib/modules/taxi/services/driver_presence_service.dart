import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/taxi_provider.dart';
import 'taxi_api_service.dart';
import 'driver_presence_store.dart';

typedef DriverProfileReader = Map<String, dynamic>? Function();
typedef DriverProfileWriter = Future<void> Function(Map<String, dynamic> profile);

/// يُبقي السائق «متصل» ويحدّث موقعه بالخلفية (Foreground Service على أندرويد).
class DriverPresenceService {
  DriverPresenceService._();
  static final DriverPresenceService instance = DriverPresenceService._();

  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  String? _activePhone;
  TaxiProvider? _taxi;
  DriverProfileReader? _readProfile;
  DriverProfileWriter? _writeProfile;

  bool get isRunning => _activePhone != null && _activePhone!.isNotEmpty;

  LocationSettings _locationSettings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
        intervalDuration: const Duration(seconds: 12),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'الغيث — سائق تكسي',
          notificationText: 'أنت متصل وتستقبل طلبات التكسي',
          notificationChannelName: 'تتبع موقع السائق',
          enableWakeLock: true,
        ),
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 15,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );
  }

  Future<void> restoreIfNeeded({
    required String phone,
    required TaxiProvider taxiProvider,
    required DriverProfileReader readProfile,
    required DriverProfileWriter writeProfile,
  }) async {
    final wantsOnline = await DriverPresenceStore.getWantsOnline(phone);
    if (!wantsOnline) return;
    await start(
      phone: phone,
      taxiProvider: taxiProvider,
      readProfile: readProfile,
      writeProfile: writeProfile,
      announceOnline: true,
    );
  }

  Future<void> start({
    required String phone,
    required TaxiProvider taxiProvider,
    required DriverProfileReader readProfile,
    required DriverProfileWriter writeProfile,
    bool announceOnline = true,
  }) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return;

    await DriverPresenceStore.setWantsOnline(normalized, true);
    await _stopStreams();
    _activePhone = normalized;
    _taxi = taxiProvider;
    _readProfile = readProfile;
    _writeProfile = writeProfile;

    if (announceOnline) {
      try {
        await taxiProvider.setOnline(true);
      } catch (error, stack) {
        debugPrint('DriverPresence: setOnline failed: $error\n$stack');
      }
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_heartbeat());
    });

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen(
      (pos) => unawaited(_onPosition(pos)),
      onError: (error) => debugPrint('DriverPresence: position error: $error'),
    );

    unawaited(_captureOnce());
    unawaited(_heartbeat());
  }

  Future<void> stop({
    required String phone,
    required TaxiProvider taxiProvider,
    bool goOffline = false,
  }) async {
    final normalized = phone.trim();
    await _stopStreams();
    _activePhone = null;
    _taxi = null;
    _readProfile = null;
    _writeProfile = null;

    if (goOffline) {
      await DriverPresenceStore.setWantsOnline(normalized, false);
      try {
        await taxiProvider.setOnline(false);
      } catch (error) {
        debugPrint('DriverPresence: setOffline failed: $error');
      }
    }
  }

  /// عند تسجيل الخروج — إيقاف التتبع وإلغاء «متصل» على الخادم.
  Future<void> releaseForLogout(String phone) async {
    final normalized = phone.trim();
    await _stopStreams();
    _activePhone = null;
    _taxi = null;
    _readProfile = null;
    _writeProfile = null;
    if (normalized.isEmpty) return;
    await DriverPresenceStore.setWantsOnline(normalized, false);
    try {
      await TaxiApiService.setDriverOnlineStatus(false, manual: true);
    } catch (error) {
      debugPrint('DriverPresence: logout offline failed: $error');
    }
  }

  Future<void> _stopStreams() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _captureOnce() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings(),
      ).timeout(const Duration(seconds: 12));
      await _onPosition(pos);
    } catch (error) {
      debugPrint('DriverPresence: captureOnce failed: $error');
    }
  }

  Future<void> _heartbeat() async {
    final phone = _activePhone;
    final taxi = _taxi;
    if (phone == null || taxi == null) return;
    try {
      await TaxiApiService.setDriverOnlineStatus(true);
    } catch (error) {
      debugPrint('DriverPresence: heartbeat online ping failed: $error');
    }
  }

  Future<void> _onPosition(Position pos) async {
    final taxi = _taxi;
    final readProfile = _readProfile;
    if (taxi == null || readProfile == null) return;

    final activeTrip = taxi.currentRequest;
    final hasActiveTrip = activeTrip != null &&
        activeTrip.id.isNotEmpty &&
        !activeTrip.isCompleted &&
        !activeTrip.isCancelled;

    if (hasActiveTrip) {
      try {
        await taxi.updateDriverTripLocation(
          requestId: activeTrip.id,
          lat: pos.latitude,
          lng: pos.longitude,
        );
      } catch (_) {}
    }

    final profile = Map<String, dynamic>.from(readProfile() ?? {});
    final taxiType = profile['taxiType']?.toString();

    try {
      await TaxiApiService.updateDriverPresenceLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        taxiType: taxiType,
      );
    } catch (error) {
      debugPrint('DriverPresence: presence location failed: $error');
    }

    profile['latitude'] = pos.latitude;
    profile['longitude'] = pos.longitude;
    profile['lat'] = pos.latitude;
    profile['lng'] = pos.longitude;
    profile['locationUpdatedAt'] = DateTime.now().toIso8601String();

    taxi.updateIncomingPollLocation(
      lat: pos.latitude,
      lng: pos.longitude,
    );
  }
}
