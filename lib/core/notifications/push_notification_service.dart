import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../../services/supabase_service.dart';
import 'push_notification_inbox.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isConfigured) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationInbox.handleIncoming(message);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;
  String? _currentToken;
  String? _boundPhone;

  bool get isAvailable => _initialized;
  String? get boundPhone => _boundPhone;

  Future<void> initialize() async {
    if (_initialized || kIsWeb || !DefaultFirebaseOptions.isConfigured) {
      if (!DefaultFirebaseOptions.isConfigured) {
        debugPrint('Push: Firebase is not configured — external notifications disabled.');
      }
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await PushNotificationInbox.ensureInitialized();

      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('Push: permission=${settings.authorizationStatus.name}');

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        await PushNotificationInbox.clearUnread();
      }

      messaging.onTokenRefresh.listen((token) {
        _currentToken = token;
        final phone = _boundPhone;
        if (phone != null && phone.isNotEmpty) {
          unawaited(_registerToken(phone, token));
        }
      });

      _currentToken = await messaging.getToken();
      _initialized = true;
      debugPrint('Push: initialized token=${_currentToken != null}');
    } catch (error) {
      debugPrint('Push: initialization failed: $error');
    }
  }

  Future<void> onAppResumed() async {
    if (!_initialized) return;
    await PushNotificationInbox.clearUnread();
    final phone = _boundPhone?.trim();
    if (phone == null || phone.isEmpty) return;
    try {
      await SupabaseService.markPushInboxOpened(phone: phone);
    } catch (error) {
      debugPrint('Push: failed to mark inbox opened: $error');
    }
  }

  Future<void> bindToUser(String phone) async {
    if (!_initialized) return;
    final normalized = phone.trim();
    if (normalized.isEmpty) return;
    _boundPhone = normalized;

    final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    _currentToken = token;
    await _registerToken(normalized, token);
    try {
      await SupabaseService.markPushInboxOpened(phone: normalized);
    } catch (error) {
      debugPrint('Push: failed to mark inbox opened on bind: $error');
    }
  }

  Future<void> unbindFromUser({String? phone}) async {
    if (!_initialized) return;
    final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
    final targetPhone = (phone ?? _boundPhone)?.trim();
    if (targetPhone != null &&
        targetPhone.isNotEmpty &&
        token != null &&
        token.isNotEmpty) {
      try {
        await SupabaseService.deleteDeviceToken(
          phone: targetPhone,
          token: token,
        );
      } catch (error) {
        debugPrint('Push: failed to delete token: $error');
      }
    }
    _boundPhone = null;
  }

  Future<void> _registerToken(String phone, String token) async {
    try {
      await SupabaseService.saveDeviceToken(
        phone: phone,
        token: token,
        platform: _platformLabel(),
      );
      debugPrint('Push: token registered for $phone');
    } catch (error) {
      debugPrint('Push: failed to register token: $error');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await PushNotificationInbox.handleIncoming(message);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('Push: opened ${message.data}');
    unawaited(PushNotificationInbox.clearUnread());
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'unknown';
    }
  }
}
