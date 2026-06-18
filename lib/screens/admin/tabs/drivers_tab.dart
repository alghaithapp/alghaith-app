import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../widgets/section_header.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/status_badge.dart';
import '../widgets/empty_state.dart';

class DriverManagementTab extends StatefulWidget {
  const DriverManagementTab({super.key});
  @override
  State<DriverManagementTab> createState() => DriverManagementTabState();
}

class DriverManagementTabState extends State<DriverManagementTab> {
  String? _busyDriverPhone;
  String? _busyAction;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final drivers = provider.allDrivers;
    final pending = drivers.where((d) =>
      d['isApproved'] != true && (d['approvalStatus']?.toString() ?? 'pending') == 'pending'
    ).toList();
    final approved = drivers.where((d) => d['isApproved'] == true).toList();

    return RefreshIndicator(
      onRefresh: () async => provider.refreshAllDrivers(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pending.isNotEmpty) ...[
            const SectionHeader(title: 'سائقون بانتظار التفعيل', color: Colors.orange),
            const SizedBox(height: 12),
            ...pending.map((d) => DriverCard(
              driver: d,
              isBusy: _busyDriverPhone == d['phone'],
              busyAction: _busyAction,
              onAction: (action) => _handleAction(provider, d, action),
            )),
            const SizedBox(height: 24),
          ],
          const SectionHeader(title: 'السائقون النشطون', color: Colors.blue),
          const SizedBox(height: 12),
          if (approved.isEmpty)
            const EmptyState(text: 'لا يوجد سائقون معتمدون حالياً')
          else
            ...approved.map((d) => DriverCard(
              driver: d,
              isBusy: _busyDriverPhone == d['phone'],
              busyAction: _busyAction,
              onAction: (action) => _handleAction(provider, d, action),
            )),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _handleAction(AppProvider provider, Map d, String action) async {
    final phone = d['phone']?.toString() ?? '';
    try {
      if (action == 'approve') {
        setState(() { _busyDriverPhone = phone; _busyAction = 'approval'; });
        await provider.toggleDriverApproval(phone, true);
      } else if (action == 'stop') {
        setState(() { _busyDriverPhone = phone; _busyAction = 'stop'; });
        await provider.toggleDriverApproval(phone, false);
      } else if (action == 'reject') {
        _showRejectDialog(context, provider, d);
        return;
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشلت العملية: $error', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
    setState(() { _busyDriverPhone = null; _busyAction = null; });
  }

  Future<void> _showRejectDialog(BuildContext context, AppProvider provider, Map driver) async {
    final controller = TextEditingController();
    final phone = driver['phone']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض طلب السائق', style: TextStyle(fontFamily: 'Cairo')),
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
        await provider.rejectDriverApplication(phone, 'custom', rejectionMessageAr: controller.text);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الرفض: $error', style: const TextStyle(fontFamily: 'Cairo'))),
          );
        }
      }
    }
    setState(() { _busyDriverPhone = null; _busyAction = null; });
    controller.dispose();
  }
}

class DriverCard extends StatelessWidget {
  final Map driver;
  final bool isBusy;
  final String? busyAction;
  final Function(String action) onAction;

  const DriverCard({
    super.key,
    required this.driver,
    required this.isBusy,
    this.busyAction,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isApproved = driver['isApproved'] == true;
    final name = driver['name'] ?? 'سائق';
    final phone = driver['phone'] ?? '';
    final vehicle = driver['vehicle'] ?? '';
    final plate = driver['plate'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFF0F2F5),
                child: Icon(Icons.local_taxi_rounded, size: 20, color: Colors.blueGrey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$name', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  Text('$phone', style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Cairo')),
                  if (vehicle.isNotEmpty)
                    Text('$vehicle | $plate', style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Cairo')),
                ]),
              ),
              StatusBadge(
                label: isApproved ? 'مفعّل' : (driver['approvalStatus'] == 'rejected' ? 'مرفوض' : 'معلق'),
                color: isApproved ? Colors.green : (driver['approvalStatus'] == 'rejected' ? Colors.red : Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isApproved) ...[
                Expanded(child: QuickActionBtn(
                  label: 'موافقة', icon: Icons.check, color: Colors.green,
                  onTap: () => onAction('approve'),
                  isLoading: isBusy && busyAction == 'approval',
                )),
                const SizedBox(width: 8),
                Expanded(child: QuickActionBtn(
                  label: 'رفض', icon: Icons.close, color: Colors.red,
                  onTap: () => onAction('reject'),
                )),
              ] else ...[
                Expanded(child: QuickActionBtn(
                  label: 'إيقاف', icon: Icons.block, color: Colors.red,
                  onTap: () => onAction('stop'),
                  isLoading: isBusy && busyAction == 'stop',
                )),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
