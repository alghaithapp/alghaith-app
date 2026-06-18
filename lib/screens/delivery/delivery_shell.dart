import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/app_bottom_nav_style.dart';
import '../../core/ui/account_ui.dart';
import '../../providers/app_provider.dart';
import '../../utils/courier_profile_fields.dart';
import 'delivery_earnings_screen.dart';
import 'delivery_setup_screen.dart';
import '../../utils/account_role_switch.dart';
import '../../utils/extensions.dart';
import '../../utils/helpers.dart';
import '../../utils/role_notification_poller.dart';
import '../../widgets/app_image.dart';
import '../../widgets/account/account_page_header.dart';
import '../../utils/role_switch_notifications.dart';
import '../../screens/notifications_screen.dart';
import '../../widgets/safe_bottom_bar.dart';

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
      // فتح تفاصيل الطلب إذا كان هناك orderId معلّق من الإشعار
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
      body = _DeliveryGroupCard(
          group: CourierGroupedOrder(incoming.groupId, [incoming]));
    } else if (active != null) {
      body = _ActiveDeliveryGroupCard(
          group: CourierGroupedOrder(active.groupId, [active]));
    } else if (completed != null) {
      body = _CompletedDeliveryCard(order: completed);
    } else {
      body = _EmptyCard(text: 'Order not found');
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

class CourierGroupedOrder {
  final String? groupId;
  final List<ActiveOrder> orders;
  CourierGroupedOrder(this.groupId, this.orders);

  String get orderNumber => orders.first.orderNumber;
  int get totalPrice => orders.fold(0, (sum, o) => sum + o.price);
  String get customerName => orders.first.customerNameAr;
  String get customerPhone => orders.first.customerPhone;
  String get customerAddress => orders.first.addressAr;
  double? get customerLat => orders.first.customerLatitude;
  double? get customerLng => orders.first.customerLongitude;

  bool get isSingle => orders.length == 1;
  bool get allPickedUp => orders.every((o) =>
      o.deliveryStatusKey == 'picked_up' ||
      o.deliveryStatusKey == 'on_way' ||
      o.deliveryStatusKey == 'delivered');
  bool get isOnWay => orders.any((o) => o.deliveryStatusKey == 'on_way');
  bool get isDelivered =>
      orders.every((o) => o.deliveryStatusKey == 'delivered');
}

extension CourierOrderGrouping on List<ActiveOrder> {
  List<CourierGroupedOrder> groupForCourier() {
    final Map<String, List<ActiveOrder>> grouped = {};
    final List<CourierGroupedOrder> result = [];

    for (final order in this) {
      if (order.groupId != null && order.groupId!.isNotEmpty) {
        grouped.putIfAbsent(order.groupId!, () => []).add(order);
      } else {
        result.add(CourierGroupedOrder(null, [order]));
      }
    }

    for (final entry in grouped.entries) {
      result.add(CourierGroupedOrder(entry.key, entry.value));
    }

    result.sort((a, b) {
      final ta =
          DateTime.tryParse(a.orders.first.createdAt ?? '') ?? DateTime(2000);
      final tb =
          DateTime.tryParse(b.orders.first.createdAt ?? '') ?? DateTime(2000);
      return tb.compareTo(ta);
    });

    return result;
  }
}

class _MapInfoLine extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _MapInfoLine({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class DeliveryDashboardScreen extends StatelessWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final groupedIncoming =
        appProvider.deliveryIncomingOrders.groupForCourier();
    final active = appProvider.deliveryActiveOrders.length;
    final done = appProvider.deliveryCompletedOrders.length;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'لوحة المندوب',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TopCard(
              title: 'مرحبًا ${appProvider.deliveryCourierName}',
              subtitle:
                  'توصيل طلبات المطاعم والتسوق — استلام نقداً عند التسليم',
              icon: Icons.motorcycle,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _StatBox(
                        label: 'جديدة',
                        value: '${groupedIncoming.length}',
                        color: AppColors.accent)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatBox(
                        label: 'نشطة', value: '$active', color: Colors.blue)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatBox(
                        label: 'مكتملة', value: '$done', color: Colors.green)),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const DeliveryEarningsScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF007A7A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'عرض الأرباح — ${appProvider.courierTotalEarnings.toPrice()} د.ع',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_left,
                        color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: 'طلبات مطاعم وتسوق جديدة'),
            const SizedBox(height: 10),
            if (groupedIncoming.isEmpty)
              _EmptyCard(
                text: 'لا توجد طلبات جديدة من المطاعم أو التسوق الآن',
              )
            else
              ...groupedIncoming
                  .take(3)
                  .map((group) => _DeliveryGroupCard(group: group)),
          ],
        ),
      ),
    );
  }
}

