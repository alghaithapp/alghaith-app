import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_bottom_nav_style.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/role_notification_poller.dart';
import '../../utils/role_switch_notifications.dart';
import '../../widgets/safe_bottom_bar.dart';
import 'delivery_dashboard_screen.dart';
import 'delivery_requests_screen.dart';
import 'delivery_active_screen.dart';
import 'delivery_completed_screen.dart';
import 'delivery_account_screen.dart';
import 'delivery_shared_widgets.dart';

class DeliveryShell extends StatefulWidget {
  const DeliveryShell({super.key});

  @override
  State<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends State<DeliveryShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DeliveryDashboardScreen(),
    DeliveryRequestsScreen(),
    DeliveryActiveScreen(),
    DeliveryCompletedScreen(),
    DeliveryAccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      RoleSwitchNotificationPresenter.showIfNeeded(context);
      final provider = context.read<AppProvider>();
      final orderId = provider.takePendingOrderId('delivery');
      if (orderId != null && orderId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DeliveryOrderDetailsScreen(orderId: orderId),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RoleNotificationPoller(
      role: 'delivery',
      interval: const Duration(seconds: 30),
      onRefresh: (provider) => provider.refreshCourierOrders(),
      pollBanners: (provider) => provider.pollCourierBanners(),
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
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          child: SizedBox(
            height: 108,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, CupertinoIcons.graph_square_fill, 'الرئيسية'),
                _navItem(1, CupertinoIcons.bell_fill, 'الطلبات'),
                _navItem(2, Icons.motorcycle, 'نشطة'),
                _navItem(3, CupertinoIcons.checkmark_seal_fill, 'مكتملة'),
                _navItem(4, CupertinoIcons.person_fill, 'الحساب'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive
                    ? AppBottomNavStyle.activeColor
                    : CupertinoColors.systemGrey,
                size: 44,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? AppBottomNavStyle.activeColor
                      : CupertinoColors.systemGrey,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeliveryOrderDetailsScreen extends StatelessWidget {
  final String orderId;

  const DeliveryOrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final incoming = _findOrder(provider.deliveryIncomingOrders, orderId);
    final active = _findOrder(provider.deliveryActiveOrders, orderId);
    final completed = _findOrder(provider.deliveryCompletedOrders, orderId);

    Widget body;
    if (incoming != null) {
      body = DeliveryGroupCard(
          group: CourierGroupedOrder(incoming.groupId, [incoming]));
    } else if (active != null) {
      body = DeliveryActiveGroupCard(
          group: CourierGroupedOrder(active.groupId, [active]));
    } else if (completed != null) {
      body = DeliveryCompletedCard(order: completed);
    } else {
      body = DeliveryEmptyCard(text: 'Order not found');
    }

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'Order details',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: provider.refreshCourierOrders,
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
        border: null,
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.refreshCourierOrders,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [body],
          ),
        ),
      ),
    );
  }

  ActiveOrder? _findOrder(List<ActiveOrder> orders, String id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }
}
