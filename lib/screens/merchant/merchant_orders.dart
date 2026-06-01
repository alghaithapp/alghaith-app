import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';

class MerchantOrders extends StatelessWidget {
  const MerchantOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isAr = appProvider.lang == 'ar';
    final labels = appProvider.merchantLabels;
    final orders = appProvider.orders;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: Color(0x11000000))),
        middle: Text(
          isAr
              ? 'طلبات ${labels.storeLabelAr}'
              : '${labels.storeLabelEn} Orders',
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniOrderStat(
                        label: isAr ? 'كل الطلبات' : 'All',
                        value: '${orders.length}',
                        color: Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _MiniOrderStat(
                        label: isAr ? 'بانتظار' : 'Pending',
                        value: '${appProvider.merchantPendingOrdersCount}',
                        color: Colors.redAccent,
                      ),
                    ),
                    Expanded(
                      child: _MiniOrderStat(
                        label: isAr ? 'قيد الخدمة' : 'Active',
                        value: '${appProvider.merchantActiveOrdersCount}',
                        color: Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _MiniOrderStat(
                        label: isAr ? 'مكتملة' : 'Done',
                        value: '${appProvider.merchantCompletedOrdersCount}',
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: orders.isEmpty
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.doc_text_search,
                                size: 54, color: Colors.orange),
                            const SizedBox(height: 10),
                            Text(
                              isAr ? 'لا توجد طلبات حتى الآن' : 'No orders yet',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Cairo'),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isAr
                                  ? 'ستظهر الطلبات الجديدة هنا مع أزرار التحكم بالحالة.'
                                  : 'Incoming orders will appear here with full status controls.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  height: 1.4,
                                  fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return _OrderCard(
                          order: order,
                          isAr: isAr,
                          onAccept: () => appProvider.updateOrderStatus(
                              order.id, 'accepted', 'تم القبول', 'Accepted'),
                          onPrepare: () => appProvider.updateOrderStatus(
                              order.id,
                              'preparing',
                              'قيد التحضير',
                              'Preparing'),
                          onDeliver: () => appProvider.updateOrderStatus(
                              order.id,
                              'delivering',
                              'قيد التوصيل',
                              'Delivering'),
                          onComplete: () => appProvider.updateOrderStatus(
                              order.id, 'completed', 'مكتمل', 'Completed'),
                          onReject: () => appProvider.updateOrderStatus(
                              order.id, 'cancelled', 'ملغي', 'Cancelled'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final ActiveOrder order;
  final bool isAr;
  final VoidCallback onAccept;
  final VoidCallback onPrepare;
  final VoidCallback onDeliver;
  final VoidCallback onComplete;
  final VoidCallback onReject;

  const _OrderCard({
    required this.order,
    required this.isAr,
    required this.onAccept,
    required this.onPrepare,
    required this.onDeliver,
    required this.onComplete,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final statusKey = order.statusKey;
    final isPending = statusKey == 'pending';
    final isAccepted = statusKey == 'accepted';
    final isPreparing = statusKey == 'preparing';
    final isDelivering = statusKey == 'delivering';
    final isDone = statusKey == 'completed';
    final isCancelled = statusKey == 'cancelled';

    final Color statusColor = isCancelled
        ? Colors.red
        : isDone
            ? Colors.green
            : isDelivering
                ? Colors.blue
                : isPreparing
                    ? Colors.deepOrange
                    : isAccepted
                        ? Colors.teal
                        : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAr ? order.dateAr : order.dateEn,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11, fontFamily: 'Cairo'),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
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
            isAr ? 'الطلبات' : 'Items',
            style: const TextStyle(
                color: Colors.grey, fontSize: 11, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 4),
          Text(
            isAr ? order.itemsNameAr : order.itemsNameEn,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
                fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${order.price.toPrice()} د.ع',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange),
              ),
              Text(
                '${order.itemsCount} ${isAr ? 'صنف' : 'items'}',
                style: const TextStyle(
                    color: Colors.grey, fontSize: 11, fontFamily: 'Cairo'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isPending)
                _ActionChip(
                  label: isAr ? 'قبول' : 'Accept',
                  color: Colors.green,
                  onTap: onAccept,
                ),
              if (isPending || isAccepted)
                _ActionChip(
                  label: isAr ? 'تحضير' : 'Prepare',
                  color: Colors.deepOrange,
                  onTap: onPrepare,
                ),
              if (isAccepted || isPreparing)
                _ActionChip(
                  label: isAr ? 'تسليم' : 'Deliver',
                  color: Colors.blue,
                  onTap: onDeliver,
                ),
              if (isDelivering)
                _ActionChip(
                  label: isAr ? 'إتمام' : 'Complete',
                  color: Colors.green,
                  onTap: onComplete,
                ),
              if (isPending)
                _ActionChip(
                  label: isAr ? 'رفض' : 'Reject',
                  color: Colors.red,
                  onTap: onReject,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: color,
      borderRadius: BorderRadius.circular(14),
      onPressed: onTap,
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
    );
  }
}

class _MiniOrderStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniOrderStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11, color: Colors.grey, fontFamily: 'Cairo'),
        ),
      ],
    );
  }
}
