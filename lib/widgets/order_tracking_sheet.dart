import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';

class OrderTrackingSheet extends StatefulWidget {
  final ActiveOrder order;

  const OrderTrackingSheet({
    super.key,
    required this.order,
  });

  @override
  State<OrderTrackingSheet> createState() => _OrderTrackingSheetState();
}

class _OrderTrackingSheetState extends State<OrderTrackingSheet> {
  Timer? _timer;
  ActiveOrder? _liveOrder;

  @override
  void initState() {
    super.initState();
    _liveOrder = widget.order;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppProvider>().refreshCustomerOrders();
      if (!mounted) return;
      _syncLiveOrder();
    });
    _timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await context.read<AppProvider>().refreshCustomerOrders();
      if (!mounted) return;
      _syncLiveOrder();
    });
  }

  void _syncLiveOrder() {
    final updated = context.read<AppProvider>().orders.firstWhere(
          (order) => order.id == widget.order.id,
          orElse: () => _liveOrder ?? widget.order,
        );
    setState(() => _liveOrder = updated);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = _liveOrder ?? widget.order;
    final steps = _buildSteps(order);
    final eta = _etaLabel(order);

    return CupertinoActionSheet(
      title: Text(
        'تتبع الطلب #${order.orderNumber}',
        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
      ),
      message: Column(
        children: [
          if ((order.assignedCourierName ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'المندوب: ${order.assignedCourierName}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            ),
          ],
          if (eta != null) ...[
            const SizedBox(height: 6),
            Text(
              eta,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: Colors.deepOrange,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...steps,
        ],
      ),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('إغلاق'),
      ),
    );
  }

  List<Widget> _buildSteps(ActiveOrder order) {
    final key = order.deliveryStatusKey ?? order.statusKey;
    final doneUntil = _doneIndex(key);

    final labels = [
      (
        'تم استلام الطلب',
        'التاجر يستلم طلبك',
      ),
      (
        'قيد التحضير',
        'المتجر يجهّز الطلب',
      ),
      (
        'المندوب في الطريق',
        order.deliveryStatusAr ?? 'جاري التوصيل',
      ),
      (
        'تم التسليم',
        order.codConfirmed ? 'تم الدفع نقداً' : 'بانتظار التسليم',
      ),
    ];

    return List.generate(labels.length, (index) {
      final isDone = index <= doneUntil;
      final isActive = index == doneUntil + 1;
      return _TimelineStep(
        title: labels[index].$1,
        subtitle: labels[index].$2,
        isDone: isDone,
        isActive: isActive,
      );
    });
  }

  int _doneIndex(String key) {
    if (const {'completed', 'delivered', 'done'}.contains(key)) return 3;
    if (key == 'on_way') return 2;
    if (const {'picked_up', 'accepted'}.contains(key)) return 1;
    if (const {'preparing', 'delivering', 'waiting'}.contains(key)) return 0;
    return -1;
  }

  String? _etaLabel(ActiveOrder order) {
    if (order.estimatedArrivalMinutes != null &&
        const {'on_way', 'picked_up', 'accepted'}.contains(order.deliveryStatusKey)) {
      return 'الوصول المتوقع: ~${order.estimatedArrivalMinutes} دقيقة';
    }
    if (order.estimatedArrivalAt != null) {
      return 'الوصول المتوقع: ${order.estimatedArrivalAt}';
    }
    return null;
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDone;
  final bool isActive;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? Colors.green
        : isActive
            ? Colors.orange
            : CupertinoColors.systemGrey4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(
            isDone
                ? CupertinoIcons.checkmark_circle_fill
                : isActive
                    ? CupertinoIcons.location_solid
                    : CupertinoIcons.circle,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    color: isDone || isActive
                        ? CupertinoColors.black
                        : CupertinoColors.systemGrey,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: CupertinoColors.systemGrey,
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
