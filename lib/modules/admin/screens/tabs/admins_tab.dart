import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';

class AdminsTab extends StatefulWidget {
  const AdminsTab({super.key});
  @override
  State<AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<AdminsTab> {
  bool _showInviteForm = false;
  final _phoneCtrl = TextEditingController();
  final _roleCtrl = TextEditingController(text: 'admin');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().admin.refreshAllAdmins();
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _invite(dynamic admin) async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() => _busy = true);
    try {
      await admin.inviteAdmin(phone, role: _roleCtrl.text.trim());
      _phoneCtrl.clear();
      setState(() => _showInviteForm = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إضافة $phone كمشرف', style: const TextStyle(fontFamily: 'Cairo'))),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final admin = context.watch<AppProvider>().admin;
    final admins = admin.allAdmins;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('المشرفون (${admins.length})', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black)),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _showInviteForm = !_showInviteForm),
              icon: Icon(_showInviteForm ? Icons.close : Icons.person_add, size: 18),
              label: Text(_showInviteForm ? 'إلغاء' : 'إضافة مشرف', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            ),
          ],
        ),
        if (_showInviteForm) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            decoration: InputDecoration(
              labelText: 'رقم الهاتف',
              labelStyle: const TextStyle(fontFamily: 'Cairo'),
              filled: true,
              fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black),
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _roleCtrl,
            decoration: InputDecoration(
              labelText: 'الصلاحية (admin / moderator / support)',
              labelStyle: const TextStyle(fontFamily: 'Cairo'),
              filled: true,
              fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : () => _invite(admin),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إضافة مشرف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (admins.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: Text('لا يوجد مشرفون', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey))),
          )
        else
          ...admins.map((a) => _AdminCard(admin: a, isDark: isDark, adminService: admin)),
      ],
    );
  }
}

class _AdminCard extends StatelessWidget {
  final Map<String, dynamic> admin;
  final bool isDark;
  final dynamic adminService;
  const _AdminCard({required this.admin, required this.isDark, required this.adminService});

  @override
  Widget build(BuildContext context) {
    final phone = admin['phone']?.toString() ?? '';
    final name = admin['displayName']?.toString() ?? admin['fullName']?.toString() ?? '';
    final role = admin['role']?.toString() ?? '';
    final perms = (admin['myPermissions'] ?? admin['permissions']);
    final permMap = (perms is Map) ? Map<String, dynamic>.from(perms) : <String, dynamic>{};
    final permList = permMap.entries.where((e) => e.value == true).map((e) {
      switch (e.key) {
        case 'canRegister': return 'تسجيل';
        case 'canApprove': return 'موافقة';
        case 'canDelete': return 'حذف';
        case 'canSuspend': return 'تعليق';
        case 'canManageAdmins': return 'إدارة المشرفين';
        default: return e.key;
      }
    }).join('، ');

    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(radius: 22, backgroundColor: Colors.red.withValues(alpha: 0.1), child: const Icon(Icons.shield, size: 20, color: Colors.red)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (name.isNotEmpty) Flexible(child: Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blue, fontFamily: 'Cairo')),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(phone, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo'), textDirection: TextDirection.ltr),
                  if (permList.isNotEmpty) Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(permList, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'Cairo')),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('إزالة مشرف', style: TextStyle(fontFamily: 'Cairo')),
                    content: Text('إزالة صلاحيات المشرف عن $phone؟', style: const TextStyle(fontFamily: 'Cairo')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إزالة', style: TextStyle(fontFamily: 'Cairo', color: Colors.red))),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  await adminService.removeAdmin(phone);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت إزالة المشرف', style: TextStyle(fontFamily: 'Cairo'))),
                  );
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
