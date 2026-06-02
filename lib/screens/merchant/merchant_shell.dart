import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
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
  int _lastPendingCount = 0;
  // تتبع حالة كل طلب لاكتشاف التغييرات
  Map<String, String> _lastOrderStatuses = {};
  OverlayEntry? _notificationEntry;
  // قائمة الإشعارات المنتظرة (تُعرض واحداً تلو الآخر)
  final List<_BannerData> _pendingBanners = [];

  final List<Widget> _screens = const [
    MerchantDashboardScreen(),
    MerchantOrdersScreen(),
    MerchantProductsScreen(),
    MerchantEarningsScreen(),
    MerchantMoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      _lastPendingCount = provider.merchantPendingOrdersCount;
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
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notificationEntry?.remove();
    super.dispose();
  }

  Future<void> _pollForNewOrders() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.refreshMerchantIncomingOrders();
    if (!mounted) return;

    final orders = provider.merchantIncomingOrders;
    final newCount = provider.merchantPendingOrdersCount;

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

    _lastPendingCount = newCount;
    _lastOrderStatuses = {for (final o in orders) o.id: o.statusKey};

    _showNextBanner();
  }

  void _enqueueBanner(_BannerData data) {
    _pendingBanners.add(data);
  }

  void _showNextBanner() {
    if (_notificationEntry != null) return; // يوجد بانر يعرض حالياً
    if (_pendingBanners.isEmpty) return;
    final data = _pendingBanners.removeAt(0);
    _showBanner(data);
  }

  void _showBanner(_BannerData data) {
    _notificationEntry?.remove();
    _notificationEntry = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _MerchantNotificationBanner(
        data: data,
        onTap: () {
          entry.remove();
          _notificationEntry = null;
          setState(() => _currentIndex = 1);
          _showNextBanner();
        },
        onDismiss: () {
          entry.remove();
          _notificationEntry = null;
          _showNextBanner();
        },
      ),
    );
    _notificationEntry = entry;
    overlay.insert(entry);
  }

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
      NavigationDestination(
        icon: Badge(
          isLabelVisible: provider.merchantPendingOrdersCount > 0,
          label: Text('${provider.merchantPendingOrdersCount}'),
          child: const Icon(Icons.receipt_long_outlined),
        ),
        selectedIcon: Badge(
          isLabelVisible: provider.merchantPendingOrdersCount > 0,
          label: Text('${provider.merchantPendingOrdersCount}'),
          child: const Icon(Icons.receipt_long_rounded, color: Colors.deepOrange),
        ),
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

// ─────────────────────────────────────────────
// ويدجت البانر الموحد
// ─────────────────────────────────────────────
class _MerchantNotificationBanner extends StatefulWidget {
  final _BannerData data;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _MerchantNotificationBanner({
    required this.data,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_MerchantNotificationBanner> createState() =>
      _MerchantNotificationBannerState();
}

class _MerchantNotificationBannerState
    extends State<_MerchantNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    // طلب إلغاء يبقى أطول (8 ثواني) لأنه يحتاج قراراً
    const seconds = 3;
    _autoHide = Timer(const Duration(seconds: seconds), _dismiss);
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted) return;
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  // ألوان ومؤشرات مختلفة لكل نوع
  List<Color> get _gradientColors {
    switch (widget.data.type) {
      case _BannerType.newOrder:
        return [const Color(0xFFFF6B00), const Color(0xFFFF3D00)];
      case _BannerType.cancelRequest:
        return [const Color(0xFFD32F2F), const Color(0xFFB71C1C)];
      case _BannerType.timeout:
        return [const Color(0xFF455A64), const Color(0xFF263238)];
    }
  }

  Color get _shadowColor {
    switch (widget.data.type) {
      case _BannerType.newOrder:
        return Colors.orange;
      case _BannerType.cancelRequest:
        return Colors.red;
      case _BannerType.timeout:
        return Colors.blueGrey;
    }
  }

  IconData get _icon {
    switch (widget.data.type) {
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
    final top = MediaQuery.of(context).padding.top + 12;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _shadowColor.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.data.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.data.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
