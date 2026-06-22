import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/notifications/push_notification_service.dart';
import '../providers/app_provider.dart';

class PushNotificationLifecycleScope extends StatefulWidget {
  final Widget child;

  const PushNotificationLifecycleScope({super.key, required this.child});

  @override
  State<PushNotificationLifecycleScope> createState() =>
      _PushNotificationLifecycleScopeState();
}

class _PushNotificationLifecycleScopeState
    extends State<PushNotificationLifecycleScope> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(PushNotificationService.instance.onAppResumed());
      if (!mounted) return;
      unawaited(context.read<AppProvider>().refreshCourierApprovalIfNeeded());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PushNotificationService.instance.onAppResumed());
      if (!mounted) return;
      unawaited(context.read<AppProvider>().refreshCourierApprovalIfNeeded());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
