import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/notifications/push_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../screens/shared/operator_setup_screen.dart';
import '../providers/taxi_provider.dart';
import '../utils/driver_readiness.dart';

/// شريط تنبيهات يضمن جاهزية السائق لاستقبال الطلبات والإشعارات.
class DriverReadinessBanner extends StatefulWidget {
  const DriverReadinessBanner({super.key});

  @override
  State<DriverReadinessBanner> createState() => _DriverReadinessBannerState();
}

class _DriverReadinessBannerState extends State<DriverReadinessBanner> {
  DriverReadinessStatus? _status;
  bool _isFixing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) await _refresh();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final phone = provider.authPhone;
    if (phone == null || phone.isEmpty) return;

    final status = await DriverReadiness.syncDriverOnlineFromReadiness(
      appProvider: provider,
      taxiProvider: context.read<TaxiProvider>(),
      phone: phone,
    );

    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _fixIssue(DriverReadinessIssue issue) async {
    if (_isFixing) return;
    setState(() => _isFixing = true);
    try {
      final provider = context.read<AppProvider>();
      final phone = provider.authPhone ?? '';

      switch (issue) {
        case DriverReadinessIssue.notificationsDenied:
          final granted = await DriverReadiness.requestNotifications();
          if (!granted && mounted) {
            await openAppSettings();
          }
          break;
        case DriverReadinessIssue.pushTokenMissing:
          if (phone.isNotEmpty) {
            await PushNotificationService.instance.ensureUserBinding(phone);
          }
          break;
        case DriverReadinessIssue.locationDenied:
          final permission = await DriverReadiness.ensureLocationPermission();
          if (permission == LocationPermission.deniedForever && mounted) {
            await Geolocator.openAppSettings();
          }
          break;
        case DriverReadinessIssue.locationMissing:
          final pos = await DriverReadiness.captureCurrentPosition();
          if (pos != null) {
            final profile =
                Map<String, dynamic>.from(provider.driverProfile ?? {});
            profile['latitude'] = pos.latitude;
            profile['longitude'] = pos.longitude;
            profile['lat'] = pos.latitude;
            profile['lng'] = pos.longitude;
            await provider.setDriverProfile(profile);
            if (mounted) {
              context.read<TaxiProvider>().updateIncomingPollLocation(
                    lat: pos.latitude,
                    lng: pos.longitude,
                  );
            }
          } else if (mounted) {
            await Geolocator.openAppSettings();
          }
          break;
        case DriverReadinessIssue.taxiTypeMissing:
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const OperatorSetupScreen(role: 'driver'),
            ),
          );
          break;
        case DriverReadinessIssue.taxiServiceDisabled:
          await provider.setDriverServiceEnabled('taxi', true);
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _isFixing = false);
        await _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null || status.isReady) {
      return const SizedBox.shrink();
    }

    final issues = status.issues;
    return Material(
      color: const Color(0xFFFFF8E6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.accent, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'أكمل الإعداد لاستقبال الطلبات',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (_isFixing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'تحديث',
                  ),
              ],
            ),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE0A3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DriverReadiness.issueTitle(issue),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DriverReadiness.issueDescription(issue),
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed:
                            _isFixing ? null : () => _fixIssue(issue),
                        child: const Text(
                          'إصلاح',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// تهيئة تلقائية لكل شروط استقبال الطلبات عند فتح واجهة السائق.
Future<void> bootstrapDriverReadiness({
  required AppProvider appProvider,
  required TaxiProvider taxiProvider,
  required String phone,
}) async {
  final push = PushNotificationService.instance;
  await push.initialize();
  await DriverReadiness.requestNotifications();
  await push.ensureUserBinding(phone);

  final normalized = DriverReadiness.ensureProfileDefaults(
    appProvider.driverProfile,
  );
  if (normalized.changed) {
    await appProvider.setDriverProfile(normalized.profile);
  }

  taxiProvider.hydrateOnlineFromProfile(appProvider.driverProfile);

  await DriverReadiness.ensureLocationPermission();

  await DriverReadiness.syncDriverOnlineFromReadiness(
    appProvider: appProvider,
    taxiProvider: taxiProvider,
    phone: phone,
    captureLocationIfMissing: true,
  );
}
