import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';

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
    DeliveryAccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appProvider = Provider.of<AppProvider>(context);
    final lang = appProvider.lang;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
      body: SafeArea(bottom: false, child: _screens[_currentIndex]),
      bottomNavigationBar: Container(
        height: 90,
        decoration: BoxDecoration(
          color:
              isDark ? const Color(0xFF1A1A1A) : Colors.white.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, CupertinoIcons.graph_square_fill,
                lang == 'ar' ? 'الرئيسية' : 'Home'),
            _navItem(1, CupertinoIcons.bell_fill,
                lang == 'ar' ? 'الطلبات' : 'Requests'),
            _navItem(2, CupertinoIcons.car_detailed,
                lang == 'ar' ? 'نشطة' : 'Active'),
            _navItem(3, CupertinoIcons.person_fill,
                lang == 'ar' ? 'الحساب' : 'Account'),
          ],
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
              fontSize: 10,
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
    final isAr = appProvider.lang == 'ar';
    final waiting = appProvider.deliveryIncomingOrders.length;
    final active = appProvider.deliveryActiveOrders.length;
    final done = appProvider.deliveryCompletedOrders.length;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? 'لوحة المندوب' : 'Delivery Dashboard',
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
              title: isAr ? 'مرحبًا بك يا مندوب' : 'Welcome courier',
              subtitle: isAr
                  ? 'تابع الطلبات الجديدة من المطاعم ووافق عليها أو ارفضها'
                  : 'Track restaurant requests and accept or reject them',
              icon: CupertinoIcons.bag_fill,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _StatBox(
                        label: isAr ? 'جديدة' : 'New',
                        value: '$waiting',
                        color: Colors.orange)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatBox(
                        label: isAr ? 'نشطة' : 'Active',
                        value: '$active',
                        color: Colors.blue)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatBox(
                        label: isAr ? 'مكتملة' : 'Done',
                        value: '$done',
                        color: Colors.green)),
              ],
            ),
            const SizedBox(height: 16),
            _SectionTitle(
                title:
                    isAr ? 'طلبات مطاعم جديدة' : 'Incoming restaurant orders'),
            const SizedBox(height: 10),
            if (appProvider.deliveryIncomingOrders.isEmpty)
              _EmptyCard(
                text: isAr
                    ? 'لا توجد طلبات مطاعم جديدة الآن'
                    : 'No new restaurant requests right now',
              )
            else
              ...appProvider.deliveryIncomingOrders
                  .take(3)
                  .map((order) => _DeliveryOrderCard(order: order, isAr: isAr)),
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
    final isAr = appProvider.lang == 'ar';
    final orders = appProvider.deliveryIncomingOrders;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? 'الطلبات الواردة' : 'Incoming Requests',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        border: null,
      ),
      child: SafeArea(
        child: orders.isEmpty
            ? _EmptyCard(
                text: isAr
                    ? 'لا توجد طلبات واردة من المطاعم'
                    : 'No incoming restaurant requests',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  return _DeliveryOrderCard(order: orders[index], isAr: isAr);
                },
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
    final isAr = appProvider.lang == 'ar';
    final orders = appProvider.deliveryActiveOrders;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? 'الطلبات النشطة' : 'Active Deliveries',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        border: null,
      ),
      child: SafeArea(
        child: orders.isEmpty
            ? _EmptyCard(
                text: isAr
                    ? 'لا توجد طلبات نشطة حاليًا'
                    : 'No active deliveries yet',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  return _ActiveDeliveryCard(order: orders[index], isAr: isAr);
                },
              ),
      ),
    );
  }
}

class DeliveryAccountScreen extends StatelessWidget {
  const DeliveryAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isAr = appProvider.lang == 'ar';

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? 'حساب المندوب' : 'Courier Account',
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
              title: isAr ? 'مندوب التوصيل' : 'Delivery Courier',
              subtitle: isAr
                  ? 'هذا القسم مخصص لإدارة طلبات التوصيل القادمة من المطاعم'
                  : 'Manage restaurant delivery requests from here',
              icon: CupertinoIcons.car_detailed,
            ),
            const SizedBox(height: 16),
            _InfoTile(
              label: isAr ? 'الاسم' : 'Name',
              value: appProvider.deliveryCourierName,
            ),
            _InfoTile(
              label: isAr ? 'الطلبات الجديدة' : 'New requests',
              value: '${appProvider.deliveryIncomingOrders.length}',
            ),
            _InfoTile(
              label: isAr ? 'الطلبات النشطة' : 'Active deliveries',
              value: '${appProvider.deliveryActiveOrders.length}',
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () => appProvider.resetAll(),
              child: Text(isAr ? 'تسجيل الخروج' : 'Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryOrderCard extends StatelessWidget {
  final ActiveOrder order;
  final bool isAr;

  const _DeliveryOrderCard({required this.order, required this.isAr});

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
                  isAr
                      ? 'طلب مطعم #${order.orderNumber}'
                      : 'Restaurant order #${order.orderNumber}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isAr ? 'جديد' : 'New',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isAr ? order.itemsNameAr : order.itemsNameEn,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${order.price.toPrice()} د.ع',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              Row(
                children: [
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    minimumSize: Size.zero,
                    onPressed: () => appProvider.rejectDeliveryOrder(order.id),
                    child: Text(isAr ? 'رفض' : 'Reject',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                    minimumSize: Size.zero,
                    onPressed: () => appProvider.acceptDeliveryOrder(order.id),
                    child: Text(isAr ? 'موافقة' : 'Accept',
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
  final bool isAr;

  const _ActiveDeliveryCard({required this.order, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final delivered = order.deliveryStatusKey == 'delivered';
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
            isAr ? 'طلب #${order.orderNumber}' : 'Order #${order.orderNumber}',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 6),
          Text(
            isAr
                ? (order.deliveryStatusAr ?? 'قيد التوصيل')
                : (order.deliveryStatusEn ?? 'Out for delivery'),
            style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (order.deliveryStatusKey == 'accepted')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: Size.zero,
                  onPressed: () => appProvider.markDeliveryPickedUp(order.id),
                  child: Text(isAr ? 'استلام الطلب' : 'Pick Up',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              if (order.deliveryStatusKey == 'picked_up')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: Size.zero,
                  onPressed: () => appProvider.markDeliveryCompleted(order.id),
                  child: Text(isAr ? 'تم التسليم' : 'Delivered',
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
