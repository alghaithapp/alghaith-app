import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../utils/extensions.dart';
import '../../utils/helpers.dart';
import 'delivery_shared_widgets.dart';
import 'delivery_requests_screen.dart';

// ── Screen ───────────────────────────────────────────────────────

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
            ? DeliveryEmptyCard(
                text: 'لا توجد طلبات نشطة حالياً',
              )
            : RefreshIndicator(
                onRefresh: appProvider.refreshCourierOrders,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    return DeliveryActiveGroupCard(group: grouped[index]);
                  },
                ),
              ),
      ),
    );
  }
}

// ── Active Group Card ────────────────────────────────────────────

class DeliveryActiveGroupCard extends StatelessWidget {
  final CourierGroupedOrder group;

  const DeliveryActiveGroupCard({super.key, required this.group});

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
