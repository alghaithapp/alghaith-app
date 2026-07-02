import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/push_notification_service.dart';
import '../services/push_notification_inbox.dart';
import '../../common/screens/notifications_screen.dart';
import '../widgets/in_app_notification_banner.dart';
import '../../taxi/providers/taxi_provider.dart';
import '../../taxi/services/driver_presence_service.dart';
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
    IncomingCallWatcher.instance.onCallCancelled = _handleCallCancelled;
    PushNotificationInbox.onTaxiIncomingPush = _handleTaxiIncomingPush;
    PushNotificationInbox.onTaxiStatusPush = _handleTaxiStatusPush;
    PushNotificationService.instance.onAdminMessage = _handleAdminMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_onLifecycleRefresh());
    });
  }

  Future<void> _handleTaxiIncomingPush() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    if (provider.userRole != 'driver') return;
    await context.read<TaxiProvider>().fetchIncomingRequests();
  }

  Future<void> _handleTaxiStatusPush() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final taxi = context.read<TaxiProvider>();
    if (provider.userRole == 'driver') {
      await taxi.loadDriverActiveRequest();
      await taxi.fetchIncomingRequests();
    } else {
      await taxi.loadActiveRequest();
    }
  }

  Future<void> _handleAdminMessage(RemoteMessage message) async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    provider.ingestAdminBroadcastPush(Map<String, dynamic>.from(message.data));
    if (!provider.inAppAlertsEnabled) return;

    final title = message.data['title']?.toString().trim().isNotEmpty == true
        ? message.data['title'].toString().trim()
        : (message.notification?.title?.trim().isNotEmpty == true
            ? message.notification!.title!.trim()
            : 'رسالة من الإدارة');
    final body = message.data['body']?.toString().trim().isNotEmpty == true
        ? message.data['body'].toString().trim()
        : (message.notification?.body?.trim() ?? '');

    final tapped = await showInAppNotificationBanner(
      context: context,
      title: title,
      body: body.isNotEmpty ? body : 'لديك رسالة جديدة من إدارة التطبيق',
      accentColor: const Color(0xFF007A7A),
      icon: Icons.campaign_rounded,
    );
    if (!mounted || !tapped) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  Future<void> _onLifecycleRefresh() async {
    await PushNotificationService.instance.onAppResumed();
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.syncUserNotificationsFromServer();
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
    if (provider.userRole == 'driver') {
      final taxi = context.read<TaxiProvider>();
      final presence = DriverPresenceService.instance;
      // لا نعيد بدء الخدمة إذا كانت تعمل بالفعل لتجنب قطع التدفق
      if (!presence.isRunning) {
        await presence.restoreIfNeeded(
          phone: phone,
          taxiProvider: taxi,
          readProfile: () => provider.driverProfile,
          writeProfile: provider.setDriverProfile,
        );
      } else {
        // فقط نضمن أن الـ heartbeat سيعيد الاتصال إذا انقطع
        await presence.ensureOnline();
      }
    }
    if (_watchedPhone == phone && IncomingCallWatcher.instance.isActive) return;
    _watchedPhone = phone;
    IncomingCallWatcher.instance.bind(phone);
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    IncomingCallCoordinator.present(data);
  }

  void _handleCallCancelled(String callId) {
    // يُعلم شاشة المكالمة الواردة بإلغاء المتصل لإيقاف الرنين
    IncomingCallCoordinator.present({
      'eventKey': 'call:cancelled',
      'callLogId': callId,
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    IncomingCallWatcher.instance.onIncomingCall = null;
    IncomingCallWatcher.instance.onCallCancelled = null;
    IncomingCallWatcher.instance.unbind();
    PushNotificationInbox.onTaxiIncomingPush = null;
    PushNotificationInbox.onTaxiStatusPush = null;
    PushNotificationService.instance.onAdminMessage = null;
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
