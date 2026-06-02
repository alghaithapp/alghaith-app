import 'dart:async';

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

    return DefaultTabController(
      length: 4,
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
                          label: 'جديد',
                          value: '${provider.merchantPendingOrdersCount}',
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          label: 'موافقة/إلغاء',
                          value: '${provider.merchantIncomingOrders.where((o) => o.statusKey == 'accepted' || o.statusKey == 'cancel_requested').length}',
                          color: Colors.deepOrange,
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          label: 'مكتمل',
                          value: '${provider.merchantIncomingOrders.where((o) => o.statusKey == 'completed').length}',
                          color: Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          label: 'ملغي',
                          value: '${provider.merchantIncomingOrders.where((o) => o.statusKey == 'cancelled').length}',
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
                      Tab(text: 'موافقة/إلغاء'),
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
                _OrdersList(orders: provider.merchantIncomingOrders.where((o) => o.statusKey == 'pending').toList()),
                _OrdersList(orders: provider.merchantIncomingOrders.where((o) => o.statusKey == 'accepted' || o.statusKey == 'cancel_requested').toList()),
                _OrdersList(orders: provider.merchantIncomingOrders.where((o) => o.statusKey == 'completed').toList()),
                _OrdersList(orders: provider.merchantIncomingOrders.where((o) => o.statusKey == 'cancelled').toList()),
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

  const _OrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    if (orders.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد طلبات هنا',
          style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
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
          onDetails: () async {
            await provider.markMerchantOrderAsRead(order.id);
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
            );
          },
          onAccept: () => provider.updateOrderStatus(order.id, 'accepted', 'تمت الموافقة', 'Approved'),
          onReject: () async {
            final reason = await _showRejectReasonDialog(context);
            if (reason == null || reason.trim().isEmpty) return;
            provider.updateOrderStatus(
              order.id,
              'cancelled',
              'تم رفض الطلب',
              'Rejected',
              noteAr: 'سبب الرفض: ${reason.trim()}',
              noteEn: 'Rejected reason: ${reason.trim()}',
            );
          },
          onNext: () {
            if (order.statusKey != 'accepted') return;
            provider.updateOrderStatus(order.id, 'completed', 'مكتمل', 'Completed');
          },
          onApproveCancelRequest: () {
            provider.resolveCustomerCancellationRequestByMerchant(
              order.id,
              approve: true,
            );
          },
          onRejectCancelRequest: () {
            provider.resolveCustomerCancellationRequestByMerchant(
              order.id,
              approve: false,
            );
          },
        );
      },
    );
  }

  Future<String?> _showRejectReasonDialog(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سبب رفض الطلب'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب سبب الرفض للزبون',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }
}

class _OrderCard extends StatelessWidget {
  final ActiveOrder order;
  final VoidCallback onDetails;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onNext;
  final VoidCallback onApproveCancelRequest;
  final VoidCallback onRejectCancelRequest;

  const _OrderCard({
    required this.order,
    required this.onDetails,
    required this.onAccept,
    required this.onReject,
    required this.onNext,
    required this.onApproveCancelRequest,
    required this.onRejectCancelRequest,
  });

  Color get _statusColor {
    switch (order.statusKey) {
      case 'accepted':   return Colors.deepOrange;
      case 'completed':  return Colors.green;
      case 'cancelled':  return Colors.red;
      default:           return Colors.blue;
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
                      context.read<AppProvider>().displayOrderNumber(order),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.customerNameAr,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.dateAr,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.read<AppProvider>().orderElapsedLabelAr(order),
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 11,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    if (order.statusKey == 'pending') ...[
                      const SizedBox(height: 2),
                      _PendingApprovalCountdown(order: order),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.statusAr,
                  style: TextStyle(
                    color: _statusColor,
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
            order.itemsNameAr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.4, fontFamily: 'Cairo'),
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
                order.paymentMethodAr,
                style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Cairo'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallButton(label: 'تفاصيل', color: Colors.black87, onTap: onDetails),
              if (order.statusKey == 'pending') ...[
                _SmallButton(label: 'قبول', color: Colors.blue, onTap: onAccept),
                _SmallButton(label: 'رفض', color: Colors.red, onTap: onReject),
              ],
              if (order.statusKey == 'accepted')
                _SmallButton(label: 'إكمال الطلب', color: Colors.green, onTap: onNext),
              if (order.statusKey == 'cancel_requested') ...[
                _SmallButton(
                  label: 'موافقة على الإلغاء',
                  color: Colors.red,
                  onTap: onApproveCancelRequest,
                ),
                _SmallButton(
                  label: 'رفض طلب الإلغاء',
                  color: Colors.blue,
                  onTap: onRejectCancelRequest,
                ),
              ],
              if (order.statusKey != 'completed' &&
                  order.statusKey != 'cancelled' &&
                  order.statusKey != 'accepted' &&
                  order.statusKey != 'cancel_requested' &&
                  order.statusKey != 'pending')
                _SmallButton(label: 'تغيير الحالة', color: Colors.green, onTap: onNext),
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

  const _SmallButton({required this.label, required this.color, required this.onTap});

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
      child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _PendingApprovalCountdown extends StatefulWidget {
  final ActiveOrder order;

  const _PendingApprovalCountdown({required this.order});

  @override
  State<_PendingApprovalCountdown> createState() =>
      _PendingApprovalCountdownState();
}

class _PendingApprovalCountdownState extends State<_PendingApprovalCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label =
        context.read<AppProvider>().pendingApprovalRemainingLabelAr(widget.order);
    if (label == null) return const SizedBox.shrink();
    return Text(
      label,
      style: const TextStyle(
        color: Colors.red,
        fontSize: 11,
        fontFamily: 'Cairo',
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.10),
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Cairo')),
      ],
    );
  }
}
