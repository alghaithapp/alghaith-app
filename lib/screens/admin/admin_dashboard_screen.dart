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

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.refreshAdminReports();
      provider.refreshAllMerchants();
    });
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

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'لوحة الإدارة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.red.shade700,
          labelColor: Colors.red.shade700,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'التقارير', icon: Icon(Icons.bar_chart_rounded)),
            Tab(text: 'إدارة التجار', icon: Icon(Icons.store_rounded)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              provider.refreshAdminReports();
              provider.refreshAllMerchants();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReportsTab(reports: reports),
          const _MerchantManagementTab(),
        ],
      ),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  final Map<String, dynamic> reports;

  const _ReportsTab({required this.reports});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return RefreshIndicator(
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
          ..._recentOrders(reports)
              .map((order) => _RecentOrderTile(order: order)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: Colors.blue.shade700,
              onPressed: () => provider.setUserRole('customer'),
              child: const Text(
                'التبديل إلى حساب الزبون',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ),
          const SizedBox(height: 12),
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

    return RefreshIndicator(
      onRefresh: provider.refreshAllMerchants,
      child: merchants.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'لا يوجد تجار مسجلون بعد',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: merchants.length,
              itemBuilder: (context, index) {
                final merchant = merchants[index];
                final phone = merchant['phone']?.toString() ?? '';
                return _MerchantCard(
                  merchant: merchant,
                  isBusy: _busyMerchantPhone == phone,
                  busyAction: _busyAction,
                  onToggleBazaar: () {
                    final enabling = merchant['isBazaarMember'] != true;
                    _handleMerchantAction(
                      merchantPhone: phone,
                      action: 'bazaar',
                      operation: () => provider.toggleMerchantBazaarMember(
                        phone,
                        enabling,
                      ),
                      successMessage: enabling
                          ? (result) {
                              final sync = result is Map
                                  ? result['bazaarProductSync']
                                  : null;
                              if (sync is Map) {
                                final total = sync['totalEligible'] ?? 0;
                                return 'تم تفعيل البازار. $total منتج يظهر '
                                    'في قسم التاجر وفي بازار ومطاعم الغيث.';
                              }
                              return 'تم تفعيل البازار. منتجات التاجر تظهر '
                                  'في قسمه وفي البازار معاً.';
                            }
                          : null,
                    );
                  },
                  onToggleFreeze: () {
                    _handleMerchantAction(
                      merchantPhone: phone,
                      action: 'freeze',
                      operation: () => provider.toggleMerchantFrozen(
                        phone,
                        !(merchant['isFrozen'] == true),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _handleMerchantAction({
    required String merchantPhone,
    required String action,
    required Future<dynamic> Function() operation,
    String Function(dynamic result)? successMessage,
  }) async {
    if (_busyMerchantPhone != null || merchantPhone.isEmpty) return;
    setState(() {
      _busyMerchantPhone = merchantPhone;
      _busyAction = action;
    });
    try {
      final result = await operation();
      if (!mounted) return;
      final message = successMessage?.call(result);
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'فشل التحديث، حاول مجدداً',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyMerchantPhone = null;
          _busyAction = null;
        });
      }
    }
  }
}

class _MerchantCard extends StatelessWidget {
  final Map<String, dynamic> merchant;
  final bool isBusy;
  final String? busyAction;
  final VoidCallback onToggleBazaar;
  final VoidCallback onToggleFreeze;

  const _MerchantCard({
    required this.merchant,
    required this.isBusy,
    required this.busyAction,
    required this.onToggleBazaar,
    required this.onToggleFreeze,
  });

  @override
  Widget build(BuildContext context) {
    final storeName = merchant['storeName']?.toString() ?? '';
    final fullName = merchant['fullName']?.toString() ?? '';
    final phone = merchant['phone']?.toString() ?? '';
    final isBazaarMember = merchant['isBazaarMember'] == true;
    final isOpen = merchant['isOpen'] == true;
    final isFrozen = merchant['isFrozen'] == true;
    final rating = (merchant['rating'] as num?)?.toDouble() ?? 0.0;
    final serviceId = merchant['primaryServiceId']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFrozen
              ? Colors.red.shade200
              : (isBazaarMember ? Colors.amber.shade300 : Colors.grey.shade200),
          width: isFrozen || isBazaarMember ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isFrozen
                      ? Colors.red.shade50
                      : (isBazaarMember
                          ? Colors.amber.shade50
                          : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isFrozen
                      ? Icons.block_rounded
                      : (isBazaarMember ? Icons.verified : Icons.store),
                  color: isFrozen
                      ? Colors.red.shade700
                      : (isBazaarMember ? Colors.amber.shade700 : Colors.grey),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName.isNotEmpty ? storeName : 'متجر بدون اسم',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (fullName.isNotEmpty)
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              if (rating > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.orange),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoBadge(
                label: isFrozen ? 'مجمّد' : (isOpen ? 'مفتوح' : 'مغلق'),
                color: isFrozen
                    ? Colors.red
                    : (isOpen ? Colors.green : Colors.red),
              ),
              if (isFrozen)
                const _InfoBadge(
                  label: 'لا يستقبل طلبات',
                  color: Colors.red,
                ),
              if (serviceId.isNotEmpty)
                _InfoBadge(
                  label: _serviceLabel(serviceId),
                  color: Colors.blue,
                ),
              _InfoBadge(
                label:
                    '${merchant['totalProducts'] ?? 0} منتج منشور',
                color: Colors.deepPurple,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionChip(
                  label: isFrozen ? 'فك التجميد' : 'تجميد الحساب',
                  icon:
                      isFrozen ? Icons.lock_open_rounded : Icons.block_rounded,
                  color: Colors.red,
                  isBusy: isBusy && busyAction == 'freeze',
                  onTap: onToggleFreeze,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionChip(
                  label: isBazaarMember ? 'عضو بازار الغيث' : 'تفعيل البازار',
                  icon: isBazaarMember
                      ? Icons.check_circle
                      : Icons.storefront_rounded,
                  color:
                      isBazaarMember ? Colors.amber.shade700 : Colors.blueGrey,
                  isBusy: isBusy && busyAction == 'bazaar',
                  onTap: onToggleBazaar,
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                phone,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _serviceLabel(String id) {
    switch (id) {
      case 'restaurant':
        return 'مطعم';
      case 'product':
        return 'متجر';
      case 'professionals':
        return 'مهني';
      case 'tourism':
        return 'سياحة';
      case 'beauty':
        return 'تجميل';
      case 'used':
        return 'مستعمل';
      case 'cars':
        return 'سيارات';
      case 'real_estate':
        return 'عقارات';
      default:
        return id;
    }
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isBusy;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isBusy)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
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

  const _RecentOrderTile({required this.order});

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
