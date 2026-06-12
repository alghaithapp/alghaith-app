import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'app_logo.dart';

class StartupSplashScreen extends StatelessWidget {
  const StartupSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StartupSplashView();
  }
}

class _StartupSplashView extends StatelessWidget {
  const _StartupSplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FBFB), Color(0xFFEAF3F3), Color(0xFFDDEDED)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -70,
              child: _BlurBlob(
                size: 240,
                colors: const [Color(0xFFFFE6BF), AppColors.accent],
              ),
            ),
            Positioned(
              bottom: -100,
              right: -80,
              child: _BlurBlob(
                size: 250,
                colors: const [Color(0xFFB9DEE0), AppColors.primary],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BackdropPainter(),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            blurRadius: 30,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: const Color(0xFFE2ECEC),
                              ),
                            ),
                            child: const AppLogo(size: 108),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'منصة عراقية للخدمات والتسوق المحلي في مكان واحد',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo',
                              color: Color(0xFF5A6B6E),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.accentDark,
                                    AppColors.accent,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.22),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'جارٍ تجهيز حسابك...',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                              color: Color(0xFF5A6B6E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _BlurBlob({
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
        gradient: RadialGradient(
          colors: [
            colors.first.withValues(alpha: 0.42),
            colors.last.withValues(alpha: 0.08),
          ],
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.06)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final skylinePath = Path()
      ..moveTo(0, size.height * 0.74)
      ..lineTo(size.width * 0.09, size.height * 0.74)
      ..lineTo(size.width * 0.09, size.height * 0.69)
      ..lineTo(size.width * 0.13, size.height * 0.69)
      ..lineTo(size.width * 0.13, size.height * 0.75)
      ..lineTo(size.width * 0.20, size.height * 0.75)
      ..lineTo(size.width * 0.20, size.height * 0.63)
      ..lineTo(size.width * 0.24, size.height * 0.63)
      ..lineTo(size.width * 0.24, size.height * 0.71)
      ..lineTo(size.width * 0.31, size.height * 0.71)
      ..lineTo(size.width * 0.31, size.height * 0.61)
      ..lineTo(size.width * 0.38, size.height * 0.61)
      ..lineTo(size.width * 0.38, size.height * 0.76)
      ..lineTo(size.width * 0.45, size.height * 0.76)
      ..lineTo(size.width * 0.45, size.height * 0.66)
      ..lineTo(size.width * 0.51, size.height * 0.66)
      ..lineTo(size.width * 0.51, size.height * 0.73)
      ..lineTo(size.width * 0.58, size.height * 0.73)
      ..lineTo(size.width * 0.58, size.height * 0.59)
      ..lineTo(size.width * 0.66, size.height * 0.59)
      ..lineTo(size.width * 0.66, size.height * 0.74)
      ..lineTo(size.width * 0.73, size.height * 0.74)
      ..lineTo(size.width * 0.73, size.height * 0.65)
      ..lineTo(size.width * 0.79, size.height * 0.65)
      ..lineTo(size.width * 0.79, size.height * 0.72)
      ..lineTo(size.width * 0.88, size.height * 0.72)
      ..lineTo(size.width * 0.88, size.height * 0.62)
      ..lineTo(size.width * 0.94, size.height * 0.62)
      ..lineTo(size.width * 0.94, size.height * 0.74)
      ..lineTo(size.width, size.height * 0.74);
    canvas.drawPath(skylinePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
