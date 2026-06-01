import 'package:animate_do/animate_do.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'customer_setup_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          const _Backdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                children: [
                  FadeInDown(
                    child: Container(
                      width: 98,
                      height: 98,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: const Color(0xFF121212),
                        border: Border.all(
                          color: const Color(0xFFE53935).withValues(alpha: 0.28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE53935).withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.person_crop_circle_fill,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FadeInDown(
                    delay: const Duration(milliseconds: 80),
                    child: const Text(
                      'اختيار الحساب',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeIn(
                    delay: const Duration(milliseconds: 150),
                    child: const Text(
                      'ابدأ بحساب زبون / تاجر، ثم فعّل حساب التاجر لاحقًا من صفحة حسابي إذا احتجت ذلك',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB8B8B8),
                        fontSize: 14.5,
                        height: 1.7,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeInRight(
                    delay: const Duration(milliseconds: 220),
                    child: _RoleCard(
                      title: 'حساب زبون / تاجر',
                      subtitle:
                          'أنشئ حسابك الشخصي أولًا، ثم يمكنك الانتقال إلى حساب التاجر من داخل صفحة حسابي',
                      icon: CupertinoIcons.person_crop_circle_fill,
                      accentColor: const Color(0xFFE53935),
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const CustomerSetupScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: _RoleCard(
                      title: 'حساب سائق',
                      subtitle: 'لتلقي الطلبات وإدارة حالة السائق',
                      icon: Icons.local_taxi_rounded,
                      accentColor: const Color(0xFF2196F3),
                      onTap: () => appProvider.setUserRole('driver'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeInUp(
                    delay: const Duration(milliseconds: 380),
                    child: _RoleCard(
                      title: 'مندوب توصيل',
                      subtitle: 'لاستلام وتسليم الطلبات ومتابعة المهام',
                      icon: Icons.motorcycle,
                      accentColor: const Color(0xFF00A3A3),
                      onTap: () => appProvider.setUserRole('delivery'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF0F0F0F)),
      child: Stack(
        children: [
          Positioned(
            top: -88,
            left: -64,
            child: _GlowBlob(
              size: 260,
              colors: [
                const Color(0xFFE53935).withValues(alpha: 0.12),
                const Color(0xFFFF8A5A).withValues(alpha: 0.06),
              ],
            ),
          ),
          Positioned(
            bottom: -96,
            right: -72,
            child: _GlowBlob(
              size: 240,
              colors: [
                const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                const Color(0xFFE53935).withValues(alpha: 0.08),
              ],
            ),
          ),
          Positioned(
            top: 120,
            right: -36,
            child: _GlassTile(
              width: 150,
              height: 92,
              rotate: -0.18,
            ),
          ),
          Positioned(
            top: 248,
            left: -24,
            child: _GlassTile(
              width: 124,
              height: 78,
              rotate: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _GlowBlob({
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _GlassTile extends StatelessWidget {
  final double width;
  final double height;
  final double rotate;

  const _GlassTile({
    required this.width,
    required this.height,
    required this.rotate,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.06),
              const Color(0xFFE53935).withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withValues(alpha: 0.24)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accentColor, width: 1.5),
                color: const Color(0xFF121212),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFB6B6B6),
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.12),
              ),
              child: Icon(
                CupertinoIcons.chevron_left,
                color: accentColor,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
