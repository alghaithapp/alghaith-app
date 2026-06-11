import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/helpers.dart';
import 'delivery_setup_screen.dart';

class DeliveryPendingApprovalScreen extends StatefulWidget {
  const DeliveryPendingApprovalScreen({super.key});

  @override
  State<DeliveryPendingApprovalScreen> createState() =>
      _DeliveryPendingApprovalScreenState();
}

class _DeliveryPendingApprovalScreenState
    extends State<DeliveryPendingApprovalScreen> {
  bool _isRefreshing = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_refresh(silent: true));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await context.read<AppProvider>().refreshAccountFromCloud();
      if (!mounted) return;
      final approved = context.read<AppProvider>().isCourierApproved;
      if (approved && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تفعيل حسابك! مرحباً بك.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final name = provider.courierProfile?['name']?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'بانتظار الموافقة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : () => _refresh(),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CupertinoActivityIndicator(radius: 9),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.hourglass_top_rounded,
              size: 72,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 24),
            const Text(
              'طلبك قيد المراجعة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name.isNotEmpty
                  ? 'مرحباً $name، تم استلام بياناتك بنجاح.'
                  : 'تم استلام بياناتك بنجاح.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                height: 1.6,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'لن يُفعَّل حساب مندوب التوصيل إلا بعد موافقة الإدارة من لوحة '
              'التحكم. ستصلك إشعار عند التفعيل.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                height: 1.65,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DeliverySetupScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.edit_rounded),
              label: const Text(
                'تعديل البيانات',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => AppHelpers.launchWhatsApp(
                AppHelpers.supportWhatsAppNumber,
                'مرحباً، أنا مندوب توصيل وبانتظار موافقة الإدارة على حسابي.',
              ),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text(
                'تواصل مع الدعم',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF007A7A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
