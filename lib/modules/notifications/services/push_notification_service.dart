import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../firebase_options.dart';
import '../../../services/supabase_service.dart';
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

    // مهلة قصيرة لمنع تعليق التطبيق (شاشة بيضاء) إذا تعذّر الحصول على التوكن
    // أو إذن الإشعارات على iOS. بدل انتظار إلى ما لا نهاية.
    await _initializeWithTimeout();
  }

  Future<void> _initializeWithTimeout() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await PushNotificationInbox.ensureInitialized();

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

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      final initialMessage = await messaging.getInitialMessage().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (initialMessage != null) {
        await PushNotificationInbox.clearUnread();
        _handleOpenedMessage(initialMessage);
      }

      messaging.onTokenRefresh.listen((token) {
        _currentToken = token;
        final phone = _boundPhone;
        if (phone != null && phone.isNotEmpty) {
          unawaited(_registerToken(phone, token));
        }
      });

      _currentToken = await messaging.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Push: getToken timed out on iOS — starting without token.');
          return null;
        },
      );
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

  bool get hasToken =>
      _currentToken != null && _currentToken!.trim().isNotEmpty;

  bool get isFirebaseConfigured => DefaultFirebaseOptions.isConfigured;

  Future<bool> areNotificationsAuthorized() async {
    if (kIsWeb || !DefaultFirebaseOptions.isConfigured) return false;
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return false;

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final status = settings.authorizationStatus;
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> requestNotificationsPermission() async {
    if (kIsWeb || !DefaultFirebaseOptions.isConfigured) return false;
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return false;

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// ربط توكن FCM بالمستخدم مع إعادة المحاولة.
  Future<bool> ensureUserBinding(String phone) async {
    if (kIsWeb || !DefaultFirebaseOptions.isConfigured) return false;
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return false;

    final normalized = phone.trim();
    if (normalized.isEmpty) return false;

    for (var attempt = 0; attempt < 3; attempt++) {
      await bindToUser(normalized);
      final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null && token.trim().isNotEmpty) {
        _currentToken = token;
        return true;
      }
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
    return false;
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
        platform: _platformLabel() ?? 'unknown',
      );
      debugPrint('Push: token registered for $phone');
    } catch (error) {
      debugPrint('Push: failed to register token: $error');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await PushNotificationInbox.handleIncoming(message);
    final eventKey = message.data['eventKey']?.toString() ?? '';
    final category = message.data['category']?.toString() ?? '';
    final requestId = message.data['orderId']?.toString() ?? '';

    if (eventKey == 'call:incoming') {
      onIncomingCall?.call(Map<String, dynamic>.from(message.data));
    }
    if (eventKey == 'chat:new') {
      onChatMessage?.call(Map<String, dynamic>.from(message.data));
    }

    if (eventKey.contains(':approved') || eventKey.contains(':rejected')) {
      await PushNotificationInbox.onCourierStatusPush?.call();
    }
    if (category == 'taxi') {
      await PushNotificationInbox.onTaxiStatusPush?.call();
      if (eventKey == 'taxi:pool_new') {
        await PushNotificationInbox.onTaxiIncomingPush?.call();
      }
    }

    // للدور driver: إشعار طلب تكسي جديد — اعرض نافذة قبول/رفض
    final audience = message.data['audience']?.toString() ?? '';
    if (audience == 'driver' &&
        (eventKey.contains(':pool_new') || eventKey.contains(':pool_returned')) &&
        requestId.isNotEmpty) {
      final title = message.data['title']?.toString() ?? '🚕 طلب تكسي جديد';
      final body = message.data['body']?.toString() ?? '';
      // سيتم معالجة طلب التكسي الجديد من خلال الـ Provider
      debugPrint('Push: taxi request $requestId — handled via provider');
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('Push: opened ${message.data}');
    unawaited(PushNotificationInbox.clearUnread());
    unawaited(PushNotificationInbox.onCourierStatusPush?.call());
    final category = message.data['category']?.toString() ?? '';
    if (category == 'taxi') {
      unawaited(PushNotificationInbox.onTaxiStatusPush?.call());
    }

    // إبلاغ الـ Provider بفتح إشعار للقيام بالتوجيه
    _lastOpenedNotificationData = message.data;
    if (_onNotificationOpened != null) {
      _onNotificationOpened!(message.data);
    }
  }

  Map<String, dynamic>? _lastOpenedNotificationData;

  /// مفتاح Root Navigator لإظهار النوافذ المنبثقة من الإشعارات
  static GlobalKey<NavigatorState>? _rootNavigatorKey;

  /// تعيين مفتاح Root Navigator (يُستدعى من main.dart)
  static void setRootNavigatorKey(GlobalKey<NavigatorState> key) {
    _rootNavigatorKey = key;
  }
  void Function(Map<String, dynamic> data)? _onNotificationOpened;
  void Function(Map<String, dynamic> data)? onIncomingCall;
  void Function(Map<String, dynamic> data)? onChatMessage;

  void setOnNotificationOpened(void Function(Map<String, dynamic> data) callback) {
    _onNotificationOpened = callback;
    if (_lastOpenedNotificationData != null) {
      callback(_lastOpenedNotificationData!);
      _lastOpenedNotificationData = null;
    }
  }

  String? _platformLabel() {
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

  Future<void> subscribeToTopic(String topic) async {
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('Push: subscribed to topic $topic');
    } catch (e) {
      debugPrint('Push: failed to subscribe to topic $topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('Push: unsubscribed from topic $topic');
    } catch (e) {
      debugPrint('Push: failed to unsubscribe from topic $topic: $e');
    }
  }
}
