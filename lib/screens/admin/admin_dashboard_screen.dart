import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshAdminReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final reports = provider.adminReports ?? const {};

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'لوحة الإدارة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: provider.refreshAdminReports,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refreshAdminReports,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Text(
              'تقارير المنصة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _ReportCard(
                  label: 'إجمالي الطلبات',
                  value: '${reports['totalOrders'] ?? 0}',
                  color: Colors.deepOrange,
                ),
                _ReportCard(
                  label: 'طلبات مكتملة',
                  value: '${reports['completedOrders'] ?? 0}',
                  color: Colors.green,
                ),
                _ReportCard(
                  label: 'قيد التوصيل',
                  value: '${reports['deliveringOrders'] ?? 0}',
                  color: Colors.blue,
                ),
                _ReportCard(
                  label: 'بانتظار',
                  value: '${reports['pendingOrders'] ?? 0}',
                  color: Colors.purple,
                ),
                _ReportCard(
                  label: 'إجمالي المبيعات',
                  value:
                      '${((reports['totalSales'] as num?) ?? 0).toInt().toPrice()} د.ع',
                  color: const Color(0xFF007A7A),
                ),
                _ReportCard(
                  label: 'كاش محصّل',
                  value:
                      '${((reports['codCollected'] as num?) ?? 0).toInt().toPrice()} د.ع',
                  color: Colors.teal,
                ),
                _ReportCard(
                  label: 'التجار',
                  value:
                      '${reports['openMerchants'] ?? 0}/${reports['totalMerchants'] ?? 0}',
                  color: Colors.indigo,
                ),
                _ReportCard(
                  label: 'المنتجات / المستخدمون',
                  value:
                      '${reports['totalProducts'] ?? 0} / ${reports['totalUsers'] ?? 0}',
                  color: Colors.brown,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'آخر الطلبات',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            ..._recentOrders(reports).map(
              (order) => _RecentOrderTile(order: order),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: Colors.black87,
                onPressed: provider.resetAll,
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _recentOrders(Map<String, dynamic> reports) {
    final raw = reports['recentOrders'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class _ReportCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ReportCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;

  const _RecentOrderTile({
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلب #${order['orderNumber'] ?? '-'}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${order['merchantStoreName'] ?? order['customerNameAr'] ?? ''}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${((order['price'] as num?) ?? 0).toInt().toPrice()} د.ع',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
