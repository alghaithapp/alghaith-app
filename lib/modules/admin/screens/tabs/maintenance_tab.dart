import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';

class MaintenanceTab extends StatefulWidget {
  const MaintenanceTab({super.key});
  @override
  State<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends State<MaintenanceTab> {
  final _messageCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final admin = context.read<AppProvider>().admin;
    await admin.refreshMaintenancePolicy();
    if (!mounted) return;
    final p = admin.maintenancePolicy ?? {};
    _messageCtrl.text = (p['maintenanceMessageAr']?.toString() ?? '');
    setState(() {});
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final admin = context.read<AppProvider>().admin;
    setState(() => _saving = true);
    try {
      await admin.saveMaintenancePolicy({
        'enabled': admin.maintenancePolicy?['enabled'] == true,
        if (_messageCtrl.text.trim().isNotEmpty) 'maintenanceMessageAr': _messageCtrl.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات', style: TextStyle(fontFamily: 'Cairo'))),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final admin = context.watch<AppProvider>().admin;
    final policy = admin.maintenancePolicy;
    final enabled = policy?['enabled'] == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('وضع الصيانة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 4),
        Text('عند التفعيل، سيرى جميع المستخدمين شاشة "تحت الصيانة"', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 24),
        SwitchListTile(
          value: enabled,
          onChanged: (v) async {
            try {
              await admin.saveMaintenancePolicy({
                'enabled': v,
                if (_messageCtrl.text.trim().isNotEmpty) 'maintenanceMessageAr': _messageCtrl.text.trim(),
              });
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))),
              );
            }
          },
          title: Text(
            enabled ? 'وضع الصيانة مُفعّل' : 'وضع الصيانة مُعطّل',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: enabled ? Colors.red : (isDark ? Colors.white70 : Colors.black54)),
          ),
          subtitle: Text(
            enabled ? 'جميع المستخدمين سيرون شاشة الصيانة' : 'التطبيق يعمل بشكل طبيعي',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
          ),
          activeColor: Colors.red,
        ),
        const SizedBox(height: 20),
        Text('رسالة الصيانة (للزبائن)', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: _messageCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'اكتب رسالة الصيانة هنا...',
            hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('حفظ الإعدادات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
