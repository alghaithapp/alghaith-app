import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../notifications/services/push_notification_service.dart';
import '../../../providers/app_provider.dart';
import '../../taxi/utils/driver_readiness.dart';
import '../../../utils/driver_profile_fields.dart';
import '../../../utils/helpers.dart';
import '../../../screens/shared/operator_setup_screen.dart';

class DriverPendingApprovalScreen extends StatefulWidget {
  const DriverPendingApprovalScreen({super.key});

  @override
  State<DriverPendingApprovalScreen> createState() =>
      _DriverPendingApprovalScreenState();
}

class _DriverPendingApprovalScreenState
    extends State<DriverPendingApprovalScreen> with WidgetsBindingObserver {
  bool _isRefreshing = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final phone = context.read<AppProvider>().authPhone;
      if (phone != null && phone.isNotEmpty) {
        unawaited(_ensurePushReady(phone));
      }
      unawaited(_refresh(silent: true));
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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

  Future<void> _ensurePushReady(String phone) async {
    try {
      await PushNotificationService.instance.initialize();
      await DriverReadiness.requestNotifications();
      await PushNotificationService.instance.ensureUserBinding(phone);
    } catch (e) {
      debugPrint('driver pending push setup error: $e');
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final provider = context.read<AppProvider>();
      final wasApproved = provider.isDriverApproved;
      await provider.refreshAccountFromCloud();
      if (!mounted) return;
      final approved = context.read<AppProvider>().isDriverApproved;
      if (!wasApproved && approved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تفعيل حساب التكسي! مرحباً بك.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            duration: Duration(seconds: 5),
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
    final profile = provider.driverProfile;
    final name = DriverProfileFields.name(profile);
    final isRejected = DriverProfileFields.isRejected(profile);
    final rejectionMessage = DriverProfileFields.rejectionMessage(profile);

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
                  : Icons.local_taxi_rounded,
              size: 72,
              color: isRejected ? Colors.red.shade700 : Colors.deepOrange,
            ),
            const SizedBox(height: 24),
            Text(
              isRejected ? 'يرجى تعديل بياناتك' : 'طلبك قيد المراجعة',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name.isNotEmpty
                  ? 'مرحباً $name، ${isRejected ? 'لم يُقبل طلبك بعد.' : 'تم استلام بياناتك بنجاح.'}'
                  : (isRejected
                      ? 'لم يُقبل طلبك بعد.'
                      : 'تم استلام بياناتك بنجاح.'),
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
              const Text(
                'لن يُفعَّل حساب التكسي إلا بعد موافقة الإدارة. ستصلك إشعار عند التفعيل.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  height: 1.65,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        color: Colors.deepOrange, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'فعّل الإشعارات الآن',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'حتى تصلك رسالة فور موافقة الإدارة على حسابك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        final phone = provider.authPhone;
                        if (phone == null || phone.isEmpty) return;
                        await DriverReadiness.requestNotifications();
                        await PushNotificationService.instance
                            .ensureUserBinding(phone);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تم تجهيز الإشعارات',
                              style: TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                      ),
                      child: const Text(
                        'تفعيل الإشعارات',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OperatorSetupScreen(role: 'driver'),
                  ),
                );
              },
              icon: const Icon(Icons.edit_rounded),
              label: Text(
                isRejected ? 'تعديل البيانات وإعادة الإرسال' : 'تعديل البيانات',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    isRejected ? Colors.red.shade700 : Colors.deepOrange,
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
                'مرحباً، أنا سائق تكسي وبانتظار موافقة الإدارة على حسابي.',
              ),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text(
                'تواصل مع الدعم',
                style:
                    TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF007A7A),
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
