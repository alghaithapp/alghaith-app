import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../widgets/merchant_card.dart';
import '../widgets/section_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';
import '../widgets/detail_stat.dart';

class MerchantManagementTab extends StatefulWidget {
  const MerchantManagementTab();

  @override
  State<MerchantManagementTab> createState() => MerchantManagementTabState();
}

class MerchantManagementTabState extends State<MerchantManagementTab> {
  String? _busyMerchantPhone;
  String? _busyAction;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final merchants = provider.allMerchants;
    final pending = merchants.where((m) {
      if (m['isApproved'] == true) return false;
      final status = m['approvalStatus']?.toString() ?? 'pending';
      return status == 'pending';
    }).toList();
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
            const SectionHeader(title: 'طلبات انضمام جديدة', color: Colors.red),
            const SizedBox(height: 12),
            ...pending.map((m) => MerchantCard(
              merchant: m,
              isBusy: _busyMerchantPhone == m['phone'],
              busyAction: _busyAction,
              onAction: (action) => _handleAction(provider, m, action),
              onTap: () => _showMerchantDetails(context, merchant: m),
            )),
            const SizedBox(height: 24),
          ],

          const SectionHeader(title: 'التجار المعتمدون', color: Colors.green),
          const SizedBox(height: 12),
          if (approved.isEmpty)
            const EmptyState(text: 'لا يوجد تجار معتمدون حالياً')
          else
            ...approved.map((m) => MerchantCard(
              merchant: m,
              isBusy: _busyMerchantPhone == m['phone'],
              busyAction: _busyAction,
              onAction: (action) => _handleAction(provider, m, action),
              onTap: () => _showMerchantDetails(context, merchant: m),
            )),

          if (others.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'طلبات أخرى (مرفوضة/متوقفة)', color: Colors.grey),
            const SizedBox(height: 12),
            ...others.map((m) => MerchantCard(
              merchant: m,
              isBusy: _busyMerchantPhone == m['phone'],
              busyAction: _busyAction,
              onAction: (action) => _handleAction(provider, m, action),
              onTap: () => _showMerchantDetails(context, merchant: m),
            )),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _handleAction(AppProvider provider, Map m, String action) async {
    final phone = m['phone']?.toString() ?? '';
    try {
      if (action == 'approve') {
        setState(() { _busyMerchantPhone = phone; _busyAction = 'approval'; });
        await provider.toggleMerchantApproval(phone, true);
      } else if (action == 'reject') {
        _showRejectDialog(context, provider, m);
        return;
      } else if (action == 'freeze') {
        setState(() { _busyMerchantPhone = phone; _busyAction = 'freeze'; });
        await provider.toggleMerchantFrozen(phone, !(m['isFrozen'] == true));
      } else if (action == 'bazaar') {
        setState(() { _busyMerchantPhone = phone; _busyAction = 'bazaar'; });
        await provider.toggleMerchantBazaarMember(phone, !(m['isBazaarMember'] == true));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشلت العملية: $error', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
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

  void _showMerchantDetails(BuildContext context, {required Map merchant}) {
    final isApproved = merchant['isApproved'] == true;
    final isFrozen = merchant['isFrozen'] == true;
    final isBazaar = merchant['isBazaarMember'] == true;
    final storeName = merchant['storeName']?.toString() ?? 'بدون اسم';
    final fullName = merchant['fullName']?.toString() ?? '';
    final phone = merchant['phone']?.toString() ?? '';
    final serviceId = merchant['primaryServiceId']?.toString() ?? '';
    final description = merchant['description']?.toString() ?? '';
    final rejectionMsg = merchant['rejectionMessageAr']?.toString() ?? '';

    String serviceLabel(String id) {
      switch (id) {
        case 'restaurant': return 'مطعم';
        case 'product': return 'متجر';
        case 'real_estate': return 'عقار';
        case 'professionals': return 'مهني';
        default: return id;
      }
    }

    String formatMoney(int value) {
      return value.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }

    int toInt(String key) => (merchant[key] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scrollCtrl,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeName,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                        ),
                        if (fullName.isNotEmpty)
                          Text(fullName,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
                          ),
                        const SizedBox(height: 4),
                        Text('$phone · ${serviceLabel(serviceId)}',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: isApproved ? 'مفعّل' : (merchant['approvalStatus'] == 'rejected' ? 'مرفوض' : 'معلق'),
                    color: isApproved ? Colors.green : (merchant['approvalStatus'] == 'rejected' ? Colors.red : Colors.orange),
                  ),
                ],
              ),

              // Badges row
              if (isFrozen || isBazaar) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (isFrozen)
                      StatusBadge(label: 'مجمّد', color: Colors.red),
                    if (isBazaar)
                      StatusBadge(label: 'مفعل في البازار', color: Colors.teal),
                  ],
                ),
              ],

              // Description
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(description,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey.shade700),
                ),
              ],

              // Rejection reason
              if (merchant['approvalStatus'] == 'rejected' && rejectionMsg.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(rejectionMsg,
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontFamily: 'Cairo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Stats grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        DetailStat(label: 'إجمالي المنتجات', value: '${toInt('totalProducts')}'),
                        DetailStat(label: 'المنتجات المتاحة', value: '${toInt('availableProducts')}'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        DetailStat(label: 'إجمالي الطلبات', value: '${toInt('totalOrders')}'),
                        DetailStat(label: 'الطلبات المكتملة', value: '${toInt('completedOrders')}'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        DetailStat(label: 'الطلبات المعلقة', value: '${toInt('pendingOrders')}'),
                        DetailStat(label: 'قيد التوصيل', value: '${toInt('deliveringOrders')}'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        DetailStat(label: 'إجمالي الأرباح', value: '${formatMoney(toInt('totalRevenue'))} د.ع', isMoney: true),
                        DetailStat(label: 'التقييم', value: (merchant['rating'] as num?)?.toStringAsFixed(1) ?? '0.0'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
