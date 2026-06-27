import 'dart:async';

import 'package:flutter/material.dart';

import '../modules/notifications/services/push_notification_service.dart';
import '../utils/call_navigation.dart';

/// توجيه موحّد لمكالمة واردة — يستخدم rootNavigatorKey (يعمل خارج شجرة MaterialApp).
class IncomingCallCoordinator {
  IncomingCallCoordinator._();

  static void present(Map<String, dynamic> data) {
    final nav = PushNotificationService.rootNavigatorKey?.currentState;
    if (nav == null || !nav.mounted) return;
    unawaited(CallNavigation.handlePushData(nav.context, data));
  }

  static GlobalKey<NavigatorState>? get rootNavigatorKey =>
      PushNotificationService.rootNavigatorKey;
}
