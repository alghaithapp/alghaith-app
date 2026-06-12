import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final BoxFit fit;

  /// نصف قطر تدوير الحواف. افتراضياً نسبة من الحجم لتبدو كأيقونة ناعمة.
  final double? borderRadius;

  const AppLogo({
    super.key,
    this.size = 72,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.24;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: fit,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => Container(
            width: size,
            height: size,
            color: const Color(0xFFEFE7DA),
            alignment: Alignment.center,
            child: Text(
              'الغيث',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: size * 0.22,
                color: const Color(0xFF2A1A17),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
