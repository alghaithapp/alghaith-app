import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/app_provider.dart';

/// بوابة موحّدة تتطلب تسجيل الدخول للعمليات الحساسة (التسوق، الشراء، التواصل).
///
/// التصفح متاح بالكامل للزائر، لكن عند محاولة إضافة منتج للسلة أو إتمام
/// الشراء أو التواصل مع تاجر، نطلب منه تسجيل الدخول أولاً.
class GuestGate {
  const GuestGate._();

  /// يخرج من وضع الزائر ويعيد المستخدم إلى شاشة تسجيل الدخول.
  ///
  /// يُفرّغ مكدس التنقّل أولاً لأن تغيير [MaterialApp.home] وحده لا يزيل
  /// الشاشات المفتوحة فوق الشاشة الرئيسية.
  static void exitGuestToLogin(BuildContext context) {
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    provider.resetAll();
  }

  /// يعيد `true` إذا كان المستخدم مسجّلاً للدخول (لديه جلسة هاتف فعلية).
  /// إذا كان زائراً، يعرض نافذة تدعوه لتسجيل الدخول ويعيد `false`.
  static bool requireAccount(
    BuildContext context, {
    String message = 'سجّل دخولك لإتمام هذه الخطوة.',
  }) {
    final provider = context.read<AppProvider>();
    if (provider.hasPhoneSession) {
      return true;
    }
    _showLoginPrompt(context, provider, message);
    return false;
  }

  static void _showLoginPrompt(
    BuildContext context,
    AppProvider provider,
    String message,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _GuestLoginSheet(
          message: message,
          onLogin: () {
            Navigator.of(sheetContext).pop();
            exitGuestToLogin(context);
          },
        );
      },
    );
  }
}

class _GuestLoginSheet extends StatelessWidget {
  final String message;
  final VoidCallback onLogin;

  const _GuestLoginSheet({
    required this.message,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC04A20), Color(0xFFE79031)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'تسجيل الدخول مطلوب',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14.5,
                height: 1.6,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'تسجيل الدخول',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'متابعة التصفح',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
