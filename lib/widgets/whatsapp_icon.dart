import 'package:flutter/material.dart';

class WhatsAppIcon extends StatelessWidget {
  final double size;
  final BoxFit fit;

  const WhatsAppIcon({
    super.key,
    this.size = 24,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/WhatsApp.svg.png',
      width: size,
      height: size,
      fit: fit,
    );
  }
}
