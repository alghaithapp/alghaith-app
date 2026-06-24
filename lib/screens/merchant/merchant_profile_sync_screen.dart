import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/helpers.dart';
import 'merchant_setup_screen.dart';

/// تظهر عندما تكون بيانات المتجر محلياً لكن لم تُؤكَّد على السيرفر بعد.
class MerchantProfileSyncScreen extends StatefulWidget {
  const MerchantProfileSyncScreen({super.key});

  @override
  State<MerchantProfileSyncScreen> createState() =>
      _MerchantProfileSyncScreenState();
}

class _MerchantProfileSyncScreenState extends State<MerchantProfileSyncScreen> {
  bool _isSubmitting = false;

  Future<void> _resubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final submitted =
          await context.read<AppProvider>().resubmitMerchantProfileToServer();
      if (!mounted) return;
      if (submitted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إرسال طلبك للسيرفر بنجاح. سيظهر لدى الإدارة قريباً.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('StateError: ', ''),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final storeName = provider.merchantStoreName;
    final isProfessional =
        provider.merchantServiceIds.contains('professionals') ||
            provider.merchantActiveServiceId == 'professionals';
    final profileLabel = isProfessional ? 'ملف المهنة' : 'متجر';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'إرسال الطلب للإدارة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.cloud_upload_rounded,
            size: 72,
            color: Colors.orange.shade800,
          ),
          const SizedBox(height: 24),
          const Text(
            'لم يصل طلبك للسيرفر بعد',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            storeName.isNotEmpty
                ? 'بيانات $profileLabel "$storeName" محفوظة على جهازك فقط، ولم تُسجَّل بعد في نظام الإدارة.'
                : 'بياناتك محفوظة على جهازك فقط، ولم تُسجَّل بعد في نظام الإدارة.',
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
            'اضغط الزر أدناه لإرسال بياناتك إلى السيرفر. بعد التأكيد ستظهر شاشة انتظار الموافقة ولن يصل طلبك للإدارة إلا بعد ذلك.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              height: 1.65,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _resubmit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _isSubmitting
                  ? 'جارٍ الإرسال...'
                  : 'إعادة إرسال البيانات للسيرفر',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
              isProfessional ? 'تعديل بيانات المهنة' : 'تعديل بيانات المتجر',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF145B66),
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
              'مرحباً، أحتاج مساعدة في إرسال طلب تاجر للسيرفر.',
            ),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text(
              'تواصل مع الدعم',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
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
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
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
    );
  }
}
