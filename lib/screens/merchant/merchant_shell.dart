import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../utils/merchant_service_labels.dart';
import '../../utils/role_switch_notifications.dart';
import '../../widgets/in_app_notification_banner.dart';
import '../../widgets/safe_bottom_bar.dart';
import 'merchant_dashboard_screen.dart';
import 'merchant_earnings_screen.dart';
import 'merchant_more_screen.dart';
import 'merchant_orders_screen.dart';
import 'merchant_products_screen.dart';
import 'order_details_screen.dart';

class MerchantShell extends StatefulWidget {
  const MerchantShell({super.key});

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _refreshTimer;
  bool _isInBackground = false;
  // تتبع حالة كل طلب لاكتشاف التغييرات
  Map<String, String> _lastOrderStatuses = {};
  bool _bannerShowing = false;
  // قائمة الإشعارات المنتظرة (تُعرض واحداً تلو الآخر)
  final List<_BannerData> _pendingBanners = [];
  String? _lastActiveServiceId;

  bool _contactOnlyFor(AppProvider provider) =>
      !merchantServiceUsesOrderFlow(provider.merchantActiveServiceId);

  bool _isTabEnabled(AppProvider provider, int index) {
    if (!_contactOnlyFor(provider)) return true;
    return index != 1 && index != 3;
  }

  int _mapPendingTab(AppProvider provider, int tab) {
    if (!_contactOnlyFor(provider)) return tab;
    if (tab == 1 || tab == 3) return 0;
    return tab;
  }

  Widget _screenForIndex(AppProvider provider, int index) {
    if (!_isTabEnabled(provider, index)) {
      return const MerchantDashboardScreen();
    }
    switch (index) {
      case 0:
        return const MerchantDashboardScreen();
      case 1:
        return MerchantOrdersScreen(
          onNavigateHome: () => setState(() => _currentIndex = 0),
        );
      case 2:
        return const MerchantProductsScreen();
      case 3:
        return const MerchantEarningsScreen();
      case 4:
        return const MerchantMoreScreen();
      default:
        return const MerchantDashboardScreen();
    }
  }

  static const _disabledNavColor = Color(0xFFBDBDBD);

  NavigationDestination _ordersDestination(
    AppProvider provider, {
    required bool enabled,
  }) {
    final pending = provider.merchantPendingOrdersCount;
    final icon = Icon(
      Icons.receipt_long_outlined,
      color: enabled ? null : _disabledNavColor,
    );
    final selectedIcon = Icon(
      Icons.receipt_long_rounded,
      color: enabled ? AppColors.accent : _disabledNavColor,
    );
    return NavigationDestination(
      icon: enabled && pending > 0
          ? Badge(label: Text('$pending'), child: icon)
          : icon,
      selectedIcon: enabled && pending > 0
          ? Badge(label: Text('$pending'), child: selectedIcon)
          : selectedIcon,
      label: 'الطلبات',
      enabled: enabled,
    );
  }

  NavigationDestination _earningsDestination({required bool enabled}) {
    return NavigationDestination(
      icon: Icon(
        Icons.payments_outlined,
        color: enabled ? null : _disabledNavColor,
      ),
      selectedIcon: Icon(
        Icons.payments_rounded,
        color: enabled ? AppColors.accent : _disabledNavColor,
      ),
      label: 'الأرباح',
      enabled: enabled,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AppProvider>().addListener(_onAppProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final provider = context.read<AppProvider>();
      // حفظ الحالات الأولية لجميع الطلبات
      _lastOrderStatuses = {
        for (final o in provider.merchantIncomingOrders) o.id: o.statusKey,
      };
      _lastActiveServiceId = provider.merchantActiveServiceId;
      if (!_contactOnlyFor(provider)) {
        provider.refreshMerchantIncomingOrders();
      }
      provider.syncMerchantCatalogToCloud().catchError((error) {
        debugPrint('MERCHANT_CLOUD_SYNC: $error');
      });
      // استطلاع دوري كل 10 ثوانٍ (بدون Realtime — يوفر حصة Supabase)
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_isInBackground) return;
        _pollForNewOrders();
      });
      RoleSwitchNotificationPresenter.showIfNeeded(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isInBackground = state == AppLifecycleState.paused || state == AppLifecycleState.inactive;
    if (_isInBackground) {
      _refreshTimer?.cancel();
    } else if (_refreshTimer == null || !_refreshTimer!.isActive) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollForNewOrders());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<AppProvider>().removeListener(_onAppProviderChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onAppProviderChanged() {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final activeId = provider.merchantActiveServiceId;
    if (_lastActiveServiceId != activeId) {
      _lastActiveServiceId = activeId;
      if (_contactOnlyFor(provider) &&
          (_currentIndex == 1 || _currentIndex == 3)) {
        setState(() => _currentIndex = 0);
      }
    }
    final tab = provider.takePendingMerchantTab();
    if (tab != null) {
      final mapped = _mapPendingTab(provider, tab);
      final nextIndex = mapped.clamp(0, 4);
      if (nextIndex != _currentIndex) {
        setState(() => _currentIndex = nextIndex);
      }
    }
    // فتح تفاصيل الطلب إذا كان هناك orderId معلّق من الإشعار
    final orderId = provider.takePendingOrderId('merchant');
    if (orderId != null && orderId.isNotEmpty && !_contactOnlyFor(provider)) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final updatedProvider = context.read<AppProvider>();
        final order = updatedProvider.merchantIncomingOrders
            .where((o) => o.id == orderId)
            .firstOrNull;
        if (order == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(order: order),
          ),
        );
      });
    }
  }

  Future<void> _pollForNewOrders() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    if (_contactOnlyFor(provider)) return;
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
    final labels = provider.merchantActiveLabels;
    final purchaseTabsEnabled = !_contactOnlyFor(provider);
    var safeIndex = _currentIndex.clamp(0, 4);
    if (!purchaseTabsEnabled && (safeIndex == 1 || safeIndex == 3)) {
      safeIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_currentIndex == 1 || _currentIndex == 3) {
          setState(() => _currentIndex = 0);
        }
      });
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: ValueKey('merchant-shell-${provider.merchantActiveServiceId}'),
      backgroundColor:
          isDark ? const Color(0xFF101010) : const Color(0xFFF2F2F7),
      body: SafeArea(
        bottom: false,
        child: _screenForIndex(provider, safeIndex),
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
          selectedIndex: safeIndex,
          onDestinationSelected: (value) {
            if (!_isTabEnabled(provider, value)) return;
            if (value == 0) {
              provider.resetHome();
            }
            setState(() => _currentIndex = value);
          },
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFFFFE4D4),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon:
                  Icon(Icons.dashboard_rounded, color: AppColors.accent),
              label: 'الرئيسية',
            ),
            _ordersDestination(provider, enabled: purchaseTabsEnabled),
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2_rounded,
                  color: AppColors.accent),
              label: labels.productsTitleAr,
            ),
            _earningsDestination(enabled: purchaseTabsEnabled),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon:
                  Icon(Icons.more_horiz_rounded, color: AppColors.accent),
              label: 'المزيد',
            ),
          ],
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
