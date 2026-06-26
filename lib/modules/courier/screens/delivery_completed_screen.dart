import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/app_models.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/extensions.dart';
import 'delivery_earnings_screen.dart';
import 'delivery_shared_widgets.dart';

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
          onPressed: () async {
            await appProvider.refreshCourierOrders();
          },
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
        border: null,
      ),
      child: SafeArea(
        child: orders.isEmpty
            ? DeliveryEmptyCard(
                text: 'لا توجد طلبات مكتملة بعد',
              )
            : RefreshIndicator(
                onRefresh: () => appProvider.refreshCourierOrders(),
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
                      (order) => DeliveryCompletedCard(order: order),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class DeliveryCompletedCard extends StatelessWidget {
  final ActiveOrder order;

  const DeliveryCompletedCard({super.key, required this.order});

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
