import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/realtime/realtime_subscription_mixin.dart';
import '../../core/theme/app_colors.dart';
import '../../features/taxi/providers/taxi_provider.dart';
import '../../features/taxi/screens/driver/driver_home_screen.dart';
import '../../features/taxi/screens/driver/driver_request_screen.dart';
import '../../features/taxi/screens/driver/driver_trip_screen.dart';
import '../../features/taxi/screens/driver/driver_earnings_screen.dart';
import '../../features/taxi/widgets/driver_readiness_banner.dart';
import '../../providers/app_provider.dart';
import '../../utils/driver_profile_fields.dart';
import '../../services/supabase_service.dart';
import '../../core/notifications/push_notification_inbox.dart';
import '../../utils/role_notification_poller.dart';
import '../../utils/role_switch_notifications.dart';
import '../../widgets/safe_bottom_bar.dart';
import 'driver_account_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> with RealtimeSubscriptionMixin {
  int _currentIndex = 0;
  Timer? _locationTimer;

  final List<Widget> _screens = const [
    DriverHomeScreen(),
    DriverRequestScreen(),
    DriverTripScreen(),
    DriverEarningsScreen(),
    DriverAccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      RoleSwitchNotificationPresenter.showIfNeeded(context);
      final provider = context.read<AppProvider>();
      final phone = provider.authPhone;
      if (phone != null && phone.isNotEmpty) {
        PushNotificationInbox.onTaxiIncomingPush = () async {
          if (!context.mounted) return;
          final taxi = context.read<TaxiProvider>();
          await taxi.fetchIncomingRequests();
        };
        // تحديث موقع السائق وتشغيل polling الطلبات
        _initDriverLocation(provider, phone);
        _startDriverLocationUpdates(provider);

        // Realtime للرحلة النشطة (بعد القبول)
        final sub = SupabaseService.realtime.subscribeToTable(
          table: 'taxi_requests',
          filterColumn: 'driver_phone',
          filterValue: phone,
          onData: (_) {
            if (!context.mounted) return;
            context.read<TaxiProvider>().loadDriverActiveRequest();
          },
        );
        trackChannel(sub);
      }
    });
  }

  Future<void> _initDriverLocation(AppProvider provider, String phone) async {
    if (!context.mounted) return;
    final taxi = context.read<TaxiProvider>();

    await bootstrapDriverReadiness(
      appProvider: provider,
      taxiProvider: taxi,
      phone: phone,
    );
    if (!context.mounted) return;

    final profile = Map<String, dynamic>.from(provider.driverProfile ?? {});
    final lat = (profile['latitude'] ?? profile['lat']) as num?;
    final lng = (profile['longitude'] ?? profile['lng']) as num?;
    final taxiType = DriverProfileFields.taxiTypeOrDefault(profile);

    taxi.startIncomingPolling(
      phone: phone,
      lat: lat?.toDouble(),
      lng: lng?.toDouble(),
      taxiType: taxiType,
    );
  }

  void _startDriverLocationUpdates(AppProvider provider) {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!mounted) return;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }

        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 8));

        final profile =
            Map<String, dynamic>.from(provider.driverProfile ?? {});
        profile['latitude'] = pos.latitude;
        profile['longitude'] = pos.longitude;
        profile['lat'] = pos.latitude;
        profile['lng'] = pos.longitude;
        await provider.setDriverProfile(profile);

        if (!mounted) return;
        context.read<TaxiProvider>().updateIncomingPollLocation(
              lat: pos.latitude,
              lng: pos.longitude,
            );
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    PushNotificationInbox.onTaxiIncomingPush = null;
    _locationTimer?.cancel();
    context.read<TaxiProvider>().stopPolling();
    disposeRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = AppColors.accent;

    return RoleNotificationPoller(
      role: 'driver',
      onRefresh: (provider) => provider.refreshDriverTaxiRequests(),
      pollBanners: (provider) => provider.pollTaxiBanners(),
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const DriverReadinessBanner(),
              Expanded(child: _screens[_currentIndex]),
            ],
          ),
        ),
        bottomNavigationBar: SafeBottomBar(
          color: isDark
              ? const Color(0xFF1A1A1A)
              : Colors.white.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.18 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, CupertinoIcons.house_fill, accentColor, 'الرئيسية'),
                _navItem(1, CupertinoIcons.bell_fill, accentColor, 'الطلبات',
                    badge: _pendingCount(context)),
                _navItem(2, Icons.route_rounded, accentColor, 'الرحلات'),
                _navItem(3, CupertinoIcons.money_dollar_circle_fill,
                    accentColor, 'الأرباح'),
                _navItem(4, CupertinoIcons.person_fill, accentColor, 'الحساب'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _pendingCount(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return provider.visibleTaxiIncomingRequests.length;
  }

  Widget _navItem(int index, IconData icon, Color accentColor, String label,
      {int badge = 0}) {
    final isActive = _currentIndex == index;
    final iconWidget = Icon(icon,
        color: isActive ? accentColor : CupertinoColors.systemGrey, size: 26);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          badge > 0
              ? Badge(
                  label: Text('$badge'),
                  child: iconWidget,
                )
              : iconWidget,
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? accentColor : CupertinoColors.systemGrey,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
