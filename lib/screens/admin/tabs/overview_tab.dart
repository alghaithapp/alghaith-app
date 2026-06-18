import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/extensions.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class OverviewTab extends StatelessWidget {
  final Map<String, dynamic> reports;
  const OverviewTab({required this.reports});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final salesTotal = ((reports['totalSales'] as num?) ?? 0).toInt();
    final codTotal = ((reports['codCollected'] as num?) ?? 0).toInt();

    return RefreshIndicator(
      onRefresh: () async => provider.refreshAdminReports(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'إجمالي المبيعات',
                  value: '${salesTotal.toPrice()} د.ع',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF007A7A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: 'كاش محصّل',
                  value: '${codTotal.toPrice()} د.ع',
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              StatTile(
                label: 'إجمالي الطلبات',
                value: '${reports['totalOrders'] ?? 0}',
                icon: Icons.shopping_bag_rounded,
                color: Colors.deepOrange,
              ),
              StatTile(
                label: 'طلبات مكتملة',
                value: '${reports['completedOrders'] ?? 0}',
                icon: Icons.check_circle_rounded,
                color: Colors.green,
              ),
              StatTile(
                label: 'قيد التوصيل',
                value: '${reports['deliveringOrders'] ?? 0}',
                icon: Icons.motorcycle_rounded,
                color: Colors.blue,
              ),
              StatTile(
                label: 'بانتظار الموافقة',
                value: '${reports['pendingOrders'] ?? 0}',
                icon: Icons.hourglass_empty_rounded,
                color: Colors.amber.shade800,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const HeaderWithAction(title: 'آخر التحركات'),
          const SizedBox(height: 10),
          ..._recentOrders(reports).map((order) => ModernOrderTile(order: order)),

          const SizedBox(height: 32),
          ModernWideButton(
            label: 'التبديل لحساب الزبون',
            icon: Icons.person_search_rounded,
            onTap: () => provider.setUserRole('customer'),
            color: const Color(0xFF1A1A1A),
          ),
          const SizedBox(height: 12),
          ModernWideButton(
            label: 'تسجيل الخروج',
            icon: Icons.power_settings_new_rounded,
            onTap: provider.resetAll,
            color: Colors.red.shade700,
            isOutlined: true,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _recentOrders(Map<String, dynamic> reports) {
    final raw = reports['recentOrders'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .take(5)
        .toList();
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Text(
                  label,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderWithAction extends StatelessWidget {
  final String title;
  const HeaderWithAction({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 17),
        ),
      ],
    );
  }
}

class ModernOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  const ModernOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2F2F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.blueGrey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلب #${order['orderNumber'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  '${order['merchantStoreName'] ?? order['customerNameAr'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${((order['price'] as num?) ?? 0).toInt().toPrice()} د.ع',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.accent),
              ),
              const SizedBox(height: 2),
              const Text('قبل قليل', style: TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class ModernWideButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool isOutlined;

  const ModernWideButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(18),
          border: isOutlined ? Border.all(color: color, width: 1.5) : null,
          boxShadow: isOutlined ? null : [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isOutlined ? color : Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    color: isOutlined ? color : Colors.white,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
