import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/realtime/realtime_subscription_mixin.dart';
import '../../core/theme/app_colors.dart';
import '../../features/taxi/screens/driver/driver_home_screen.dart';
import '../../features/taxi/screens/driver/driver_request_screen.dart';
import '../../features/taxi/screens/driver/driver_trip_screen.dart';
import '../../features/taxi/screens/driver/driver_earnings_screen.dart';
import '../../providers/app_provider.dart';
import '../../services/supabase_service.dart';
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
        final sub = SupabaseService.realtime.subscribeToTable(
          table: 'taxi_requests',
          filterColumn: 'driver_phone',
          filterValue: phone,
          onData: (_) {
            if (!context.mounted) return;
            context.read<AppProvider>().refreshDriverTaxiRequests();
          },
        );
        trackChannel(sub);
      }
    });
  }

  @override
  void dispose() {
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
          child: _screens[_currentIndex],
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
