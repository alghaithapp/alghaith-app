import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';

class OrderDetailsScreen extends StatelessWidget {
  final ActiveOrder order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';
    final labels = provider.merchantLabels;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          isAr ? 'تفاصيل الطلب' : 'Order Details',
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            title: order.orderNumber,
            children: [
              _InfoRow(
                  label: isAr ? 'العميل' : 'Customer',
                  value: isAr ? order.customerNameAr : order.customerNameEn),
              _InfoRow(
                  label: isAr ? 'الهاتف' : 'Phone', value: order.customerPhone),
              _InfoRow(
                  label: isAr ? 'العنوان' : 'Address',
                  value: isAr ? order.addressAr : order.addressEn),
              _InfoRow(
                  label: isAr ? 'طريقة الدفع' : 'Payment',
                  value: isAr ? order.paymentMethodAr : order.paymentMethodEn),
              if ((isAr ? order.noteAr : order.noteEn).isNotEmpty)
                _InfoRow(
                    label: isAr ? 'ملاحظات' : 'Note',
                    value: isAr ? order.noteAr : order.noteEn),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: isAr
                ? '${labels.itemPluralAr} المطلوبة'
                : 'Ordered ${labels.itemPluralEn}',
            children: order.lineItems.isEmpty
                ? [
                    Text(
                      isAr
                          ? 'لا توجد عناصر مفصلة.'
                          : 'No detailed items available.',
                      style: const TextStyle(
                          color: Colors.grey, fontFamily: 'Cairo'),
                    )
                  ]
                : order.lineItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.fastfood_rounded,
                                color: Colors.deepOrange, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAr ? item.nameAr : item.nameEn,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Cairo',
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: isAr ? 'الإجمالي' : 'Total',
            children: [
              _InfoRow(
                  label: isAr ? 'المبلغ' : 'Amount',
                  value: '${order.price.toPrice()} د.ع'),
              _InfoRow(
                  label: isAr ? 'الحالة' : 'Status',
                  value: isAr ? order.statusAr : order.statusEn),
              if (order.deliveryStatusKey != null)
                _InfoRow(
                  label: isAr ? 'التوصيل' : 'Delivery',
                  value: isAr
                      ? (order.deliveryStatusAr ?? '-')
                      : (order.deliveryStatusEn ?? '-'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                label: isAr ? 'قبول الطلب' : 'Accept',
                color: Colors.blue,
                onTap: () => provider.updateOrderStatus(
                    order.id, 'accepted', 'تم القبول', 'Accepted'),
              ),
              _ActionButton(
                label: isAr ? 'تجهيز الطلب' : 'Prepare',
                color: Colors.deepOrange,
                onTap: () => provider.updateOrderStatus(
                    order.id, 'preparing', 'قيد التجهيز', 'Preparing'),
              ),
              _ActionButton(
                label: isAr ? 'جاهز للتوصيل' : 'Ready',
                color: Colors.green,
                onTap: () => provider.updateOrderStatus(
                    order.id, 'delivering', 'جاهز للتوصيل', 'Ready'),
              ),
              _ActionButton(
                label: isAr ? 'إلغاء الطلب' : 'Cancel',
                color: Colors.red,
                onTap: () => provider.updateOrderStatus(
                    order.id, 'cancelled', 'ملغي', 'Cancelled'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.children,
  });

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

  const _InfoRow({
    required this.label,
    required this.value,
  });

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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onTap,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
