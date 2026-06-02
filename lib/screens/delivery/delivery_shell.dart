import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import 'delivery_earnings_screen.dart';
import 'delivery_setup_screen.dart';
import '../../utils/extensions.dart';
import '../../utils/helpers.dart';
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
      context.read<AppProvider>().refreshCourierOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        child: SizedBox(
          height: 64,
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
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? Colors.orange[800] : CupertinoColors.systemGrey,
              size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.orange[800] : CupertinoColors.systemGrey,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class DeliveryDashboardScreen extends StatelessWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final waiting = appProvider.deliveryIncomingOrders.length;
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
                        value: '$waiting',
                        color: Colors.orange)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatBox(
                        label: 'نشطة',
                        value: '$active',
                        color: Colors.blue)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatBox(
                        label: 'مكتملة',
                        value: '$done',
                        color: Colors.green)),
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
                    const Icon(CupertinoIcons.chevron_left, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: 'طلبات مطاعم وتسوق جديدة'),
            const SizedBox(height: 10),
            if (appProvider.deliveryIncomingOrders.isEmpty)
              _EmptyCard(
                text: 'لا توجد طلبات جديدة من المطاعم أو التسوق الآن',
              )
            else
              ...appProvider.deliveryIncomingOrders
                  .take(3)
                  .map((order) => _DeliveryOrderCard(order: order)),
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
    final orders = appProvider.deliveryIncomingOrders;

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
        child: orders.isEmpty
            ? _EmptyCard(
                text: 'لا توجد طلبات جاهزة للتوصيل حالياً',
              )
            : RefreshIndicator(
                onRefresh: appProvider.refreshCourierOrders,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return _DeliveryOrderCard(order: orders[index]);
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
    final orders = appProvider.deliveryActiveOrders;

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
        child: orders.isEmpty
            ? _EmptyCard(
                text: 'لا توجد طلبات نشطة حالياً',
              )
            : RefreshIndicator(
                onRefresh: appProvider.refreshCourierOrders,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return _ActiveDeliveryCard(order: orders[index]);
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

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'حساب المندوب',
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
              title: appProvider.deliveryCourierName,
              subtitle: 'توصيل طلبات المطاعم والتسوق — دراجة / موتور',
              icon: Icons.motorcycle,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isAvailable
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isAvailable ? 'متاح لاستلام الطلبات' : 'غير متاح حالياً',
                style: TextStyle(
                  color: isAvailable ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: isAvailable,
              onChanged: appProvider.setCourierAvailability,
              activeThumbColor: const Color(0xFF007A7A),
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'التوفر',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                isAvailable
                    ? 'تستقبل طلبات التوصيل الآن'
                    : 'مؤقتًا لا تستقبل طلبات جديدة',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
            const SizedBox(height: 12),
            _InfoTile(
              label: 'الاسم',
              value: '${profile['name'] ?? appProvider.deliveryCourierName}',
            ),
            _InfoTile(
              label: 'الهاتف',
              value: appProvider.courierPhone,
            ),
            _InfoTile(
              label: 'الدراجة',
              value: '${profile['vehicle'] ?? '-'}',
            ),
            _InfoTile(
              label: 'المنطقة',
              value: '${profile['area'] ?? '-'}',
            ),
            if ('${profile['notes'] ?? ''}'.trim().isNotEmpty)
              _InfoTile(
                label: 'ملاحظات',
                value: '${profile['notes']}',
              ),
            _InfoTile(
              label: 'الطلبات الجديدة',
              value: '${appProvider.deliveryIncomingOrders.length}',
            ),
            _InfoTile(
              label: 'الطلبات النشطة',
              value: '${appProvider.deliveryActiveOrders.length}',
            ),
            _InfoTile(
              label: 'الطلبات المكتملة',
              value: '${appProvider.deliveryCompletedOrders.length}',
            ),
            const SizedBox(height: 12),
            CupertinoButton.filled(
              color: Colors.orange.shade800,
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const DeliveryEarningsScreen(),
                  ),
                );
              },
              child: Text(
                'شاشة الأرباح',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
            const SizedBox(height: 10),
            CupertinoButton.filled(
              color: const Color(0xFF007A7A),
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const DeliverySetupScreen(),
                  ),
                );
              },
              child: Text(
                'تعديل الملف',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
            const SizedBox(height: 10),
            CupertinoButton(
              color: Colors.black87,
              onPressed: () => appProvider.resetAll(),
              child: Text(
                'تسجيل الخروج',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryOrderCard extends StatelessWidget {
  final ActiveOrder order;

  const _DeliveryOrderCard({required this.order});

  bool get _hasCustomerLocation =>
      order.customerLatitude != null && order.customerLongitude != null;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.bag_fill,
                  color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طلب #${order.orderNumber}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'دفع عند الاستلام',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          if ((order.merchantStoreName ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'المتجر: ${order.merchantStoreName}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            order.itemsNameAr,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(CupertinoIcons.location_solid,
                  size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.addressAr,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(CupertinoIcons.person_fill,
                  size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                order.customerNameAr,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 0,
                onPressed: () => AppHelpers.makePhoneCall(order.customerPhone),
                child: Text(
                  order.customerPhone,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${order.price.toPrice()} د.ع',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  )),
              Row(
                children: [
                  if (_hasCustomerLocation) ...[
                    CupertinoButton(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      color: Colors.blueGrey,
                      borderRadius: BorderRadius.circular(12),
                      minimumSize: const ui.Size(0, 0),
                      onPressed: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => _DeliveryMapPreviewScreen(order: order),
                        ),
                      ),
                      child: Text('الخريطة',
                          style:
                              const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    minimumSize: const ui.Size(0, 0),
                    onPressed: () => appProvider.rejectDeliveryOrder(order.id),
                    child: Text('رفض',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                    minimumSize: const ui.Size(0, 0),
                    onPressed: () => appProvider.acceptDeliveryOrder(order.id),
                    child: Text('موافقة',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  final ActiveOrder order;

  const _ActiveDeliveryCard({required this.order});

  bool get _hasCustomerLocation =>
      order.customerLatitude != null && order.customerLongitude != null;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final delivered = order.deliveryStatusKey == 'delivered';
    final statusKey = order.deliveryStatusKey ?? '';
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
          Text(
            'طلب #${order.orderNumber}',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 6),
          Text(
            order.deliveryStatusAr ?? 'قيد التوصيل',
            style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 8),
          Text(
            order.addressAr,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${order.price.toPrice()} د.ع — ${order.paymentMethodAr}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (_hasCustomerLocation)
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: const ui.Size(0, 0),
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => _DeliveryMapPreviewScreen(order: order),
                    ),
                  ),
                  child: Text('لوكيشن الزبون',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              if (statusKey == 'accepted')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: const ui.Size(0, 0),
                  onPressed: () => appProvider.markDeliveryPickedUp(order.id),
                  child: Text('استلام من المتجر',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              if (statusKey == 'picked_up')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: const ui.Size(0, 0),
                  onPressed: () => appProvider.markDeliveryOnTheWay(order.id),
                  child: Text('في الطريق',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              if (statusKey == 'on_way')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: const ui.Size(0, 0),
                  onPressed: () => appProvider.markDeliveryCompleted(order.id),
                  child: Text('تم التسليم + كاش',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              if (delivered)
                const Icon(CupertinoIcons.checkmark_seal_fill,
                    color: Colors.green),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeliveryMapPreviewScreen extends StatefulWidget {
  final ActiveOrder order;

  const _DeliveryMapPreviewScreen({required this.order});

  @override
  State<_DeliveryMapPreviewScreen> createState() => _DeliveryMapPreviewScreenState();
}

class _DeliveryMapPreviewScreenState extends State<_DeliveryMapPreviewScreen> {
  MapboxMap? _map;
  CircleAnnotationManager? _circleManager;
  Position? _courierPosition;

  Position get _customerPosition => Position(
        widget.order.customerLongitude!,
        widget.order.customerLatitude!,
      );

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    try {
      _circleManager = await map.annotations.createCircleAnnotationManager();
      await _syncMarkers();
    } catch (_) {}
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
      _courierPosition = Position(current.longitude, current.latitude);
    });
    await _syncMarkers();
  }

  Future<void> _syncMarkers() async {
    final manager = _circleManager;
    if (manager == null) return;
    try {
      await manager.deleteAll();
      await manager.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _customerPosition),
          circleColor: const Color(0xFFE60012).value,
          circleRadius: 8,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 2,
        ),
      );
      final courier = _courierPosition;
      if (courier != null) {
        await manager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: courier),
            circleColor: const Color(0xFF1976D2).value,
            circleRadius: 8,
            circleStrokeColor: Colors.white.value,
            circleStrokeWidth: 2,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final customerLat = widget.order.customerLatitude;
    final customerLng = widget.order.customerLongitude;
    if (customerLat == null || customerLng == null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('لوكيشن الزبون'),
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
          'لوكيشن الزبون',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => AppHelpers.openExternalMapNavigation(
            latitude: customerLat,
            longitude: customerLng,
          ),
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
              child: MapWidget(
                styleUri: 'mapbox://styles/mapbox/streets-v12',
                cameraOptions: CameraOptions(
                  center: Point(coordinates: _customerPosition),
                  zoom: 14.8,
                ),
                onMapCreated: _onMapCreated,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'عنوان الزبون: ${widget.order.addressAr}',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'إحداثيات الزبون: ${customerLat.toStringAsFixed(5)}, ${customerLng.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
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
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        fontFamily: 'Cairo',
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
