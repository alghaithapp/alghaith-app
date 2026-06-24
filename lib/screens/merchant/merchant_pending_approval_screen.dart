import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/notifications/push_notification_service.dart';
import '../../providers/app_provider.dart';
import '../../utils/helpers.dart';
import '../../utils/merchant_profile_fields.dart';
import 'merchant_setup_screen.dart';

class MerchantPendingApprovalScreen extends StatefulWidget {
  const MerchantPendingApprovalScreen({super.key});

  @override
  State<MerchantPendingApprovalScreen> createState() =>
      _MerchantPendingApprovalScreenState();
}

class _MerchantPendingApprovalScreenState
    extends State<MerchantPendingApprovalScreen> with WidgetsBindingObserver {
  bool _isRefreshing = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final phone = context.read<AppProvider>().authPhone;
      if (phone != null && phone.isNotEmpty) {
        unawaited(PushNotificationService.instance.bindToUser(phone));
      }
      unawaited(_refresh(silent: true));
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_refresh(silent: true));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh(silent: true));
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final provider = context.read<AppProvider>();
      final wasApproved = provider.isMerchantApproved;
      await provider.refreshAccountFromCloud();
      if (!provider.isMerchantApproved) {
        await provider.refreshMerchantProfileServerStatus();
      }
      if (!mounted) return;
      final approved = context.read<AppProvider>().isMerchantApproved;
      if (!wasApproved && approved) {
        final isProfessional = context
                .read<AppProvider>()
                .merchantServiceIds
                .contains('professionals') ||
            context.read<AppProvider>().merchantActiveServiceId ==
                'professionals';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isProfessional
                  ? 'تم تفعيل ملف المهنة! مرحباً بك.'
                  : 'تم تفعيل متجرك! مرحباً بك.',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            duration: const Duration(seconds: 5),
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
    final store = provider.merchantStore;
    final storeName = provider.merchantStoreName;
    final isProfessional =
        provider.merchantServiceIds.contains('professionals') ||
            provider.merchantActiveServiceId == 'professionals';
    final isRejected = MerchantProfileFields.isRejected(store);
    final rejectionMessage = MerchantProfileFields.rejectionMessage(store);
    final accountLabel = isProfessional ? 'حساب المهني' : 'حساب التاجر';
    final profileLabel = isProfessional ? 'ملف المهنة' : 'متجر';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          isRejected ? 'طلبك يحتاج تعديلاً' : 'بانتظار الموافقة',
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
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
              isRejected
                  ? Icons.error_outline_rounded
                  : (isProfessional
                      ? Icons.engineering_rounded
                      : Icons.storefront_rounded),
              size: 72,
              color: isRejected ? Colors.red.shade700 : const Color(0xFF145B66),
            ),
            const SizedBox(height: 24),
            Text(
              isRejected
                  ? (isProfessional
                      ? 'يرجى تعديل بيانات ملف المهنة'
                      : 'يرجى تعديل بيانات متجرك')
                  : 'طلبك قيد المراجعة',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              storeName.isNotEmpty
                  ? '$profileLabel "$storeName" ${isRejected ? 'لم يُقبل بعد.' : 'بانتظار موافقة الإدارة.'}'
                  : (isRejected
                      ? 'لم يُقبل طلبك بعد.'
                      : (isProfessional
                          ? 'تم استلام بيانات ملف المهنة بنجاح.'
                          : 'تم استلام بيانات متجرك بنجاح.')),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                height: 1.6,
                color: Colors.grey.shade700,
              ),
            ),
            if (isRejected && rejectionMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  rejectionMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.65,
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                isProfessional
                    ? 'لن يُفعَّل $accountLabel ولا يظهر في قسم المهنيين للزبائن إلا بعد موافقة الإدارة. '
                        'ستصلك إشعار عند التفعيل.'
                    : 'لن يُفعَّل $accountLabel ولا يظهر للزبائن إلا بعد موافقة الإدارة. '
                        'ستصلك إشعار عند التفعيل.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  height: 1.65,
                  color: Colors.grey,
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MerchantSetupScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.edit_rounded),
              label: Text(
                isRejected
                    ? 'تعديل البيانات وإعادة الإرسال'
                    : (isProfessional
                        ? 'تعديل بيانات المهنة'
                        : 'تعديل بيانات المتجر'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    isRejected ? Colors.red.shade700 : const Color(0xFF145B66),
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
                'مرحباً، أنا تاجر وبانتظار موافقة الإدارة على حساب متجري.',
              ),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text(
                'تواصل مع الدعم',
                style:
                    TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF5A01D),
                foregroundColor: const Color(0xFF1A1A1A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                context.read<AppProvider>().setUserRole('customer');
              },
              icon: const Icon(Icons.person_rounded),
              label: const Text(
                'العودة لحساب الزبون',
                style:
                    TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade800,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
