import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_update_policy.dart';
import '../models/maintenance_policy.dart';
import '../providers/app_provider.dart';
import '../modules/common/screens/force_update_screen.dart';
import '../modules/common/screens/maintenance_screen.dart';
import '../services/app_update_service.dart';
import '../services/maintenance_service.dart';
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
  bool _inMaintenance = false;
  bool _forceShowContent = false;
  AppUpdatePolicy? _policy;
  MaintenancePolicy? _maintenancePolicy;
  String? _storeUrl;
  int _currentBuildNumber = 0;
  String _currentVersionName = '';
  Timer? _bootstrapWatchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapWatchdog = Timer(const Duration(seconds: 35), () {
      if (!mounted || _forceShowContent || _inMaintenance) return;
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

    final provider = context.read<AppProvider>();
    final isAdmin = provider.isAdmin;

    final results = await Future.wait([
      AppUpdateService.evaluate(),
      MaintenanceService.evaluate(isAdmin: isAdmin),
    ]);

    final updateResult = results[0] as AppUpdateCheckResult;
    final maintenanceResult = results[1] as MaintenanceCheckResult;

    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      _requiresUpdate = updateResult.requiresUpdate;
      _policy = updateResult.policy;
      _storeUrl = updateResult.storeUrl;
      _currentBuildNumber = updateResult.currentBuildNumber;
      _currentVersionName = updateResult.currentVersionName;
      _inMaintenance = maintenanceResult.isActive;
      _maintenancePolicy = maintenanceResult.policy;
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

    if (_checkingUpdate) {
      return const StartupSplashScreen();
    }

    if (_inMaintenance && _maintenancePolicy != null) {
      return MaintenanceScreen(
        policy: _maintenancePolicy!,
        onRetry: () => unawaited(_evaluate()),
      );
    }

    if (_isBootstrapping(provider)) {
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
