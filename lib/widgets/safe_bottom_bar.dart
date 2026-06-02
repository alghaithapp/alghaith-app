import 'package:flutter/material.dart';

/// شريط سفلي يحترم منطقة أزرار النظام / إيماءات التنقل.
class SafeBottomBar extends StatelessWidget {
  const SafeBottomBar({
    super.key,
    required this.child,
    this.color,
    this.boxShadow,
    this.topPadding = 8,
  });

  final Widget child;
  final Color? color;
  final List<BoxShadow>? boxShadow;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          boxShadow: boxShadow,
        ),
        padding: EdgeInsets.only(top: topPadding),
        child: child,
      ),
    );
  }
}
