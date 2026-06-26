import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/account_ui.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/app_update_checker.dart';
import '../../../utils/guest_gate.dart';
import '../../../widgets/account/account_page_header.dart';

/// واجهة حساب الزائر — تصميم iOS حديث يشجّع على تسجيل الدخول.
class GuestAccountView extends StatelessWidget {
  const GuestAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationCount =
        context.watch<AppProvider>().unreadNotificationCount;

    return Scaffold(
      backgroundColor: accountBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountPageHeader(notificationCount: notificationCount),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 8,
                      ),
                      child: Center(
                        child: _GuestMainCard(
                          onLogin: () => GuestGate.exitGuestToLogin(context),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestMainCard extends StatelessWidget {
  final VoidCallback onLogin;

  const _GuestMainCard({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
      decoration: AccountUi.cardDecoration(radius: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _GuestIllustration(),
          const SizedBox(height: 32),
          const Text(
            'سجل دخولك الآن',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: accountHeadline,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'سجل دخولك للاستمتاع بتجربة تسوق أفضل\n'
            'ومتابعة طلباتك وحفظ عناوينك المفضلة',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: accountBodyGray,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 36),
          _GuestLoginButton(onPressed: onLogin),
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 8),
            onPressed: () => AppUpdateChecker.checkAndPrompt(context),
            child: const Text(
              'التحقق من تحديث التطبيق',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE84A3A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestIllustration extends StatelessWidget {
  const _GuestIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE8F0FE).withValues(alpha: 0.95),
                  const Color(0xFFF3F4F6).withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 22,
            child: _DecorDot(
              size: 10,
              color: Colors.orange.withValues(alpha: 0.35),
            ),
          ),
          Positioned(
            bottom: 28,
            left: 18,
            child: _DecorDot(
              size: 8,
              color: const Color(0xFF93C5FD).withValues(alpha: 0.55),
            ),
          ),
          Positioned(
            top: 42,
            left: 24,
            child: _DecorDot(
              size: 6,
              color: const Color(0xFFCBD5E1).withValues(alpha: 0.8),
            ),
          ),
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF64748B).withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFE2E8F0),
                        const Color(0xFFCBD5E1).withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.person_fill,
                  size: 46,
                  color: const Color(0xFF64748B).withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorDot extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorDot({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _GuestLoginButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GuestLoginButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            gradient: AccountUi.brandGradient,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: accountBrandRed.withValues(alpha: 0.32),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'تسجيل الدخول',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 10),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