class DeliveryRequestsScreen extends StatelessWidget {
  const DeliveryRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final grouped = appProvider.deliveryIncomingOrders.groupForCourier();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'الطلبات الواردة',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => appProvider.refreshCourierOrders(),
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
        border: null,
      ),
      child: SafeArea(
        child: grouped.isEmpty
            ? _EmptyCard(
                text: 'لا توجد طلبات جاهزة للتوصيل حالياً',
              )
            : RefreshIndicator(
                onRefresh: appProvider.refreshCourierOrders,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    return _DeliveryGroupCard(group: grouped[index]);
                  },
                ),
              ),
      ),
    );
  }
}

class DeliveryActiveScreen extends StatelessWidget {
  const DeliveryActiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final grouped = appProvider.deliveryActiveOrders.groupForCourier();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'الطلبات النشطة',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => appProvider.refreshCourierOrders(),
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
        border: null,
      ),
      child: SafeArea(
        child: grouped.isEmpty
            ? _EmptyCard(
                text: 'لا توجد طلبات نشطة حالياً',
              )
            : RefreshIndicator(
                onRefresh: appProvider.refreshCourierOrders,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    return _ActiveDeliveryGroupCard(group: grouped[index]);
                  },
                ),
              ),
      ),
    );
  }
}

