import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../utils/extensions.dart';
import 'delivery_shared_widgets.dart';

// ── Model ────────────────────────────────────────────────────────

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

// ── Extension ────────────────────────────────────────────────────

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

// ── Screen ───────────────────────────────────────────────────────

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
            ? DeliveryEmptyCard(
                text: 'لا توجد طلبات جاهزة للتوصيل حالياً',
              )
            : RefreshIndicator(
                onRefresh: appProvider.refreshCourierOrders,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    return DeliveryGroupCard(group: grouped[index]);
                  },
                ),
              ),
      ),
    );
  }
}

// ── Group Card ───────────────────────────────────────────────────

class DeliveryGroupCard extends StatelessWidget {
  final CourierGroupedOrder group;

  const DeliveryGroupCard({super.key, required this.group});

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
