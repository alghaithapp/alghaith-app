import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../utils/role_switch_notifications.dart';
import '../../widgets/in_app_notification_banner.dart';
import '../../widgets/safe_bottom_bar.dart';
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
  Timer? _refreshTimer;
  // تتبع حالة كل طلب لاكتشاف التغييرات
  Map<String, String> _lastOrderStatuses = {};
  bool _bannerShowing = false;
  // قائمة الإشعارات المنتظرة (تُعرض واحداً تلو الآخر)
  final List<_BannerData> _pendingBanners = [];

  late final List<Widget> _screens = [
    const MerchantDashboardScreen(),
    MerchantOrdersScreen(onNavigateHome: () => setState(() => _currentIndex = 0)),
    const MerchantProductsScreen(),
    const MerchantEarningsScreen(),
    const MerchantMoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final provider = context.read<AppProvider>();
      // حفظ الحالات الأولية لجميع الطلبات
      _lastOrderStatuses = {
        for (final o in provider.merchantIncomingOrders) o.id: o.statusKey,
      };
      provider.refreshMerchantIncomingOrders();
      provider.syncMerchantCatalogToCloud().catchError((error) {
        debugPrint('MERCHANT_CLOUD_SYNC: $error');
      });
      // استطلاع دوري كل 20 ثانية
      _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _pollForNewOrders();
      });
      RoleSwitchNotificationPresenter.showIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollForNewOrders() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.refreshMerchantIncomingOrders();
    if (!mounted) return;
    provider.tickMerchantNotificationTimers();

    final orders = provider.merchantIncomingOrders;

    for (final order in orders) {
      final prevStatus = _lastOrderStatuses[order.id];

      // طلب جديد لم يكن موجوداً من قبل
      if (prevStatus == null && order.statusKey == 'pending') {
        _enqueueBanner(_BannerData(
          type: _BannerType.newOrder,
          title: 'طلب جديد وصلك!',
          body: order.itemsNameAr.isNotEmpty
              ? order.itemsNameAr
              : 'اضغط لمراجعة الطلب',
          orderNumber: order.orderNumber,
        ));
      }

      // طلب إلغاء من الزبون
      if (prevStatus != null &&
          prevStatus != 'cancel_requested' &&
          order.statusKey == 'cancel_requested') {
        _enqueueBanner(_BannerData(
          type: _BannerType.cancelRequest,
          title: 'طلب إلغاء ${order.orderNumber}',
          body: 'الزبون يطلب إلغاء طلبه — اتخذ قراراً',
          orderNumber: order.orderNumber,
        ));
      }

      // طلب أُلغي تلقائياً بسبب انتهاء المهلة
      if (prevStatus != null &&
          prevStatus == 'pending' &&
          order.statusKey == 'cancelled' &&
          (order.noteAr.contains('مهلة') || order.noteEn.contains('timeout'))) {
        _enqueueBanner(_BannerData(
          type: _BannerType.timeout,
          title: 'انتهت مهلة الطلب ${order.orderNumber}',
          body: 'لم يُقبل الطلب خلال 20 دقيقة وأُلغي تلقائياً',
          orderNumber: order.orderNumber,
        ));
      }
    }

    _lastOrderStatuses = {for (final o in orders) o.id: o.statusKey};

    if (provider.inAppAlertsEnabled) {
      _showNextBanner();
    } else {
      _pendingBanners.clear();
    }
  }

  void _enqueueBanner(_BannerData data) {
    _pendingBanners.add(data);
  }

  Future<void> _showNextBanner() async {
    if (_bannerShowing || !mounted) return;
    final provider = context.read<AppProvider>();
    if (!provider.inAppAlertsEnabled) {
      _pendingBanners.clear();
      return;
    }
    if (_pendingBanners.isEmpty) return;

    _bannerShowing = true;
    while (mounted && _pendingBanners.isNotEmpty) {
      if (!context.read<AppProvider>().inAppAlertsEnabled) {
        _pendingBanners.clear();
        break;
      }
      final data = _pendingBanners.removeAt(0);
      final tapped = await showInAppNotificationBanner(
        context: context,
        title: data.title,
        body: data.body,
        accentColor: _bannerAccent(data.type),
        icon: _bannerIcon(data.type),
        autoHide: const Duration(seconds: 4),
      );
      if (!mounted) break;
      if (tapped) {
        context
            .read<AppProvider>()
            .markNotificationsReadForOrder(data.orderNumber, 'merchant');
        setState(() => _currentIndex = 1);
      }
    }
    _bannerShowing = false;
  }

  Color _bannerAccent(_BannerType type) {
    switch (type) {
      case _BannerType.newOrder:
        return const Color(0xFFFF6B00);
      case _BannerType.cancelRequest:
        return const Color(0xFFD32F2F);
      case _BannerType.timeout:
        return const Color(0xFF455A64);
    }
  }

  IconData _bannerIcon(_BannerType type) {
    switch (type) {
      case _BannerType.newOrder:
        return Icons.shopping_bag_rounded;
      case _BannerType.cancelRequest:
        return Icons.cancel_rounded;
      case _BannerType.timeout:
        return Icons.timer_off_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.merchantLabels;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.accent),
        label: 'الرئيسية',
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: provider.merchantPendingOrdersCount > 0,
          label: Text('${provider.merchantPendingOrdersCount}'),
          child: const Icon(Icons.receipt_long_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: provider.merchantPendingOrdersCount > 0,
          label: Text('${provider.merchantPendingOrdersCount}'),
          child: const Icon(Icons.receipt_long_rounded, color: AppColors.accent),
        ),
        label: 'الطلبات',
      ),
      NavigationDestination(
        icon: const Icon(Icons.inventory_2_outlined),
        selectedIcon:
            const Icon(Icons.inventory_2_rounded, color: AppColors.accent),
        label: labels.productsTitleAr,
      ),
      const NavigationDestination(
        icon: Icon(Icons.payments_outlined),
        selectedIcon: Icon(Icons.payments_rounded, color: AppColors.accent),
        label: 'الأرباح',
      ),
      const NavigationDestination(
        icon: Icon(Icons.more_horiz_outlined),
        selectedIcon: Icon(Icons.more_horiz_rounded, color: AppColors.accent),
        label: 'المزيد',
      ),
    ];

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF101010) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: SafeBottomBar(
        color: isDark ? const Color(0xFF171717) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
        topPadding: 0,
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

// ─────────────────────────────────────────────
// نموذج بيانات البانر
// ─────────────────────────────────────────────
enum _BannerType { newOrder, cancelRequest, timeout }

class _BannerData {
  final _BannerType type;
  final String title;
  final String body;
  final String orderNumber;

  const _BannerData({
    required this.type,
    required this.title,
    required this.body,
    required this.orderNumber,
  });
}
