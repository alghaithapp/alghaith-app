import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Provider.of<AppProvider>(context).lang == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final methods = [
      _PaymentMethod(
        titleAr: 'الدفع عند الاستلام',
        titleEn: 'Cash on Delivery',
        subtitleAr: 'الطريقة المتاحة حاليًا',
        subtitleEn: 'Available right now',
        icon: CupertinoIcons.money_dollar_circle_fill,
        color: Colors.green,
        active: true,
      ),
    ];

    return CupertinoPageScaffold(
      backgroundColor:
          isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? 'طرق الدفع' : 'Payment Methods',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                isAr
                    ? 'حاليًا طريقة الدفع الوحيدة المتاحة هي الدفع عند الاستلام. سيتم تفعيل Super Key و Zain Cash لاحقًا.'
                    : 'Currently, the only available payment method is Cash on Delivery. Super Key and Zain Cash will be enabled later.',
                style: const TextStyle(height: 1.5, fontFamily: 'Cairo'),
              ),
            ),
            const SizedBox(height: 14),
            ...methods.map(
              (method) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PaymentCard(method: method, isAr: isAr),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                isAr
                    ? 'لا توجد طرق دفع أخرى مفعلة الآن. جميع الطلبات تُسدد نقدًا عند الاستلام.'
                    : 'No other payment methods are enabled now. All orders are paid cash on delivery.',
                style: const TextStyle(height: 1.5, fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final _PaymentMethod method;
  final bool isAr;

  const _PaymentCard({
    required this.method,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final title = isAr ? method.titleAr : method.titleEn;
    final subtitle = isAr ? method.subtitleAr : method.subtitleEn;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: method.active
              ? method.color.withValues(alpha: 0.18)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: method.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(method.icon, color: method.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                    color: method.active ? Colors.black : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: method.active ? method.color : Colors.grey,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: method.active
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              method.active
                  ? (isAr ? 'متاح' : 'Active')
                  : (isAr ? 'قريباً' : 'Soon'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: method.active ? Colors.green : Colors.grey,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethod {
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final IconData icon;
  final Color color;
  final bool active;

  _PaymentMethod({
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.icon,
    required this.color,
    required this.active,
  });
}
