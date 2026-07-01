import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';

class AppUpdateTab extends StatefulWidget {
  const AppUpdateTab({super.key});
  @override
  State<AppUpdateTab> createState() => _AppUpdateTabState();
}

class _AppUpdateTabState extends State<AppUpdateTab> {
  final _minBuildCtrl = TextEditingController();
  final _iosCtrl = TextEditingController();
  final _androidCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final admin = context.read<AppProvider>().admin;
    await admin.refreshAppUpdatePolicy();
    if (!mounted) return;
    final p = admin.appUpdatePolicy ?? {};
    _minBuildCtrl.text = (p['minBuildNumber']?.toString() ?? '1');
    _iosCtrl.text = (p['iosStoreUrl']?.toString() ?? '');
    _androidCtrl.text = (p['androidStoreUrl']?.toString() ?? '');
    setState(() {});
  }

  @override
  void dispose() {
    _minBuildCtrl.dispose();
    _iosCtrl.dispose();
    _androidCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final admin = context.read<AppProvider>().admin;
    setState(() => _saving = true);
    try {
      await admin.saveAppUpdatePolicy({
        'minBuildNumber': int.tryParse(_minBuildCtrl.text.trim()) ?? 1,
        if (_iosCtrl.text.trim().isNotEmpty) 'iosStoreUrl': _iosCtrl.text.trim(),
        if (_androidCtrl.text.trim().isNotEmpty) 'androidStoreUrl': _androidCtrl.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات التحديث', style: TextStyle(fontFamily: 'Cairo'))),
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
    final policy = context.watch<AppProvider>().admin.appUpdatePolicy;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('تحديث التطبيق', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 4),
        Text('الحد الأدنى لرقم البناء — الإصدارات الأقل سترى شاشة "يجب التحديث"', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 20),
        _field('رقم البناء الأدنى (minBuildNumber)', _minBuildCtrl, isDark: isDark),
        const SizedBox(height: 12),
        _field('رابط App Store (iOS)', _iosCtrl, isDark: isDark, hint: 'https://apps.apple.com/...'),
        const SizedBox(height: 12),
        _field('رابط Google Play (Android)', _androidCtrl, isDark: isDark, hint: 'https://play.google.com/...'),
        if (policy != null && policy['minBuildNumber'] != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.grey.shade800 : Colors.blue.shade50).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'الإعدادات الحالية: أقل بناء ${policy['minBuildNumber']}، التحديث إلزامي: ${policy['forceUpdate'] == true ? 'نعم' : 'لا'}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
              )),
            ]),
          ),
        ],
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

  Widget _field(String label, TextEditingController ctrl, {required bool isDark, String? hint}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo'),
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      style: TextStyle(fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black, fontSize: 14),
    );
  }
}
