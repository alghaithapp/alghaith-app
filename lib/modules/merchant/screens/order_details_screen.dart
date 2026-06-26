import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/orders/order_adjustment.dart';
import '../../../models/app_models.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/extensions.dart';

class OrderDetailsScreen extends StatefulWidget {
  final ActiveOrder order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late List<OrderLineItem> _lineItems;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _lineItems = widget.order.lineItems
        .map((item) => item.copyWith(isAvailable: true))
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<AppProvider>().markMerchantOrderAsRead(widget.order.id),
      );
    });
  }

  ActiveOrder get _liveOrder {
    final provider = context.watch<AppProvider>();
    return provider.merchantIncomingOrders.firstWhere(
      (order) => order.id == widget.order.id,
      orElse: () => widget.order,
    );
  }

  int get _adjustedTotal => computeAdjustedOrderTotal(_liveOrder, _lineItems);

  bool get _hasUnavailable => orderHasUnavailableItems(_lineItems);

  int get _availableCount =>
      _lineItems.where((item) => item.isAvailable).length;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final order = _liveOrder;
    final labels = provider.merchantLabels;
    final canAdjust = order.statusKey == 'pending' && _lineItems.isNotEmpty;
    final waitingCustomer = order.statusKey == 'adjustment_pending';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'تفاصيل الطلب',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            title: provider.displayOrderNumber(order),
            children: [
              _InfoRow(label: 'العميل', value: order.customerNameAr),
              _InfoRow(label: 'الهاتف', value: order.customerPhone),
              _InfoRow(label: 'العنوان', value: order.addressAr),
              _InfoRow(label: 'طريقة الدفع', value: order.paymentMethodAr),
              if (order.noteAr.isNotEmpty)
                _InfoRow(label: 'ملاحظات', value: order.noteAr),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: '${labels.itemPluralAr} المطلوبة',
            children: _lineItems.isEmpty
                ? [
                    const Text(
                      'لا توجد عناصر مفصلة.',
                      style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
                    ),
                  ]
                : _lineItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.isAvailable
                                  ? Colors.deepOrange.withValues(alpha: 0.10)
                                  : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              item.isAvailable
                                  ? Icons.fastfood_rounded
                                  : Icons.block_rounded,
                              color: item.isAvailable
                                  ? Colors.deepOrange
                                  : Colors.grey,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nameAr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Cairo',
                                    decoration: item.isAvailable
                                        ? null
                                        : TextDecoration.lineThrough,
                                    color: item.isAvailable
                                        ? Colors.black
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.quantity} × ${item.price.toPrice()} د.ع',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                if (!item.isAvailable)
                                  const Text(
                                    'غير متوفر',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (canAdjust)
                            Switch(
                              value: item.isAvailable,
                              activeThumbColor: Colors.green,
                              onChanged: _submitting
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _lineItems[index] =
                                            item.copyWith(isAvailable: value);
                                      });
                                    },
                            ),
                        ],
                      ),
                    );
                  }).toList(),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'الإجمالي',
            children: [
              if (_hasUnavailable && canAdjust) ...[
                _InfoRow(
                  label: 'السعر الأصلي',
                  value: '${order.price.toPrice()} د.ع',
                ),
                _InfoRow(
                  label: 'بعد التعديل',
                  value: '${_adjustedTotal.toPrice()} د.ع',
                ),
              ] else
                _InfoRow(
                  label: 'المبلغ',
                  value: '${order.price.toPrice()} د.ع',
                ),
              _InfoRow(label: 'الحالة', value: order.statusAr),
              if (order.deliveryStatusKey != null)
                _InfoRow(
                  label: 'التوصيل',
                  value: order.deliveryStatusAr ?? '-',
                ),
            ],
          ),
          if (waitingCustomer) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
              ),
              child: const Text(
                'أُرسل التعديل للزبون وبانتظار موافقته أو رفضه.',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE65100),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canAdjust && !_hasUnavailable)
                _ActionButton(
                  label: 'قبول الطلب كاملاً',
                  color: Colors.blue,
                  onTap: _submitting
                      ? () {}
                      : () => provider.updateOrderStatus(
                            order.id,
                            'accepted',
                            'تمت الموافقة',
                            'Approved',
                          ),
                ),
              if (canAdjust && _hasUnavailable && _availableCount > 0)
                _ActionButton(
                  label: 'إرسال التعديل للزبون',
                  color: Colors.deepOrange,
                  onTap: _submitting ? () {} : () => _sendAdjustment(provider),
                ),
              if (canAdjust)
                _ActionButton(
                  label: 'رفض الطلب',
                  color: Colors.red,
                  onTap: _submitting
                      ? () {}
                      : () => _rejectWithReason(context, provider, order.id),
                ),
              if (order.statusKey == 'cancel_requested')
                _ActionButton(
                  label: 'موافقة على الإلغاء',
                  color: Colors.red,
                  onTap: () =>
                      provider.resolveCustomerCancellationRequestByMerchant(
                    order.id,
                    approve: true,
                  ),
                ),
              if (order.statusKey == 'cancel_requested')
                _ActionButton(
                  label: 'رفض طلب الإلغاء',
                  color: Colors.blue,
                  onTap: () =>
                      provider.resolveCustomerCancellationRequestByMerchant(
                    order.id,
                    approve: false,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendAdjustment(AppProvider provider) async {
    if (_availableCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب أن يبقى منتج واحد متوفراً على الأقل.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرسال التعديل للزبون'),
        content: Text(
          'سيتم إرسال الطلب المعدّل بمبلغ ${_adjustedTotal.toPrice()} د.ع '
          'وبانتظار موافقة الزبون.',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الإرسال'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final ok = await provider.proposeMerchantOrderAdjustment(
      widget.order.id,
      _lineItems,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'تم إرسال التعديل للزبون.'
              : 'تعذر إرسال التعديل. حاول مجدداً.',
        ),
      ),
    );
  }

  Future<void> _rejectWithReason(
    BuildContext context,
    AppProvider provider,
    String orderId,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سبب رفض الطلب'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب سبب الرفض ليظهر للزبون',
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
    if (reason == null || reason.trim().isEmpty) return;
    provider.updateOrderStatus(
      orderId,
      'cancelled',
      'تم رفض الطلب',
      'Rejected',
      noteAr: 'سبب الرفض: ${reason.trim()}',
      noteEn: 'Rejected reason: ${reason.trim()}',
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 42) / 2,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onTap,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
