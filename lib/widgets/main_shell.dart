import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../core/theme/app_colors.dart';
import '../core/ui/app_bottom_nav_style.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../screens/home_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/account_screen.dart';
import '../screens/favorites_screen.dart';
import '../utils/role_switch_notifications.dart';
import 'customer_order_notifications.dart';
import 'safe_bottom_bar.dart';
import 'order_tracking_sheet.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
  Timer? _orderRefreshTimer;
  Map<String, CustomerOrderSnapshot> _lastOrderSnapshots = {};
  OverlayEntry? _notificationEntry;
  final List<CustomerBannerData> _pendingBanners = [];
  late final AppProvider _appProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appProvider = context.read<AppProvider>();
    _appProvider.addListener(_onAppProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final provider = context.read<AppProvider>();
      _lastOrderSnapshots = {
        for (final order in provider.orders)
          order.id: CustomerOrderSnapshot(
            statusKey: order.statusKey,
            deliveryStatusKey: order.deliveryStatusKey,
          ),
      };
      provider.refreshCustomerOrders();
      _orderRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _pollCustomerOrders();
      });
      RoleSwitchNotificationPresenter.showIfNeeded(context);
      _openPendingOrderDetail();
    });
  }

  @override
  void dispose() {
    _appProvider.removeListener(_onAppProviderChanged);
    WidgetsBinding.instance.removeObserver(this);
    _orderRefreshTimer?.cancel();
    _notificationEntry?.remove();
    super.dispose();
  }

  void _onAppProviderChanged() {
    if (!mounted) return;
    final tab = _appProvider.takePendingMainTab();
    if (tab == null) return;
    final clamped = tab.clamp(0, 4);
    if (_currentIndex != clamped) {
      setState(() => _currentIndex = clamped);
    }
  }

  Widget _buildHomeTab() {
    return Navigator(
      key: _homeNavigatorKey,
      onGenerateRoute: (settings) {
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) {
            if (settings.name == '/') {
              return const HomeScreen();
            }
            return const HomeScreen();
          },
        );
      },
    );
  }

  Future<void> _pollCustomerOrders() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.refreshCustomerOrders();
    if (!mounted) return;
    provider.tickCustomerNotificationTimers();

    for (final order in provider.orders) {
      final previous = _lastOrderSnapshots[order.id];
      final banner = detectCustomerOrderBanner(
        order: order,
        previous: previous,
      );
      if (banner != null && provider.inAppAlertsEnabled) {
        _pendingBanners.add(banner);
      }
    }

    _lastOrderSnapshots = {
      for (final order in provider.orders)
        order.id: CustomerOrderSnapshot(
          statusKey: order.statusKey,
          deliveryStatusKey: order.deliveryStatusKey,
        ),
    };

    if (provider.inAppAlertsEnabled) {
      _showNextCustomerBanner();
    } else {
      _pendingBanners.clear();
    }
  }

  void _showNextCustomerBanner() {
    if (!context.read<AppProvider>().inAppAlertsEnabled) {
      _pendingBanners.clear();
      return;
    }
    if (_notificationEntry != null) return;
    if (_pendingBanners.isEmpty) return;
    final data = _pendingBanners.removeAt(0);
    _showCustomerBanner(data);
  }

  void _showCustomerBanner(CustomerBannerData data) {
    if (!context.read<AppProvider>().inAppAlertsEnabled) return;
    _notificationEntry?.remove();
    _notificationEntry = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => CustomerOrderNotificationBanner(
        data: data,
        onTap: () {
          context.read<AppProvider>().markNotificationsReadForOrder(
                data.orderNumber,
                'customer',
              );
          entry.remove();
          _notificationEntry = null;
          setState(() => _currentIndex = 3);
          _showNextCustomerBanner();
        },
        onDismiss: () {
          entry.remove();
          _notificationEntry = null;
          _showNextCustomerBanner();
        },
      ),
    );
    _notificationEntry = entry;
    overlay.insert(entry);
  }

  void _openPendingOrderDetail() {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final orderId = provider.takePendingOrderId('customer');
    if (orderId == null || orderId.isEmpty) return;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final updatedProvider = context.read<AppProvider>();
      final order = updatedProvider.orders.where((o) => o.id == orderId).firstOrNull;
      if (order == null) return;
      showCupertinoModalPopup(
        context: context,
        builder: (context) => OrderTrackingSheet(order: order),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _currentIndex = 0);
      _pollCustomerOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final cartCount = appProvider.cartCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screens = [
      _buildHomeTab(),
      const FavoritesScreen(),
      const CartScreen(),
      const OrdersScreen(),
      const AccountScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex == 0) {
          final canPop = await _homeNavigatorKey.currentState?.maybePop() ?? false;
          if (canPop) return;
        } else {
          setState(() => _currentIndex = 0);
          return;
        }
        final shouldExit = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black54,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              surfaceTintColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'تأكيد الخروج',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
              content: const Text(
                'هل تريد الخروج من تطبيق الغيث؟',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
              actionsAlignment: MainAxisAlignment.start,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'خروج',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
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
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, CupertinoIcons.house_fill, 'الرئيسية'),
                  _buildNavItem(1, CupertinoIcons.heart_fill, 'المفضلة'),
                  _buildSpecialCartItemCompact(
                      2, CupertinoIcons.shopping_cart, cartCount),
                  _buildNavItem(3, CupertinoIcons.doc_text_fill, 'طلباتي',
                      badgeCount: appProvider.customerActiveOrdersCount),
                  _buildNavItem(4, CupertinoIcons.person_fill, 'حسابي'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label,
      {int badgeCount = 0}) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    bool isActive = _currentIndex == index;
    final iconWidget = badgeCount > 0
        ? Badge(
            label: Text('$badgeCount'),
            child: Icon(icon,
                color: isActive
                    ? AppBottomNavStyle.activeColor
                    : CupertinoColors.systemGrey,
                size: 34),
          )
        : Icon(icon,
            color: isActive
                ? AppBottomNavStyle.activeColor
                : CupertinoColors.systemGrey,
            size: 34);
    return GestureDetector(
      onTap: () {
        if (index == 0) {
          appProvider.resetHome();
          _homeNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isActive
              ? FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: iconWidget)
              : iconWidget,
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? AppBottomNavStyle.activeColor
                    : CupertinoColors.systemGrey,
                fontFamily: 'Cairo'),
          )
        ],
      ),
    );
  }

  Widget _buildSpecialCartItemCompact(int index, IconData icon, int count) {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -4),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: AppBottomNavStyle.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.28),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(icon, color: Colors.white, size: 27),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
