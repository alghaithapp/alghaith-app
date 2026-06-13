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
      final provider = context.read<AppProvider>();
      provider.refreshAdminReports();
      provider.refreshAllMerchants();
      provider.refreshAllCouriers();
      provider.refreshHomeCategoriesConfig();
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
      backgroundColor: accountBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: AppLogo(size: 28),
        ),
        title: const Text(
          'لوحة الإدارة',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            color: accountHeadline,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accountBrandRed,
          labelColor: accountBrandRed,
          unselectedLabelColor: accountBodyGray,
          indicatorWeight: 3,
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
          tabs: const [
            Tab(text: 'التقارير', icon: Icon(Icons.bar_chart_rounded, size: 20)),
            Tab(text: 'إدارة التجار', icon: Icon(Icons.store_rounded, size: 20)),
            Tab(text: 'المندوبين', icon: Icon(Icons.delivery_dining_rounded, size: 20)),
            Tab(text: 'الأقسام', icon: Icon(Icons.grid_view_rounded, size: 20)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              provider.refreshAdminReports();
              provider.refreshAllMerchants();
              provider.refreshAllCouriers();
            },
            icon: const Icon(Icons.refresh_rounded, color: accountHeadline),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ReportsTab(reports: reports),
          const _MerchantManagementTab(),
          const _CourierManagementTab(),
          const _HomeCategoriesTab(),
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
              color: accountHeadline,
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
              color: accountHeadline,
            ),
          ),
          const SizedBox(height: 10),
          ..._recentOrders(reports)
              .map((order) => _RecentOrderTile(order: order)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: AccountUi.brandGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accountBrandRed.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => provider.setUserRole('customer'),
                  borderRadius: BorderRadius.circular(16),
                  child: const Center(
                    child: Text(
                      'التبديل إلى حساب الزبون',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: CupertinoColors.systemRed.withValues(alpha: 0.1),
              onPressed: provider.resetAll,
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  color: CupertinoColors.systemRed,
                ),
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

  Future<void> _handleMerchantApproval({
    required String merchantPhone,
    required bool enabling,
    required Future<void> Function() operation,
  }) async {
    if (_busyMerchantPhone != null || merchantPhone.isEmpty) return;
    setState(() {
      _busyMerchantPhone = merchantPhone;
      _busyAction = 'approval';
    });
    try {
      await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabling ? 'تم تفعيل الحساب بنجاح' : 'تم إلغاء تفعيل الحساب',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'فشل تحديث الموافقة، حاول مجدداً',
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

  Future<void> _showRejectDialog(
    BuildContext context,
    AppProvider provider,
    Map<String, dynamic> merchant,
  ) async {
    final controller = TextEditingController();
    final phone = merchant['phone']?.toString() ?? '';
    final name = merchant['storeName']?.toString() ??
        merchant['fullName']?.toString() ??
        phone;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('رفض طلب $name', style: const TextStyle(fontFamily: 'Cairo')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض (يظهر للمستخدم)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رفض الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true || controller.text.trim().isEmpty) return;
    await provider.rejectMerchantApplication(
      phone,
      'custom',
      rejectionMessageAr: controller.text.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم رفض الطلب وإرسال السبب للمستخدم'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final merchants = provider.allMerchants;
    final pendingMerchants = merchants.where((merchant) {
      return merchant['isApproved'] != true &&
          (merchant['approvalStatus']?.toString() ?? 'pending') == 'pending';
    }).toList();

    return RefreshIndicator(
      onRefresh: provider.refreshAllMerchants,
      child: merchants.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text(
                    'لا يوجد تجار أو مهنيون مسجلون بعد',
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
              itemCount: merchants.length + (pendingMerchants.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (pendingMerchants.isNotEmpty && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: accountBrandRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accountBrandRed.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        'بانتظار الموافقة: ${pendingMerchants.length} (تجار ومهنيون)',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                          color: accountBrandRed,
                        ),
                      ),
                    ),
                  );
                }
                final merchantIndex =
                    pendingMerchants.isNotEmpty ? index - 1 : index;
                final merchant = merchants[merchantIndex];
                final phone = merchant['phone']?.toString() ?? '';
                return _MerchantCard(
                  merchant: merchant,
                  isBusy: _busyMerchantPhone == phone,
                  busyAction: _busyAction,
                  onToggleApproval: () {
                    final enabling = merchant['isApproved'] != true;
                    _handleMerchantApproval(
                      merchantPhone: phone,
                      enabling: enabling,
                      operation: () => provider.toggleMerchantApproval(
                        phone,
                        enabling,
                      ),
                    );
                  },
                  onReject: () => _showRejectDialog(context, provider, merchant),
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
  final VoidCallback onToggleApproval;
  final VoidCallback onReject;
  final VoidCallback onToggleBazaar;
  final VoidCallback onToggleFreeze;

  const _MerchantCard({
    required this.merchant,
    required this.isBusy,
    required this.busyAction,
    required this.onToggleApproval,
    required this.onReject,
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
    final isApproved = merchant['isApproved'] == true;
    final approvalStatus = merchant['approvalStatus']?.toString() ?? '';
    final isRejected = approvalStatus == 'rejected';
    final rejectionMessage = merchant['rejectionMessageAr']?.toString() ?? '';
    final isProfessional = merchant['isProfessional'] == true ||
        serviceId == 'professionals';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AccountUi.cardDecoration(radius: 22).copyWith(
        border: (isFrozen || isBazaarMember)
            ? Border.all(
                color: isFrozen
                    ? Colors.red.withValues(alpha: 0.3)
                    : accountBrandRed.withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
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
                      ? Colors.red.withValues(alpha: 0.1)
                      : (isBazaarMember
                          ? accountBrandRed.withValues(alpha: 0.1)
                          : accountBackground),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isFrozen
                      ? Icons.block_rounded
                      : (isBazaarMember ? Icons.verified : Icons.store),
                  color: isFrozen
                      ? Colors.red
                      : (isBazaarMember ? accountBrandRed : accountBodyGray),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName.isNotEmpty
                          ? storeName
                          : (isProfessional ? 'مهني بدون اسم' : 'متجر بدون اسم'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: accountHeadline,
                      ),
                    ),
                    if (fullName.isNotEmpty)
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: accountBodyGray,
                          fontWeight: FontWeight.w500,
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
                label: isApproved
                    ? 'مفعّل'
                    : isRejected
                        ? 'مرفوض'
                        : 'بانتظار الموافقة',
                color: isApproved
                    ? Colors.green
                    : isRejected
                        ? Colors.red
                        : accountBrandRed,
              ),
              if (isProfessional)
                const _InfoBadge(label: 'مهني', color: Colors.indigo),
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
          if (isRejected && rejectionMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'سبب الرفض: $rejectionMessage',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.red.shade800,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionChip(
                  label: isApproved ? 'إلغاء التفعيل' : 'موافقة وتفعيل',
                  icon: isApproved
                      ? Icons.cancel_outlined
                      : Icons.verified_rounded,
                  color: isApproved ? Colors.orange : Colors.green,
                  isBusy: isBusy && busyAction == 'approval',
                  onTap: onToggleApproval,
                ),
              ),
              if (!isApproved) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionChip(
                    label: 'رفض الطلب',
                    icon: Icons.close_rounded,
                    color: Colors.red,
                    isBusy: isBusy && busyAction == 'reject',
                    onTap: onReject,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
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
      decoration: AccountUi.cardDecoration(radius: 18).copyWith(
        border: Border.all(color: color.withValues(alpha: 0.15)),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AccountUi.cardDecoration(radius: 16),
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
    final customMessageController = TextEditingController();

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
                  'اكتب سبب الرفض ليظهر للمندوب، أو اختر سبباً جاهزاً ثم عدّله.',
                  style: TextStyle(fontFamily: 'Cairo', height: 1.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: customMessageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'سبب الرفض (يظهر للمستخدم)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...reasons.map(
                  (reason) => RadioListTile<String>(
                    value: reason['key']!,
                    groupValue: selectedKey,
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedKey = value;
                        customMessageController.text = reason['label']!;
                      });
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

    final rejectionMessage = customMessageController.text.trim();
    customMessageController.dispose();

    if (confirmed != true || !mounted) return;
    if (rejectionMessage.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى كتابة سبب الرفض ليظهر للمندوب',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }
    setState(() => _busyCourierPhone = phone);
    try {
      await provider.rejectCourierApplication(
        phone,
        selectedKey,
        rejectionMessageAr: rejectionMessage,
      );
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AccountUi.cardDecoration(radius: 22).copyWith(
        border: Border.all(
          color: isApproved
              ? Colors.green.withValues(alpha: 0.3)
              : accountBrandRed.withValues(alpha: 0.3),
          width: 1.5,
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
                            fontSize: 16,
                            color: accountHeadline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: accountBodyGray,
                            fontWeight: FontWeight.w600,
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
                                ? Colors.green.withValues(alpha: 0.1)
                                : accountBrandRed.withValues(alpha: 0.1),
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
                              fontWeight: FontWeight.w800,
                              color: isApproved
                                  ? Colors.green.shade700
                                  : isRejected
                                      ? Colors.red
                                      : accountBrandRed,
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
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: accountHeadline,
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
              const Icon(Icons.home_rounded, size: 16, color: accountBodyGray),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  homeAddress,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    height: 1.45,
                    color: accountHeadline,
                    fontWeight: FontWeight.w500,
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

class _HomeCategoriesTab extends StatelessWidget {
  const _HomeCategoriesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final categories = MarketplaceCatalog.toggleableHomeCategories;

    return RefreshIndicator(
      onRefresh: () => provider.refreshHomeCategoriesConfig(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accountBrandRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accountBrandRed.withValues(alpha: 0.18),
              ),
            ),
            child: const Text(
              'تحكّم بالأقسام الظاهرة للزبون في الصفحة الرئيسية لكل منصة '
              '(أندرويد / آيفون). التغييرات تُطبّق فور الحفظ.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                height: 1.6,
                color: accountHeadline,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...categories.map((category) {
            return _HomeCategoryPlatformCard(categoryId: category.id, titleAr: category.titleAr);
          }),
        ],
      ),
    );
  }
}

class _HomeCategoryPlatformCard extends StatelessWidget {
  const _HomeCategoryPlatformCard({
    required this.categoryId,
    required this.titleAr,
  });

  final String categoryId;
  final String titleAr;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titleAr,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: accountHeadline,
            ),
          ),
          const SizedBox(height: 8),
          _PlatformToggleRow(
            label: 'أندرويد',
            icon: Icons.android_rounded,
            enabled: provider.homeCategoryEnabledOnPlatform(
              categoryId,
              PlatformKey.android,
            ),
            onChanged: (value) => _savePlatformToggle(
              context,
              provider,
              PlatformKey.android,
              value,
            ),
          ),
          _PlatformToggleRow(
            label: 'آيفون',
            icon: Icons.phone_iphone_rounded,
            enabled: provider.homeCategoryEnabledOnPlatform(
              categoryId,
              PlatformKey.ios,
            ),
            onChanged: (value) => _savePlatformToggle(
              context,
              provider,
              PlatformKey.ios,
              value,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePlatformToggle(
    BuildContext context,
    AppProvider provider,
    String platform,
    bool value,
  ) async {
    final ok = await provider.setHomeCategoryPlatformEnabled(
      categoryId,
      platform,
      value,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذّر حفظ التغيير، تحقق من الاتصال وحاول مجدداً.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    }
  }
}

class _PlatformToggleRow extends StatelessWidget {
  const _PlatformToggleRow({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: accountHeadline, size: 22),
      value: enabled,
      onChanged: onChanged,
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w700,
          color: accountHeadline,
        ),
      ),
      subtitle: Text(
        enabled ? 'ظاهر' : 'مخفي',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
          color: enabled ? Colors.green.shade700 : accountBodyGray,
        ),
      ),
    );
  }
}
