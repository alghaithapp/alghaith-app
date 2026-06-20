import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../features/taxi/providers/taxi_provider.dart';
import '../../features/taxi/screens/driver/driver_home_screen.dart';
import '../../features/taxi/screens/driver/driver_request_screen.dart';
import '../../features/taxi/screens/driver/driver_trip_screen.dart';
import '../../features/taxi/screens/driver/driver_earnings_screen.dart';
import '../../widgets/safe_bottom_bar.dart';
import 'driver_account_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
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
    if (!context.mounted) return;
    // بدء polling فوراً
    final taxiProvider = context.read<TaxiProvider>();
    taxiProvider.startPolling(isDriver: true);
  }

  @override
  void dispose() {
    context.read<TaxiProvider>().stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = AppColors.accent;

    return Scaffold(
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
              _navItem(0, CupertinoIcons.graph_square_fill, accentColor,
                  'الرئيسية'),
              _navItem(1, CupertinoIcons.bell_fill, accentColor, 'الطلبات'),
              _navItem(2, Icons.route_rounded, accentColor, 'الرحلات'),
              _navItem(3, CupertinoIcons.money_dollar_circle_fill, accentColor, 'الأرباح'),
              _navItem(4, CupertinoIcons.person_fill, accentColor, 'الحساب'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, Color accentColor, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? accentColor : CupertinoColors.systemGrey,
              size: 26),
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

// تم نقل شاشات السائق الجديدة إلى features/taxi/screens/driver/
// DriverDashboardScreen ← DriverHomeScreen
// DriverRequestsScreen ← DriverRequestScreen
// DriverTripsScreen ← DriverTripScreen
// DriverAccountScreen ← يبقى كما هو

