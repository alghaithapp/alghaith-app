import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/account_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/catalog/marketplace_catalog.dart';
import '../../providers/app_provider.dart';
import '../../utils/platform_key.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_image.dart';
import '../../widgets/app_logo.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  void _refreshAll() {
    final provider = context.read<AppProvider>();
    provider.refreshAdminReports();
    provider.refreshAllMerchants();
    provider.refreshAllCouriers();
    provider.refreshHomeCategoriesConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final reports = provider.adminReports ?? const {};
    final merchants = provider.allMerchants;
    final couriers = provider.allCouriers;

    final pendingMerchants = merchants.where((m) =>
      m['isApproved'] != true && (m['approvalStatus']?.toString() ?? 'pending') == 'pending'
    ).length;

    final pendingCouriers = couriers.where((c) =>
      c['isApproved'] != true && (c['approvalStatus']?.toString() ?? 'pending') == 'pending'
    ).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: AppLogo(size: 28),
        ),
        title: const Text(
          'مركز التحكم',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1A1A1A)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          isScrollable: true,
          tabs: [
            const Tab(text: 'نظرة عامة', icon: Icon(Icons.dashboard_rounded, size: 20)),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('التجار'),
                  if (pendingMerchants > 0) ...[
                    const SizedBox(width: 6),
                    _CountBadge(count: pendingMerchants, color: Colors.red),
                  ]
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('المندوبين'),
                  if (pendingCouriers > 0) ...[
                    const SizedBox(width: 6),
                    _CountBadge(count: pendingCouriers, color: Colors.red),
                  ]
                ],
              ),
            ),
            const Tab(text: 'الأقسام', icon: Icon(Icons.grid_view_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(reports: reports),
          const _MerchantManagementTab(),
          const _CourierManagementTab(),
          const _HomeCategoriesTab(),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});

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

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> reports;
  const _OverviewTab({required this.reports});

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
                child: _MetricCard(
                  label: 'إجمالي المبيعات',
                  value: '${salesTotal.toPrice()} د.ع',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF007A7A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
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
              _StatTile(
                label: 'إجمالي الطلبات',
                value: '${reports['totalOrders'] ?? 0}',
                icon: Icons.shopping_bag_rounded,
                color: Colors.deepOrange,
              ),
              _StatTile(
                label: 'طلبات مكتملة',
                value: '${reports['completedOrders'] ?? 0}',
                icon: Icons.check_circle_rounded,
                color: Colors.green,
              ),
              _StatTile(
                label: 'قيد التوصيل',
                value: '${reports['deliveringOrders'] ?? 0}',
                icon: Icons.motorcycle_rounded,
                color: Colors.blue,
              ),
              _StatTile(
                label: 'بانتظار الموافقة',
                value: '${reports['pendingOrders'] ?? 0}',
                icon: Icons.hourglass_empty_rounded,
                color: Colors.amber.shade800,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _HeaderWithAction(title: 'آخر التحركات'),
          const SizedBox(height: 10),
          ..._recentOrders(reports).map((order) => _ModernOrderTile(order: order)),

          const SizedBox(height: 32),
          _ModernWideButton(
            label: 'التبديل لحساب الزبون',
            icon: Icons.person_search_rounded,
            onTap: () => provider.setUserRole('customer'),
            color: const Color(0xFF1A1A1A),
          ),
          const SizedBox(height: 12),
          _ModernWideButton(
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

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 12,
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

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
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

class _HeaderWithAction extends StatelessWidget {
  final String title;
  const _HeaderWithAction({required this.title});

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

class _ModernOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  const _ModernOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2F2F2)),
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

class _ModernWideButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool isOutlined;

  const _ModernWideButton({
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

class _MerchantManagementTab extends StatefulWidget {
  const _MerchantManagementTab();

  @override
  State<_MerchantManagementTab> createState() => _MerchantManagementTabState();
}

class _MerchantManagementTabState extends State<_MerchantManagementTab> {
  String? _busyMerchantPhone;
  String? _busyAction;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final merchants = provider.allMerchants;
    final pending = merchants.where((m) =>
      m['isApproved'] != true && (m['approvalStatus']?.toString() ?? 'pending') == 'pending'
    ).toList();
    final approved = merchants.where((m) => m['isApproved'] == true).toList();
    final others = merchants.where((m) =>
      m['isApproved'] != true && (m['approvalStatus']?.toString() ?? 'pending') != 'pending'
    ).toList();

    return RefreshIndicator(
      onRefresh: () async => provider.refreshAllMerchants(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pending.isNotEmpty) ...[
            const _SectionHeader(title: 'طلبات انضمام جديدة', color: Colors.red),
            const SizedBox(height: 12),
            ...pending.map((m) => _ModernMerchantCard(
              merchant: m,
              isBusy: _busyMerchantPhone == m['phone'],
              busyAction: _busyAction,
              onAction: (action) => _handleAction(provider, m, action),
            )),
            const SizedBox(height: 24),
          ],

          const _SectionHeader(title: 'التجار المعتمدون', color: Colors.green),
          const SizedBox(height: 12),
          if (approved.isEmpty)
            const _EmptyState(text: 'لا يوجد تجار معتمدون حالياً')
          else
            ...approved.map((m) => _ModernMerchantCard(
              merchant: m,
              isBusy: _busyMerchantPhone == m['phone'],
              busyAction: _busyAction,
              onAction: (action) => _handleAction(provider, m, action),
            )),

          if (others.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionHeader(title: 'طلبات أخرى (مرفوضة/متوقفة)', color: Colors.grey),
            const SizedBox(height: 12),
            ...others.map((m) => _ModernMerchantCard(
              merchant: m,
              isBusy: _busyMerchantPhone == m['phone'],
              busyAction: _busyAction,
              onAction: (action) => _handleAction(provider, m, action),
            )),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _handleAction(AppProvider provider, Map m, String action) async {
    final phone = m['phone']?.toString() ?? '';
    if (action == 'approve') {
      setState(() { _busyMerchantPhone = phone; _busyAction = 'approval'; });
      await provider.toggleMerchantApproval(phone, true);
    } else if (action == 'reject') {
      _showRejectDialog(context, provider, m);
    } else if (action == 'freeze') {
      setState(() { _busyMerchantPhone = phone; _busyAction = 'freeze'; });
      await provider.toggleMerchantFrozen(phone, !(m['isFrozen'] == true));
    } else if (action == 'bazaar') {
      setState(() { _busyMerchantPhone = phone; _busyAction = 'bazaar'; });
      await provider.toggleMerchantBazaarMember(phone, !(m['isBazaarMember'] == true));
    }
    setState(() { _busyMerchantPhone = null; _busyAction = null; });
  }

  Future<void> _showRejectDialog(BuildContext context, AppProvider provider, Map merchant) async {
    final controller = TextEditingController();
    final phone = merchant['phone']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الطلب', style: TextStyle(fontFamily: 'Cairo')),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'سبب الرفض'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('رفض')),
        ],
      ),
    );
    if (confirmed == true && controller.text.isNotEmpty) {
      await provider.rejectMerchantApplication(phone, 'custom', rejectionMessageAr: controller.text);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }
}

class _ModernMerchantCard extends StatelessWidget {
  final Map merchant;
  final bool isBusy;
  final String? busyAction;
  final Function(String action) onAction;

  const _ModernMerchantCard({
    required this.merchant,
    required this.isBusy,
    this.busyAction,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isApproved = merchant['isApproved'] == true;
    final isFrozen = merchant['isFrozen'] == true;
    final isBazaar = merchant['isBazaarMember'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isFrozen ? Colors.red.shade100 : const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _AvatarPreview(imageBase64: merchant['profileImageBase64'] ?? merchant['logoImageBase64']),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(merchant['storeName'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    Text(merchant['phone'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              _StatusBadge(
                label: isApproved ? 'مفعّل' : (merchant['approvalStatus'] == 'rejected' ? 'مرفوض' : 'معلق'),
                color: isApproved ? Colors.green : (merchant['approvalStatus'] == 'rejected' ? Colors.red : Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!isApproved) ...[
                Expanded(child: _QuickActionBtn(label: 'موافقة', icon: Icons.check, color: Colors.green, onTap: () => onAction('approve'))),
                const SizedBox(width: 8),
                Expanded(child: _QuickActionBtn(label: 'رفض', icon: Icons.close, color: Colors.red, onTap: () => onAction('reject'))),
              ] else ...[
                Expanded(child: _QuickActionBtn(
                  label: isFrozen ? 'فك تجميد' : 'تجميد',
                  icon: isFrozen ? Icons.lock_open : Icons.lock_person,
                  color: Colors.red,
                  onTap: () => onAction('freeze'),
                  isLoading: isBusy && busyAction == 'freeze',
                )),
                const SizedBox(width: 8),
                Expanded(child: _QuickActionBtn(
                  label: isBazaar ? 'إزالة بازار' : 'تفعيل بازار',
                  icon: Icons.storefront,
                  color: Colors.teal,
                  onTap: () => onAction('bazaar'),
                  active: isBazaar,
                  isLoading: isBusy && busyAction == 'bazaar',
                )),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool active;
  final bool isLoading;

  const _QuickActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.active = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const CupertinoActivityIndicator(radius: 8)
            else
              Icon(icon, size: 14, color: active ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.white : color)),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) => Center(child: Text(text, style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo')));
}

class _AvatarPreview extends StatelessWidget {
  final String? imageBase64;
  const _AvatarPreview({this.imageBase64});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AppImage(imageData: imageBase64),
      ),
    );
  }
}

class _CourierManagementTab extends StatefulWidget {
  const _CourierManagementTab();
  @override
  State<_CourierManagementTab> createState() => _CourierManagementTabState();
}

class _CourierManagementTabState extends State<_CourierManagementTab> {
  String? _busyCourierPhone;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final couriers = provider.allCouriers;
    final pending = couriers.where((c) => c['isApproved'] != true && (c['approvalStatus'] == 'pending')).toList();
    final approved = couriers.where((c) => c['isApproved'] == true).toList();

    return RefreshIndicator(
      onRefresh: () async => provider.refreshAllCouriers(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pending.isNotEmpty) ...[
            const _SectionHeader(title: 'مناديب بانتظار التفعيل', color: Colors.orange),
            const SizedBox(height: 12),
            ...pending.map((c) => _ModernCourierCard(
              courier: c,
              isBusy: _busyCourierPhone == c['phone'],
              onAction: (action) => _handleAction(provider, c, action),
            )),
            const SizedBox(height: 24),
          ],
          const _SectionHeader(title: 'المناديب النشطون', color: Colors.blue),
          const SizedBox(height: 12),
          ...approved.map((c) => _ModernCourierCard(
            courier: c,
            isBusy: _busyCourierPhone == c['phone'],
            onAction: (action) => _handleAction(provider, c, action),
          )),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _handleAction(AppProvider provider, Map c, String action) async {
    final phone = c['phone']?.toString() ?? '';
    setState(() => _busyCourierPhone = phone);
    if (action == 'approve') {
      await provider.toggleCourierApproval(phone, true);
    } else if (action == 'stop') {
      await provider.toggleCourierApproval(phone, false);
    }
    setState(() => _busyCourierPhone = null);
  }
}

class _ModernCourierCard extends StatelessWidget {
  final Map courier;
  final bool isBusy;
  final Function(String action) onAction;

  const _ModernCourierCard({required this.courier, required this.isBusy, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final isApproved = courier['isApproved'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Color(0xFFF0F2F5), child: Icon(Icons.motorcycle, size: 20, color: Colors.blueGrey)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(courier['name'] ?? 'مندوب', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(courier['phone'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ),
          if (isBusy)
            const CupertinoActivityIndicator()
          else
            _QuickActionBtn(
              label: isApproved ? 'إيقاف' : 'تفعيل',
              icon: isApproved ? Icons.block : Icons.check,
              color: isApproved ? Colors.red : Colors.green,
              onTap: () => onAction(isApproved ? 'stop' : 'approve'),
            ),
        ],
      ),
    );
  }
}

class _HomeCategoriesTab extends StatelessWidget {
  const _HomeCategoriesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final categories = MarketplaceCatalog.toggleableHomeCategories;

    return RefreshIndicator(
      onRefresh: () async => provider.refreshHomeCategoriesConfig(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(child: Text('تحكم في ظهور الأقسام الرئيسية للزبائن على أندرويد وآيفون.', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...categories.map((c) => _CategoryPlatformToggle(categoryId: c.id, title: c.titleAr)),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _CategoryPlatformToggle extends StatelessWidget {
  final String categoryId;
  final String title;
  const _CategoryPlatformToggle({required this.categoryId, required this.title});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900)),
          Row(
            children: [
              const Text('أندرويد', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Switch.adaptive(
                value: provider.homeCategoryEnabledOnPlatform(categoryId, PlatformKey.android),
                onChanged: (v) => provider.setHomeCategoryPlatformEnabled(categoryId, PlatformKey.android, v),
              ),
              const SizedBox(width: 20),
              const Text('آيفون', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Switch.adaptive(
                value: provider.homeCategoryEnabledOnPlatform(categoryId, PlatformKey.ios),
                onChanged: (v) => provider.setHomeCategoryPlatformEnabled(categoryId, PlatformKey.ios, v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
