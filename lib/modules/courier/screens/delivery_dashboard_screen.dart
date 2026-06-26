import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/app_models.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/extensions.dart';
import '../../../core/theme/app_colors.dart';
import 'delivery_earnings_screen.dart';
import 'delivery_shared_widgets.dart';
import 'delivery_requests_screen.dart';

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
            DeliveryTopCard(
              title: 'مرحبًا ${appProvider.deliveryCourierName}',
              subtitle:
                  'توصيل طلبات المطاعم والتسوق — استلام نقداً عند التسليم',
              icon: Icons.motorcycle,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: DeliveryStatBox(
                        label: 'جديدة',
                        value: '${groupedIncoming.length}',
                        color: AppColors.accent)),
                const SizedBox(width: 10),
                Expanded(
                    child: DeliveryStatBox(
                        label: 'نشطة', value: '$active', color: Colors.blue)),
                const SizedBox(width: 10),
                Expanded(
                    child: DeliveryStatBox(
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
            DeliverySectionTitle(title: 'طلبات مطاعم وتسوق جديدة'),
            const SizedBox(height: 10),
            if (groupedIncoming.isEmpty)
              DeliveryEmptyCard(
                text: 'لا توجد طلبات جديدة من المطاعم أو التسوق الآن',
              )
            else
              ...groupedIncoming
                  .take(3)
                  .map((group) => DeliveryGroupCard(group: group)),
          ],
        ),
      ),
    );
  }
}
