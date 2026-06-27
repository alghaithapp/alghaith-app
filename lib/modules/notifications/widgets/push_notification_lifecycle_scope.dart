import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/push_notification_service.dart';
import '../../../providers/app_provider.dart';
import '../../../services/incoming_call_watcher.dart';
import '../../../services/incoming_call_coordinator.dart';

class PushNotificationLifecycleScope extends StatefulWidget {
  final Widget child;

  const PushNotificationLifecycleScope({super.key, required this.child});

  @override
  State<PushNotificationLifecycleScope> createState() =>
      _PushNotificationLifecycleScopeState();
}

class _PushNotificationLifecycleScopeState
    extends State<PushNotificationLifecycleScope> with WidgetsBindingObserver {
  String? _watchedPhone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    IncomingCallWatcher.instance.onIncomingCall = _handleIncomingCall;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_onLifecycleRefresh());
    });
  }

  Future<void> _onLifecycleRefresh() async {
    await PushNotificationService.instance.onAppResumed();
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.refreshCourierApprovalIfNeeded();
    await _syncIncomingCallWatcher(provider);
  }

  Future<void> _syncIncomingCallWatcher(AppProvider provider) async {
    final phone = provider.sessionPhone?.trim() ?? '';
    if (!provider.hasPhoneSession || phone.isEmpty) {
      _watchedPhone = null;
      IncomingCallWatcher.instance.unbind();
      return;
    }

    await PushNotificationService.instance.ensureUserBinding(phone);
    if (_watchedPhone == phone && IncomingCallWatcher.instance.isActive) return;
    _watchedPhone = phone;
    IncomingCallWatcher.instance.bind(phone);
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    IncomingCallCoordinator.present(data);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    IncomingCallWatcher.instance.onIncomingCall = null;
    IncomingCallWatcher.instance.unbind();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onLifecycleRefresh());
      return;
    }
    // لا نوقف المراقبة عند inactive — يحدث كثيراً أثناء المحادثة والمكالمة.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      IncomingCallWatcher.instance.unbind();
      _watchedPhone = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_syncIncomingCallWatcher(provider));
    });
    return widget.child;
  }
}
