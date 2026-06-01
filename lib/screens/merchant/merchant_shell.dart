import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import 'merchant_dashboard_screen.dart';
import 'merchant_earnings_screen.dart';
import 'merchant_more_screen.dart';
import 'merchant_orders_screen.dart';
import 'merchant_products_screen.dart';

class MerchantShell extends StatefulWidget {
  const MerchantShell({super.key});

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MerchantDashboardScreen(),
    MerchantOrdersScreen(),
    MerchantProductsScreen(),
    MerchantEarningsScreen(),
    MerchantMoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.merchantLabels;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded, color: Colors.deepOrange),
        label: 'الرئيسية',
      ),
      const NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon:
            Icon(Icons.receipt_long_rounded, color: Colors.deepOrange),
        label: 'الطلبات',
      ),
      NavigationDestination(
        icon: const Icon(Icons.inventory_2_outlined),
        selectedIcon:
            const Icon(Icons.inventory_2_rounded, color: Colors.deepOrange),
        label: labels.productsTitleAr,
      ),
      const NavigationDestination(
        icon: Icon(Icons.payments_outlined),
        selectedIcon: Icon(Icons.payments_rounded, color: Colors.deepOrange),
        label: 'الأرباح',
      ),
      const NavigationDestination(
        icon: Icon(Icons.more_horiz_outlined),
        selectedIcon: Icon(Icons.more_horiz_rounded, color: Colors.deepOrange),
        label: 'المزيد',
      ),
    ];

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF101010) : const Color(0xFFF4F4F6),
      body: SafeArea(bottom: false, child: _screens[_currentIndex]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171717) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (value) {
            if (value == 0) {
              provider.resetHome();
            }
            setState(() => _currentIndex = value);
          },
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFFFFE4D4),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: destinations,
        ),
      ),
    );
  }
}
