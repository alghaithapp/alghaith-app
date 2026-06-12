import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_update_policy.dart';
import '../screens/force_update_screen.dart';
import '../services/app_update_service.dart';
import 'startup_splash_screen.dart';

class AppUpdateGate extends StatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _requiresUpdate = false;
  AppUpdatePolicy? _policy;
  String? _storeUrl;
  int _currentBuildNumber = 0;
  String _currentVersionName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_evaluate());
  }

  @override
  void dispose() {
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
      setState(() => _checking = true);
    }
    final result = await AppUpdateService.evaluate();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _requiresUpdate = result.requiresUpdate;
      _policy = result.policy;
      _storeUrl = result.storeUrl;
      _currentBuildNumber = result.currentBuildNumber;
      _currentVersionName = result.currentVersionName;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
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
    return widget.child;
  }
}
