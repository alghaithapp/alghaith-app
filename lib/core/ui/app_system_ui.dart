import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// تهيئة شريط الحالة وأزرار النظام السفلية (edge-to-edge) على Android الحديث.
Future<void> configureAppSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );
}

class AppSystemUiScope extends StatelessWidget {
  const AppSystemUiScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final overlayStyle = overlayStyleFor(Theme.of(context).brightness);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: child,
    );
  }
}
