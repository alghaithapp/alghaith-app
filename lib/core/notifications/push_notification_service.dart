import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import '../../services/supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isConfigured) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const String _channelId = 'alghaith_orders';
  static const String _channelName = 'طلبات الغيث';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _currentToken;
  String? _boundPhone;

  bool get isAvailable => _initialized;

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
      await _setupLocalNotifications();

      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('Push: permission=${settings.authorizationStatus.name}');

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
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

  Future<void> bindToUser(String phone) async {
    if (!_initialized) return;
    final normalized = phone.trim();
    if (normalized.isEmpty) return;
    _boundPhone = normalized;

    final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    _currentToken = token;
    await _registerToken(normalized, token);
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

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'إشعارات الطلبات والتوصيل',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: message.data['orderId'],
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('Push: opened ${message.data}');
  }

  String _platformLabel() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }
}
