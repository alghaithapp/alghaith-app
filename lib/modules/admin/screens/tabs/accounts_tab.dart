import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';

class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});
  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().admin.refreshAllAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final admin = context.watch<AppProvider>().admin;
    final accounts = admin.allAccounts.where((a) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return (a['phone']?.toString() ?? '').contains(q) ||
          (a['displayName']?.toString() ?? '').toLowerCase().contains(q) ||
          (a['fullName']?.toString() ?? '').toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'ابحث عن حساب أو رقم هاتف...',
            hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: isDark ? Colors.white : Colors.black),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 16),
        if (accounts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Text('لا توجد حسابات مطابقة', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey)),
            ),
          )
        else
          ...accounts.map((a) => _AccountCard(
                account: a,
                isDark: isDark,
                onSuspend: () async {
                  final phone = a['phone']?.toString() ?? '';
                  final current = a['isSuspended'] == true;
                  try {
                    await admin.suspendAccount(phone, !current);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(current ? 'تم فك التعليق' : 'تم تعليق الحساب', style: const TextStyle(fontFamily: 'Cairo'))),
                    );
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))),
                    );
                  }
                },
                onDelete: () async {
                  final phone = a['phone']?.toString() ?? '';
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('حذف الحساب', style: TextStyle(fontFamily: 'Cairo')),
                      content: Text('هل أنت متأكد من حذف الحساب $phone؟', style: const TextStyle(fontFamily: 'Cairo')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  try {
                    await admin.deleteAccount(phone);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف الحساب', style: TextStyle(fontFamily: 'Cairo'))),
                    );
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))),
                    );
                  }
                },
              )),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic> account;
  final bool isDark;
  final VoidCallback onSuspend;
  final VoidCallback onDelete;
  const _AccountCard({required this.account, required this.isDark, required this.onSuspend, required this.onDelete});

  Color _kindColor(String k) {
    switch (k) {
      case 'merchant': return Colors.blue;
      case 'courier': return Colors.orange;
      case 'driver': return Colors.green;
      case 'admin': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _kindIcon(String k) {
    switch (k) {
      case 'merchant': return Icons.store;
      case 'courier': return Icons.delivery_dining;
      case 'driver': return Icons.directions_car;
      case 'admin': return Icons.shield;
      default: return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = account['phone']?.toString() ?? '';
    final name = account['displayName']?.toString() ?? account['fullName']?.toString() ?? '';
    final kind = account['kind']?.toString() ?? account['role']?.toString() ?? '';
    final isSuspended = account['isSuspended'] == true;
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(radius: 22, backgroundColor: _kindColor(kind).withValues(alpha: 0.15), child: Icon(_kindIcon(kind), size: 20, color: _kindColor(kind))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty) Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 2),
                  Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'Cairo'), textDirection: TextDirection.ltr),
                  const SizedBox(height: 4),
                  _KindBadge(kind: kind, isSuspended: isSuspended),
                ],
              ),
            ),
            IconButton(icon: Icon(isSuspended ? Icons.check_circle_outline : Icons.pause_circle_outline, size: 20, color: Colors.orange), onPressed: onSuspend),
            IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  final String kind;
  final bool isSuspended;
  const _KindBadge({required this.kind, required this.isSuspended});

  Color _color(String k) {
    switch (k) {
      case 'merchant': return Colors.blue;
      case 'courier': return Colors.orange;
      case 'driver': return Colors.green;
      case 'admin': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _label(String k) {
    switch (k) {
      case 'merchant': return 'تاجر';
      case 'courier': return 'مندوب';
      case 'driver': return 'سائق';
      case 'admin': return 'مشرف';
      default: return k;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _color(kind).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
          child: Text(_label(kind), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _color(kind), fontFamily: 'Cairo')),
        ),
        if (isSuspended) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: const Text('معلق', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red, fontFamily: 'Cairo')),
          ),
        ],
      ],
    );
  }
}
