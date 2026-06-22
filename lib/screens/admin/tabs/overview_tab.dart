import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/extensions.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const CountBadge({super.key, required this.count, required this.color});

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
  const OverviewTab({super.key, required this.reports});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isEmpty = reports.isEmpty;

    return RefreshIndicator(
      onRefresh: () async => provider.refreshAdminReports(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isEmpty) _buildEmptyState(provider),
          if (!isEmpty) ...[
            _buildTopRow(),
            const SizedBox(height: 16),
            _buildOrderStatsGrid(),
            const SizedBox(height: 16),
            _buildPlatformStatsRow(),
            const SizedBox(height: 16),
            _buildFinanceRow(),
            if (_topMerchants.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionHeader('أفضل التجار', Icons.emoji_events_rounded, AppColors.accent),
              const SizedBox(height: 10),
              ..._topMerchants.map((m) => _TopMerchantTile(merchant: m)),
            ],
            const SizedBox(height: 24),
            _buildSectionHeader('آخر الطلبات', Icons.receipt_long_rounded, AppColors.primary),
            const SizedBox(height: 10),
            ..._recentOrders.map((order) => ModernOrderTile(order: order)),
            const SizedBox(height: 24),
            const SizedBox(height: 32),
            ModernWideButton(
              label: 'التبديل لحساب الزبون',
              icon: Icons.person_search_rounded,
              onTap: () async {
                final p = context.read<AppProvider>();
                final ok = await p.setUserRole('customer');
                if (ok && context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر التبديل لحساب الزبون حالياً.', style: TextStyle(fontFamily: 'Cairo'))),
                  );
                }
              },
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
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            provider.adminReportsError ?? 'جاري تحميل البيانات أو تعذر الاتصال بالسيرفر. اسحب للأسفل للتحديث.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', color: Colors.red.shade700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => provider.refreshAdminReports(),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      children: [
        Expanded(child: MetricCard(
          label: 'إجمالي المبيعات',
          value: '${_int('totalSales').toPrice()} د.ع',
          icon: Icons.payments_rounded,
          color: const Color(0xFF007A7A),
        )),
        const SizedBox(width: 12),
        Expanded(child: MetricCard(
          label: 'كاش محصّل',
          value: '${_int('codCollected').toPrice()} د.ع',
          icon: Icons.account_balance_wallet_rounded,
          color: Colors.blue.shade700,
        )),
      ],
    );
  }

  Widget _buildOrderStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: [
        StatTile(label: 'كل الطلبات', value: '${_int('totalOrders')}', icon: Icons.shopping_bag_rounded, color: Colors.deepOrange),
        StatTile(label: 'مكتملة', value: '${_int('completedOrders')}', icon: Icons.check_circle_rounded, color: Colors.green),
        StatTile(label: 'قيد التوصيل', value: '${_int('deliveringOrders')}', icon: Icons.motorcycle_rounded, color: Colors.blue),
        StatTile(label: 'معلقة', value: '${_int('pendingOrders')}', icon: Icons.hourglass_empty_rounded, color: Colors.amber.shade800),
        StatTile(label: 'ملغية', value: '${_int('cancelledOrders')}', icon: Icons.cancel_rounded, color: Colors.red.shade400),
        StatTile(label: 'متوسط الطلب', value: '${_int('avgOrderValue').toPrice()} د.ع', icon: Icons.trending_up_rounded, color: Colors.teal),
        StatTile(label: 'نمو الإيرادات', value: '${_int('revenueGrowth')}%', icon: Icons.trending_up_rounded, color: _int('revenueGrowth') >= 0 ? Colors.green : Colors.red),
        StatTile(label: 'إيرادات الأسبوع', value: '${_int('recentRevenue').toPrice()} د.ع', icon: Icons.date_range_rounded, color: Colors.indigo),
      ],
    );
  }

  Widget _buildPlatformStatsRow() {
    return Row(
      children: [
        Expanded(child: MiniStatCard(label: 'التجار', value: '${_int('totalMerchants')}', sub: '${_int('openMerchants')} مفتوح', color: AppColors.primary)),
        const SizedBox(width: 8),
        Expanded(child: MiniStatCard(label: 'المندوبين', value: '${_int('totalCouriers')}', sub: '${_int('totalCouriers')} مسجل', color: Colors.orange.shade700)),
        const SizedBox(width: 8),
        Expanded(child: MiniStatCard(label: 'السائقين', value: '${_int('totalDrivers')}', sub: '${_int('totalDrivers')} مسجل', color: Colors.purple.shade700)),
        const SizedBox(width: 8),
        Expanded(child: MiniStatCard(label: 'المستخدمين', value: '${_int('totalUsers')}', sub: '${_int('activeUsersCount')} نشط', color: Colors.teal.shade700)),
      ],
    );
  }

  Widget _buildFinanceRow() {
    return Row(
      children: [
        Expanded(child: MiniStatCard(label: 'المجمدون', value: '${_int('frozenMerchants')}', sub: 'تاجر', color: Colors.red.shade600)),
        const SizedBox(width: 8),
        Expanded(child: MiniStatCard(label: 'بانتظار الموافقة', value: '${_int('pendingMerchantsCount')}', sub: 'تاجر', color: Colors.amber.shade700)),
        const SizedBox(width: 8),
        Expanded(child: MiniStatCard(label: 'المنتجات', value: '${_int('totalProducts')}', sub: 'منتج', color: Colors.blueGrey)),
        const SizedBox(width: 8),
        Expanded(child: MiniStatCard(label: 'مشرفين', value: '${_int('totalAdminAccounts')}', sub: 'حساب', color: Colors.deepPurple)),
      ],
    );
  }

  int _int(String key) => (reports[key] as num?)?.toInt() ?? 0;

  List<Map<String, dynamic>> get _recentOrders {
    final raw = reports['recentOrders'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).take(5).toList();
  }

  List<Map<String, dynamic>> get _topMerchants {
    final raw = reports['topMerchants'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 17)),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const MetricCard({super.key, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700)),
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
  const StatTile({super.key, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white : null)),
          Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: isDark ? Colors.grey.shade400 : Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const MiniStatCard({super.key, required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.85), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontFamily: 'Cairo', fontSize: 9, fontWeight: FontWeight.w700)),
          Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontFamily: 'Cairo', fontSize: 8, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _TopMerchantTile extends StatelessWidget {
  final Map<String, dynamic> merchant;
  const _TopMerchantTile({required this.merchant});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFF2F2F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.store_rounded, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              merchant['storeName'] ?? '',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : null),
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${((merchant['revenue'] as num?) ?? 0).toInt().toPrice()} د.ع',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.accent)),
            Text('${merchant['orderCount'] ?? 0} طلب', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ],
      ),
    );
  }
}

class ModernOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  const ModernOrderTile({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFF2F2F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F6F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.blueGrey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('طلب #${order['orderNumber'] ?? '-'}',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : null)),
              Text('${order['merchantStoreName'] ?? order['customerNameAr'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${((order['price'] as num?) ?? 0).toInt().toPrice()} د.ع',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.accent)),
            const Text('قبل قليل', style: TextStyle(fontSize: 9, color: Colors.grey)),
          ]),
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
    super.key,
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
          boxShadow: isOutlined ? null : [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
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
                Text(label, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: isOutlined ? color : Colors.white, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
