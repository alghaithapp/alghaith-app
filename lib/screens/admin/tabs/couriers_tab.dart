import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../widgets/section_header.dart';
import '../widgets/quick_action_button.dart';

class CourierManagementTab extends StatefulWidget {
  const CourierManagementTab({super.key});
  @override
  State<CourierManagementTab> createState() => CourierManagementTabState();
}

class CourierManagementTabState extends State<CourierManagementTab> {
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
            const SectionHeader(title: 'مناديب بانتظار التفعيل', color: Colors.orange),
            const SizedBox(height: 12),
            ...pending.map((c) => CourierCard(
              courier: c,
              isBusy: _busyCourierPhone == c['phone'],
              onAction: (action) => _handleAction(provider, c, action),
            )),
            const SizedBox(height: 24),
          ],
          const SectionHeader(title: 'المناديب النشطون', color: Colors.blue),
          const SizedBox(height: 12),
          ...approved.map((c) => CourierCard(
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
    try {
      if (action == 'approve') {
        setState(() => _busyCourierPhone = phone);
        await provider.toggleCourierApproval(phone, true);
      } else if (action == 'stop') {
        setState(() => _busyCourierPhone = phone);
        await provider.toggleCourierApproval(phone, false);
      } else if (action == 'reject') {
        _showRejectDialog(context, provider, c);
        return;
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشلت العملية: $error', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
    setState(() => _busyCourierPhone = null);
  }

  Future<void> _showRejectDialog(BuildContext context, AppProvider provider, Map courier) async {
    final controller = TextEditingController();
    final phone = courier['phone']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض طلب المندوب', style: TextStyle(fontFamily: 'Cairo')),
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
      try {
        await provider.rejectCourierApplication(phone, 'custom', rejectionMessageAr: controller.text);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الرفض: $error', style: const TextStyle(fontFamily: 'Cairo'))),
          );
        }
      }
    }
    setState(() => _busyCourierPhone = null);
    controller.dispose();
  }
}

class CourierCard extends StatelessWidget {
  final Map courier;
  final bool isBusy;
  final Function(String action) onAction;

  const CourierCard({super.key, required this.courier, required this.isBusy, required this.onAction});

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
          else if (!isApproved)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                QuickActionBtn(
                  label: 'تفعيل', icon: Icons.check, color: Colors.green,
                  onTap: () => onAction('approve'),
                ),
                const SizedBox(width: 8),
                QuickActionBtn(
                  label: 'رفض', icon: Icons.close, color: Colors.red,
                  onTap: () => onAction('reject'),
                ),
              ],
            )
          else
            QuickActionBtn(
              label: 'إيقاف', icon: Icons.block, color: Colors.red,
              onTap: () => onAction('stop'),
            ),
        ],
      ),
    );
  }
}
