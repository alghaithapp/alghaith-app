import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';
import 'order_details_screen.dart';

class MerchantOrdersScreen extends StatelessWidget {
  const MerchantOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          label: isAr ? 'جديد' : 'New',
                          value: '${provider.merchantPendingOrdersCount}',
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          label: isAr ? 'قيد التجهيز' : 'Preparing',
                          value:
                              '${provider.orders.where((o) => o.statusKey == 'preparing').length}',
                          color: Colors.deepOrange,
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          label: isAr ? 'جاهز' : 'Ready',
                          value:
                              '${provider.orders.where((o) => o.statusKey == 'delivering').length}',
                          color: Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          label: isAr ? 'ملغي' : 'Cancelled',
                          value:
                              '${provider.orders.where((o) => o.statusKey == 'cancelled').length}',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const TabBar(
                    isScrollable: true,
                    labelColor: Colors.deepOrange,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.deepOrange,
                    tabs: [
                      Tab(text: 'جديد'),
                      Tab(text: 'قيد التجهيز'),
                      Tab(text: 'جاهز للتوصيل'),
                      Tab(text: 'مكتمل'),
                      Tab(text: 'ملغي'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _OrdersList(
                  orders: provider.orders
                      .where((o) => o.statusKey == 'pending')
                      .toList(),
                  isAr: isAr,
                ),
                _OrdersList(
                  orders: provider.orders
                      .where((o) => o.statusKey == 'preparing')
                      .toList(),
                  isAr: isAr,
                ),
                _OrdersList(
                  orders: provider.orders
                      .where((o) => o.statusKey == 'delivering')
                      .toList(),
                  isAr: isAr,
                ),
                _OrdersList(
                  orders: provider.orders
                      .where((o) => o.statusKey == 'completed')
                      .toList(),
                  isAr: isAr,
                ),
                _OrdersList(
                  orders: provider.orders
                      .where((o) => o.statusKey == 'cancelled')
                      .toList(),
                  isAr: isAr,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<ActiveOrder> orders;
  final bool isAr;

  const _OrdersList({
    required this.orders,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    if (orders.isEmpty) {
      return Center(
        child: Text(
          isAr ? 'لا توجد طلبات هنا' : 'No orders here',
          style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(
          order: order,
          isAr: isAr,
          onDetails: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => OrderDetailsScreen(order: order)),
            );
          },
          onAccept: () => provider.updateOrderStatus(
              order.id, 'accepted', 'تم القبول', 'Accepted'),
          onReject: () => provider.updateOrderStatus(
              order.id, 'cancelled', 'ملغي', 'Cancelled'),
          onNext: () {
            final nextStatus = order.statusKey == 'pending'
                ? 'preparing'
                : order.statusKey == 'preparing'
                    ? 'delivering'
                    : 'completed';
            final nextAr = order.statusKey == 'pending'
                ? 'قيد التجهيز'
                : order.statusKey == 'preparing'
                    ? 'جاهز للتوصيل'
                    : 'مكتمل';
            final nextEn = order.statusKey == 'pending'
                ? 'Preparing'
                : order.statusKey == 'preparing'
                    ? 'Ready'
                    : 'Completed';
            provider.updateOrderStatus(order.id, nextStatus, nextAr, nextEn);
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final ActiveOrder order;
  final bool isAr;
  final VoidCallback onDetails;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onNext;

  const _OrderCard({
    required this.order,
    required this.isAr,
    required this.onDetails,
    required this.onAccept,
    required this.onReject,
    required this.onNext,
  });

  Color get statusColor {
    switch (order.statusKey) {
      case 'preparing':
        return Colors.deepOrange;
      case 'delivering':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAr ? order.customerNameAr : order.customerNameEn,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAr ? order.dateAr : order.dateEn,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isAr ? order.statusAr : order.statusEn,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isAr ? order.itemsNameAr : order.itemsNameEn,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${order.price.toPrice()} د.ع',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.deepOrange,
                  fontFamily: 'Cairo',
                ),
              ),
              Text(
                isAr ? order.paymentMethodAr : order.paymentMethodEn,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallButton(
                label: isAr ? 'تفاصيل' : 'Details',
                color: Colors.black87,
                onTap: onDetails,
              ),
              if (order.statusKey == 'pending')
                _SmallButton(
                  label: isAr ? 'قبول' : 'Accept',
                  color: Colors.blue,
                  onTap: onAccept,
                ),
              if (order.statusKey == 'pending')
                _SmallButton(
                  label: isAr ? 'رفض' : 'Reject',
                  color: Colors.red,
                  onTap: onReject,
                ),
              if (order.statusKey != 'completed' &&
                  order.statusKey != 'cancelled')
                _SmallButton(
                  label: isAr ? 'تغيير الحالة' : 'Next Status',
                  color: Colors.green,
                  onTap: onNext,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(
            fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.10),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}