class DeliveryCompletedScreen extends StatelessWidget {
  const DeliveryCompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final orders = appProvider.deliveryCompletedOrders;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'الطلبات المكتملة',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => appProvider.refreshCourierOrders(),
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
        border: null,
      ),
      child: SafeArea(
        child: orders.isEmpty
            ? _EmptyCard(
                text: 'لا توجد طلبات مكتملة بعد',
              )
            : RefreshIndicator(
                onRefresh: appProvider.refreshCourierOrders,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const DeliveryEarningsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007A7A),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.payments_rounded,
                                color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'إجمالي الأرباح: ${appProvider.courierTotalEarnings.toPrice()} د.ع',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Icon(CupertinoIcons.chevron_left,
                                color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                    ...orders.map(
                      (order) => _CompletedDeliveryCard(order: order),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CompletedDeliveryCard extends StatelessWidget {
  final ActiveOrder order;

  const _CompletedDeliveryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.checkmark_seal_fill,
                  color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طلب #${order.orderNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              Text(
                '${order.price.toPrice()} د.ع',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          if ((order.merchantStoreName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'المتجر: ${order.merchantStoreName}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            order.itemsNameAr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            order.addressAr,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          if (order.deliveredAt != null && order.deliveredAt!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'تم التسليم: ${order.deliveredAt}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DeliveryAccountScreen extends StatelessWidget {
  const DeliveryAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final profile = appProvider.courierProfile ?? const {};
    final isAvailable = appProvider.isCourierAvailable;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            AccountPageHeader(
              notificationCount: appProvider.unreadNotificationCount,
              title: 'حساب المندوب',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: AccountUi.cardDecoration(radius: 22),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CourierProfileFields.profileImage(profile)
                                    .isNotEmpty
                                ? AppImage(
                                    imageData:
                                        CourierProfileFields.profileImage(
                                            profile),
                                    fit: BoxFit.cover,
                                  )
                                : Icon(Icons.motorcycle,
                                    size: 38, color: Colors.orange.shade700),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appProvider.deliveryCourierName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'توصيل طلبات المطاعم والتسوق',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _EditProfileButton(
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => const DeliverySetupScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: AccountUi.cardDecoration(radius: 22),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: isAvailable,
                          onChanged: appProvider.setCourierAvailability,
                          activeThumbColor: Colors.white,
                          activeTrackColor: Colors.green,
                          inactiveTrackColor: Colors.red.shade100,
                          tileColor: Colors.white,
                          title: Text(
                            'حالة التوفر',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            isAvailable
                                ? 'متاح لاستلام الطلبات الآن'
                                : 'غير متاح لاستلام طلبات جديدة',
                            style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'النشاط والإحصائيات'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'الجديدة',
                          value: '${appProvider.deliveryIncomingOrders.length}',
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'نشطة',
                          value: '${appProvider.deliveryActiveOrders.length}',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'المكتملة',
                          value:
                              '${appProvider.deliveryCompletedOrders.length}',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _NavigationCard(
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFF007A7A),
                    title: 'شاشة الأرباح',
                    subtitle: 'عرض تفاصيل الأرباح اليومية والأسبوعية',
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const DeliveryEarningsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _NavigationCard(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: const Color(0xFFE040FB),
                    title: 'تبديل الحساب (الدور)',
                    subtitle: 'الانتقال إلى واجهة الزبون أو التاجر أو المندوب',
                    onTap: () => showRoleSwitcher(context, appProvider),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: 'بيانات السكن والوثائق'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: AccountUi.cardDecoration(radius: 22),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _InfoTile(
                          label: 'عنوان السكن',
                          value: CourierProfileFields.homeAddress(profile)
                                  .isNotEmpty
                              ? CourierProfileFields.homeAddress(profile)
                              : '—',
                        ),
                        _InfoTile(
                          label: 'اسم المختار',
                          value: CourierProfileFields.mukhtarName(profile)
                                  .isNotEmpty
                              ? CourierProfileFields.mukhtarName(profile)
                              : '—',
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'صور الوثائق والدراجة'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (CourierProfileFields.vehicleImage(profile)
                            .isNotEmpty)
                          _docPreview(
                              CourierProfileFields.vehicleImage(profile),
                              'الدراجة'),
                        if (CourierProfileFields.residenceCardImage(profile)
                            .isNotEmpty)
                          _docPreview(
                              CourierProfileFields.residenceCardImage(profile),
                              'بطاقة السكن'),
                        if (CourierProfileFields.idFrontImage(profile)
                            .isNotEmpty)
                          _docPreview(
                              CourierProfileFields.idFrontImage(profile),
                              'الموحدة (1)'),
                        if (CourierProfileFields.idBackImage(profile)
                            .isNotEmpty)
                          _docPreview(CourierProfileFields.idBackImage(profile),
                              'الموحدة (2)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _LogoutCard(onTap: () => appProvider.resetAll()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docPreview(String ref, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AppImage(
              imageData: ref,
              width: 100,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: AccountUi.cardDecoration(radius: 20),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EditProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: AccountUi.brandGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.pencil, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              const Text(
                'تعديل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavigationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: AccountUi.cardDecoration(radius: 22),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_left,
                size: 16,
                color: Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.power,
                  color: CupertinoColors.systemRed,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.systemRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const _InfoTile({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: CupertinoColors.systemGrey6.withValues(alpha: 0.9),
                ),
              )
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TopCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, Colors.grey.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.grey, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontFamily: 'Cairo',
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}

class _DeliveryGroupCard extends StatelessWidget {
  final CourierGroupedOrder group;

  const _DeliveryGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final count = group.orders.length;
    final isGroup = !group.isSingle;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  isGroup
                      ? CupertinoIcons.square_grid_2x2_fill
                      : CupertinoIcons.bag_fill,
                  color: AppColors.accent,
                  size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isGroup
                      ? 'مجموعة طلبات ($count)'
                      : 'طلب #${group.orderNumber}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Cairo',
                      fontSize: 18),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'COD',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...group.orders.map((order) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.store, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${order.merchantStoreName ?? 'متجر'} · ${order.itemsNameAr}',
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(CupertinoIcons.location_solid,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  group.customerAddress,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إجمالي المطلوب تحصيله:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),
              Text(
                '${group.totalPrice.toPrice()} د.ع',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => group.groupId != null
                      ? appProvider.rejectDeliveryGroup(group.groupId!)
                      : appProvider.rejectDeliveryOrder(group.orders.first.id),
                  child: const Text('رفض',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => group.groupId != null
                      ? appProvider.acceptDeliveryGroup(group.groupId!)
                      : appProvider.acceptDeliveryOrder(group.orders.first.id),
                  child: const Text('قبول المجموعة وتوصيلها',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveDeliveryGroupCard extends StatelessWidget {
  final CourierGroupedOrder group;

  const _ActiveDeliveryGroupCard({required this.group});

  void _openMapToMerchant(BuildContext context, ActiveOrder order) {
    if (order.merchantLatitude != null && order.merchantLongitude != null) {
      AppHelpers.openExternalMapNavigation(
        latitude: order.merchantLatitude!,
        longitude: order.merchantLongitude!,
        travelMode: 'driving',
        context: context,
      );
    }
  }

  void _openMapToCustomer(BuildContext context) {
    if (group.customerLat != null && group.customerLng != null) {
      AppHelpers.openExternalMapNavigation(
        latitude: group.customerLat!,
        longitude: group.customerLng!,
        travelMode: 'driving',
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final allPicked = group.allPickedUp;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupHeader(),
          const SizedBox(height: 16),
          if (!allPicked) ...[
            const Text(
              'مرحلة التجميع (Pick-up):',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            ...group.orders
                .map((order) => _buildPickupStep(context, order, appProvider)),
          ] else ...[
            _buildDeliveryToCustomerSection(context, appProvider),
          ],
          const Divider(height: 32),
          _buildFooterInfo(),
        ],
      ),
    );
  }

  Widget _buildGroupHeader() {
    final allPicked = group.allPickedUp;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (allPicked ? Colors.blue : AppColors.accent)
                .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            allPicked ? Icons.local_shipping : Icons.store_mall_directory,
            color: allPicked ? Colors.blue : AppColors.accent,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                allPicked ? 'في الطريق للزبون' : 'جاري تجميع الطلبات',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 16),
              ),
              Text(
                'مجموعة #${group.orderNumber}',
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPickupStep(
      BuildContext context, ActiveOrder order, AppProvider provider) {
    final picked = order.deliveryStatusKey == 'picked_up' ||
        order.deliveryStatusKey == 'on_way' ||
        order.deliveryStatusKey == 'delivered';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: picked
            ? Colors.green.withValues(alpha: 0.03)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: picked
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(picked ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: picked ? Colors.green : Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.merchantStoreName ?? 'متجر',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        decoration: picked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(order.itemsNameAr,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Colors.grey)),
                  ],
                ),
              ),
              if (!picked)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      AppHelpers.makePhoneCall(order.merchantPhone ?? ''),
                  child: const Icon(CupertinoIcons.phone_fill, size: 20),
                ),
            ],
          ),
          if (!picked) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.blueGrey.shade700,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () => _openMapToMerchant(context, order),
                    child: const Text('موقع المتجر',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () => provider.markDeliveryPickedUp(order.id),
                    child: const Text('تم الاستلام',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryToCustomerSection(
      BuildContext context, AppProvider provider) {
    final onWay = group.isOnWay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مرحلة التسليم للزبون:',
          style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: Colors.blue),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.person_fill, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.customerName,
                      style: const TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        AppHelpers.makePhoneCall(group.customerPhone),
                    child: const Icon(CupertinoIcons.phone_fill, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(CupertinoIcons.location_solid,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(group.customerAddress,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Colors.grey)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!onWay)
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () =>
                        provider.markDeliveryOnTheWay(group.orders.first.id),
                    child: const Text('بدء التحرك للزبون',
                        style: TextStyle(
                            fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        color: Colors.black87,
                        padding: EdgeInsets.zero,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () => _openMapToCustomer(context),
                        child: const Text('خرائط الزبون',
                            style:
                                TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: CupertinoButton(
                        color: Colors.green,
                        padding: EdgeInsets.zero,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () => provider
                            .markDeliveryCompleted(group.orders.first.id),
                        child: const Text('تسليم وتحصيل الكاش',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'المبلغ الإجمالي للتحصيل:',
          style:
              TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey),
        ),
        Text(
          '${group.totalPrice.toPrice()} د.ع',
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: Colors.green),
        ),
      ],
    );
  }
}

class _DeliveryMapPreviewScreen extends StatefulWidget {
  final ActiveOrder order;

  const _DeliveryMapPreviewScreen({required this.order});

  @override
  State<_DeliveryMapPreviewScreen> createState() =>
      _DeliveryMapPreviewScreenState();
}

class _DeliveryMapPreviewScreenState extends State<_DeliveryMapPreviewScreen> {
  LatLng? _courierPosition;

  LatLng? get _customerPosition {
    final lat = widget.order.customerLatitude;
    final lng = widget.order.customerLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? get _merchantPosition {
    final lat = widget.order.merchantLatitude;
    final lng = widget.order.merchantLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng get _initialPosition =>
      _merchantPosition ?? _customerPosition ?? const LatLng(33.3152, 44.3661);

  void _onMapReady() {
    unawaited(_loadCourierPosition());
  }

  Future<void> _loadCourierPosition() async {
    final enabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!enabled) return;
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      return;
    }
    final current = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
      ),
    );
    setState(() {
      _courierPosition = LatLng(current.latitude, current.longitude);
    });
  }

  VoidCallback? _externalNavigationAction() {
    final customerLat = widget.order.customerLatitude;
    final customerLng = widget.order.customerLongitude;
    final merchantLat = widget.order.merchantLatitude;
    final merchantLng = widget.order.merchantLongitude;
    final statusKey = widget.order.deliveryStatusKey ?? '';
    final courierLat = _courierPosition?.latitude;
    final courierLng = _courierPosition?.longitude;

    if (statusKey == 'accepted' && merchantLat != null && merchantLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: merchantLat,
            longitude: merchantLng,
            originLatitude: courierLat,
            originLongitude: courierLng,
            travelMode: 'walking',
          );
    }

    if (const {'picked_up', 'on_way'}.contains(statusKey) &&
        customerLat != null &&
        customerLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: customerLat,
            longitude: customerLng,
            originLatitude: courierLat,
            originLongitude: courierLng,
            travelMode: 'walking',
          );
    }

    if (merchantLat != null &&
        merchantLng != null &&
        customerLat != null &&
        customerLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: customerLat,
            longitude: customerLng,
            originLatitude: merchantLat,
            originLongitude: merchantLng,
            travelMode: 'walking',
          );
    }

    if (customerLat != null && customerLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: customerLat,
            longitude: customerLng,
            originLatitude: courierLat,
            originLongitude: courierLng,
            travelMode: 'walking',
          );
    }

    if (merchantLat != null && merchantLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: merchantLat,
            longitude: merchantLng,
            travelMode: 'walking',
          );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final customerLat = widget.order.customerLatitude;
    final customerLng = widget.order.customerLongitude;
    final merchantLat = widget.order.merchantLatitude;
    final merchantLng = widget.order.merchantLongitude;
    final hasCustomer = customerLat != null && customerLng != null;
    final hasMerchant = merchantLat != null && merchantLng != null;
    if (!hasCustomer && !hasMerchant) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('الخريطة'),
        ),
        child: const SafeArea(
          child: Center(
            child: Text(
              'هذا الطلب لا يحتوي إحداثيات موقع.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'خريطة التوصيل',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _externalNavigationAction(),
          child: const Text(
            'فتح الخرائط',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _initialPosition,
                  initialZoom: 14.8,
                  onMapReady: _onMapReady,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      if (_merchantPosition != null)
                        Marker(
                          point: _merchantPosition!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            width: 18,
                            height: 18,
                          ),
                        ),
                      if (_customerPosition != null)
                        Marker(
                          point: _customerPosition!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5A01D),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            width: 18,
                            height: 18,
                          ),
                        ),
                      if (_courierPosition != null)
                        Marker(
                          point: _courierPosition!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            width: 16,
                            height: 16,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasMerchant)
                    _MapInfoLine(
                      color: const Color(0xFF1976D2),
                      label: 'المتجر',
                      value:
                          '${widget.order.merchantStoreName ?? '-'} · ${merchantLat.toStringAsFixed(5)}, ${merchantLng.toStringAsFixed(5)}',
                    ),
                  if (hasCustomer) ...[
                    const SizedBox(height: 6),
                    _MapInfoLine(
                      color: const Color(0xFFF5A01D),
                      label: 'الزبون',
                      value:
                          '${widget.order.addressAr} · ${customerLat.toStringAsFixed(5)}, ${customerLng.toStringAsFixed(5)}',
                    ),
                  ],
                  if (_courierPosition != null) ...[
                    const SizedBox(height: 6),
                    const _MapInfoLine(
                      color: Color(0xFF2E7D32),
                      label: 'موقعك',
                      value: 'موقع المندوب الحالي',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
