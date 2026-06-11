import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_image.dart';

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
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.refreshAdminReports();
      provider.refreshAllMerchants();
      provider.refreshAllCouriers();
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
            Tab(text: 'مندوبو التوصيل', icon: Icon(Icons.delivery_dining_rounded)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              provider.refreshAdminReports();
              provider.refreshAllMerchants();
              provider.refreshAllCouriers();
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
          const _CourierManagementTab(),
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

class _CourierManagementTab extends StatefulWidget {
  const _CourierManagementTab();

  @override
  State<_CourierManagementTab> createState() => _CourierManagementTabState();
}

class _CourierManagementTabState extends State<_CourierManagementTab> {
  String? _busyCourierPhone;

  Future<void> _handleApproval({
    required String courierPhone,
    required bool enabling,
    required Future<void> Function() operation,
  }) async {
    if (_busyCourierPhone != null || courierPhone.isEmpty) return;
    setState(() => _busyCourierPhone = courierPhone);
    try {
      await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabling
                ? 'تم تفعيل حساب المندوب'
                : 'تم إلغاء تفعيل حساب المندوب',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر تحديث حالة المندوب',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyCourierPhone = null);
    }
  }

  Future<void> _showRejectDialog(
    BuildContext context,
    AppProvider provider,
    Map<String, dynamic> courier,
  ) async {
    final phone = courier['phone']?.toString() ?? '';
    if (phone.isEmpty || _busyCourierPhone != null) return;

    const reasons = <Map<String, String>>[
      {
        'key': 'name',
        'label': 'الاسم غير صحيح — يرجى كتابة الاسم الثلاثي بشكل صحيح',
      },
      {
        'key': 'phone',
        'label': 'رقم الهاتف غير صحيح — يرجى إدخال رقم مفعّل على واتساب',
      },
      {'key': 'address', 'label': 'عنوان السكن غير صحيح أو غير واضح'},
      {'key': 'vehicleImage', 'label': 'صورة الدراجة غير واضحة أو غير مقبولة'},
    ];
    var selectedKey = reasons.first['key']!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'رفض طلب المندوب',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'اختر سبب الرفض. سيصل إشعار للمندوب ليقوم بتعديل بياناته.',
                  style: TextStyle(fontFamily: 'Cairo', height: 1.5),
                ),
                const SizedBox(height: 12),
                ...reasons.map(
                  (reason) => RadioListTile<String>(
                    value: reason['key']!,
                    groupValue: selectedKey,
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedKey = value);
                    },
                    title: Text(
                      reason['label']!,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'تأكيد الرفض',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _busyCourierPhone = phone);
    try {
      await provider.rejectCourierApplication(phone, selectedKey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم رفض الطلب وإرسال إشعار للمندوب',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر رفض طلب المندوب',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyCourierPhone = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final couriers = provider.allCouriers;

    return RefreshIndicator(
      onRefresh: provider.refreshAllCouriers,
      child: couriers.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'لا يوجد مندوبو توصيل مسجلون بعد',
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
              itemCount: couriers.length,
              itemBuilder: (context, index) {
                final courier = couriers[index];
                final phone = courier['phone']?.toString() ?? '';
                return _CourierCard(
                  courier: courier,
                  isBusy: _busyCourierPhone == phone,
                  onToggleApproval: () {
                    final enabling = courier['isApproved'] != true;
                    _handleApproval(
                      courierPhone: phone,
                      enabling: enabling,
                      operation: () => provider.toggleCourierApproval(
                        phone,
                        enabling,
                      ),
                    );
                  },
                  onReject: () => _showRejectDialog(context, provider, courier),
                );
              },
            ),
    );
  }
}

class _CourierCard extends StatelessWidget {
  final Map<String, dynamic> courier;
  final bool isBusy;
  final VoidCallback onToggleApproval;
  final VoidCallback onReject;

  const _CourierCard({
    required this.courier,
    required this.isBusy,
    required this.onToggleApproval,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name = courier['name']?.toString() ?? '—';
    final phone = courier['contactPhone']?.toString() ??
        courier['phone']?.toString() ??
        '—';
    final homeAddress = courier['homeAddress']?.toString() ?? '—';
    final vehicleImage = courier['vehicleImage']?.toString() ?? '';
    final available = courier['available'] != false;
    final isApproved = courier['isApproved'] == true;
    final approvalStatus = courier['approvalStatus']?.toString() ?? '';
    final isRejected = approvalStatus == 'rejected';
    final rejectionMessage = courier['rejectionMessageAr']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproved ? Colors.green.shade300 : Colors.orange.shade300,
          width: isApproved ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
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
                          name,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isApproved
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isApproved
                                ? 'مفعّل'
                                : isRejected
                                    ? 'مرفوض'
                                    : 'بانتظار الموافقة',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isApproved
                                  ? Colors.green.shade800
                                  : isRejected
                                      ? Colors.red.shade800
                                      : Colors.orange.shade800,
                            ),
                          ),
                        ),
                        if (isApproved)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: available
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              available ? 'متاح للتوصيل' : 'غير متاح',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: available
                                    ? Colors.blue.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'صورة الدراجة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              if (vehicleImage.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AppImage(
                    imageData: vehicleImage,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.motorcycle_rounded,
                    color: Colors.grey,
                    size: 36,
                  ),
                ),
            ],
          ),
          if (isRejected && rejectionMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'سبب الرفض: $rejectionMessage',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.red.shade900,
                  height: 1.45,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.home_rounded,
                  size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  homeAddress,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isBusy ? null : onToggleApproval,
                  icon: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CupertinoActivityIndicator(radius: 8),
                        )
                      : Icon(
                          isApproved
                              ? Icons.block_rounded
                              : Icons.verified_rounded,
                        ),
                  label: Text(
                    isApproved ? 'إلغاء التفعيل' : 'موافقة وتفعيل',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isApproved
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (!isApproved) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onReject,
                    icon: const Icon(Icons.cancel_rounded),
                    label: const Text(
                      'رفض الطلب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
