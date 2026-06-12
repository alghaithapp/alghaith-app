import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_update_policy.dart';
import '../providers/app_provider.dart';
import '../screens/force_update_screen.dart';
import '../services/app_update_service.dart';
import 'startup_splash_screen.dart';

/// يبقي شاشة التحميل حتى اكتمال فحص التحديث وجاهزية الحساب معاً.
class AppUpdateGate extends StatefulWidget {
  final Widget Function() buildContent;

  const AppUpdateGate({super.key, required this.buildContent});

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _checkingUpdate = true;
  bool _requiresUpdate = false;
  bool _forceShowContent = false;
  AppUpdatePolicy? _policy;
  String? _storeUrl;
  int _currentBuildNumber = 0;
  String _currentVersionName = '';
  Timer? _bootstrapWatchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapWatchdog = Timer(const Duration(seconds: 35), () {
      if (!mounted || _forceShowContent) return;
      debugPrint('APP_UPDATE_GATE: forcing content after bootstrap timeout');
      setState(() => _forceShowContent = true);
    });
    unawaited(_evaluate());
  }

  @override
  void dispose() {
    _bootstrapWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_evaluate(silent: true));
    }
  }

  Future<void> _evaluate({bool silent = false}) async {
    if (!silent) {
      setState(() => _checkingUpdate = true);
    }
    final result = await AppUpdateService.evaluate();
    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      _requiresUpdate = result.requiresUpdate;
      _policy = result.policy;
      _storeUrl = result.storeUrl;
      _currentBuildNumber = result.currentBuildNumber;
      _currentVersionName = result.currentVersionName;
    });
  }

  bool _isBootstrapping(AppProvider provider) {
    if (_forceShowContent) return false;
    // لا نحجب الواجهة أثناء تسجيل الدخول أو المزامنة الخلفية —
    // هذا كان يسبب شاشة فارغة/رمادية على بعض الهواتف.
    return !provider.isReady || provider.isHydrating;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (_checkingUpdate || _isBootstrapping(provider)) {
      return const StartupSplashScreen();
    }

    if (_requiresUpdate && _policy != null) {
      return ForceUpdateScreen(
        policy: _policy!,
        storeUrl: _storeUrl,
        currentBuildNumber: _currentBuildNumber,
        currentVersionName: _currentVersionName,
      );
    }

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: widget.buildContent(),
    );
  }
}
