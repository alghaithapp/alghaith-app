import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';

class MerchantEarningsScreen extends StatelessWidget {
  const MerchantEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';
    final orders = provider.orders;
    final completedOrders =
        orders.where((o) => o.statusKey == 'completed').toList();
    final pendingOrders =
        orders.where((o) => o.statusKey == 'pending').toList();
    final preparingOrders =
        orders.where((o) => o.statusKey == 'preparing').toList();
    final deliveringOrders =
        orders.where((o) => o.statusKey == 'delivering').toList();
    final chartBars = <_EarningPoint>[
      _EarningPoint(
        label: isAr ? 'مكتمل' : 'Completed',
        value: completedOrders.fold<int>(0, (sum, order) => sum + order.price),
      ),
      _EarningPoint(
        label: isAr ? 'قيد التجهيز' : 'Preparing',
        value: preparingOrders.fold<int>(0, (sum, order) => sum + order.price),
      ),
      _EarningPoint(
        label: isAr ? 'قيد التوصيل' : 'Delivering',
        value: deliveringOrders.fold<int>(0, (sum, order) => sum + order.price),
      ),
      _EarningPoint(
        label: isAr ? 'بانتظار' : 'Pending',
        value: pendingOrders.fold<int>(0, (sum, order) => sum + order.price),
      ),
    ];
    final max = chartBars
        .map((e) => e.value)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, 999999999);
    final recentOrders = orders.take(5).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _EarningCard(
              label: isAr ? 'إجمالي المبيعات' : 'Total Sales',
              value: '${provider.totalSales.toPrice()} د.ع',
              color: Colors.deepOrange,
            ),
            _EarningCard(
              label: isAr ? 'عدد الطلبات' : 'Orders',
              value: '${provider.merchantOrdersCount}',
              color: Colors.blue,
            ),
            _EarningCard(
              label: isAr ? 'المكتملة' : 'Completed',
              value: '${provider.merchantCompletedOrdersCount}',
              color: Colors.green,
            ),
            _EarningCard(
              label: isAr ? 'بانتظار' : 'Pending',
              value: '${provider.merchantPendingOrdersCount}',
              color: Colors.purple,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? 'رسم بياني مبسط' : 'Simple Chart',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: chartBars.map((point) {
                    final ratio = point.value / max;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 130 * ratio,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF8A50),
                                    Color(0xFFFF5A1F)
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              point.label,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? 'آخر العمليات' : 'Recent Transactions',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 12),
              if (recentOrders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    isAr ? 'لا توجد عمليات بعد.' : 'No transactions yet.',
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                )
              else
                ...recentOrders.map((order) {
                  final title = isAr ? order.itemsNameAr : order.itemsNameEn;
                  final status = isAr
                      ? (order.deliveryStatusAr ?? order.statusAr)
                      : (order.deliveryStatusEn ?? order.statusEn);
                  final amount = order.price;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              Colors.deepOrange.withValues(alpha: 0.10),
                          child: const Icon(Icons.receipt_long_rounded,
                              color: Colors.deepOrange, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Cairo')),
                              const SizedBox(height: 4),
                              Text(status,
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontFamily: 'Cairo')),
                            ],
                          ),
                        ),
                        Text(
                          '${amount.toPrice()} د.ع',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.deepOrange,
                              fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _EarningPoint {
  final String label;
  final int value;

  _EarningPoint({
    required this.label,
    required this.value,
  });
}

class _EarningCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _EarningCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.payments_rounded, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
                color: Colors.black54, fontSize: 12, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }
}
