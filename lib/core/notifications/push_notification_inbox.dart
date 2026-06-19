import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_sound.dart';

class PushNotificationInbox {
  PushNotificationInbox._();

  static Future<void> Function()? onCourierStatusPush;
  static Future<void> Function()? onTaxiStatusPush;

  static const int summaryNotificationId = 900001;
  static const String unreadCountKey = 'push_unread_count';
  static const String inboxItemsKey = 'push_inbox_items';
  static const int maxStoredItems = 40;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _pluginReady = false;

  static Future<void> ensureInitialized() async {
    if (_pluginReady) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationAction,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        NotificationSound.androidChannel,
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'alghaith_taxi_requests',
          'طلبات التكسي',
          description: '🚕 طلبات تكسي مع أزرار قبول/رفض',
          importance: Importance.high,
          playSound: true,
        ),
      );
    }

    _pluginReady = true;
  }

  static Future<void> handleIncoming(RemoteMessage message) async {
    await ensureInitialized();

    final title = _readTitle(message);
    final body = _readBody(message);
    final eventKey = message.data['eventKey']?.toString() ?? '';
    final category = message.data['category']?.toString() ?? '';
    final audience = message.data['audience']?.toString() ?? '';
    final requestId = message.data['orderId']?.toString() ?? '';
    final isTaxiForDriver =
        category == 'taxi' &&
        audience == 'driver' &&
        (eventKey.contains(':pool_new') || eventKey.contains(':pool_returned'));

    if (isTaxiForDriver && requestId.isNotEmpty) {
      await _showTaxiNotification(
        id: requestId.hashCode,
        title: title,
        body: body,
        requestId: requestId,
      );
      return;
    }

    if (body.isEmpty && title == 'الغيث') return;

    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(unreadCountKey) ?? 0) + 1;
    await prefs.setInt(unreadCountKey, count);

    final items = _readItems(prefs);
    items.insert(
      0,
      {
        'title': title,
        'body': body,
        'orderId': message.data['orderId'] ?? '',
        'eventKey': eventKey,
        'receivedAt': DateTime.now().toIso8601String(),
      },
    );
    if (items.length > maxStoredItems) {
      items.removeRange(maxStoredItems, items.length);
    }
    await prefs.setString(inboxItemsKey, jsonEncode(items));

    await _showSummary(
      count: count,
      latestTitle: title,
      latestBody: body,
      orderId: message.data['orderId'],
    );
  }

  /// إظهار إشعار طلب تكسي مع أزرار قبول / رفض في الإشعار الخارجي
  static Future<void> _showTaxiNotification({
    required int id,
    required String title,
    required String body,
    required String requestId,
  }) async {
    const taxiChannelId = 'alghaith_taxi_requests';
    const taxiChannelName = 'طلبات التكسي';

    final androidDetails = AndroidNotificationDetails(
      taxiChannelId,
      taxiChannelName,
      channelDescription: '🚕 طلبات التكسي مع قبول/رفض',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      fullScreenIntent: true,
      showWhen: true,
    );

    await _localNotifications.show(
      id,
      title.isNotEmpty ? title : '🚕 طلب تكسي جديد',
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'taxi_request:$requestId',
    );

    // تخزين الإشعار في صندوق الإشعارات أيضاً
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(unreadCountKey) ?? 0) + 1;
    await prefs.setInt(unreadCountKey, count);
    final items = _readItems(prefs);
    items.insert(0, {
      'title': title,
      'body': body,
      'orderId': requestId,
      'eventKey': 'driver:$requestId:pool_new',
      'receivedAt': DateTime.now().toIso8601String(),
    });
    if (items.length > maxStoredItems) {
      items.removeRange(maxStoredItems, items.length);
    }
    await prefs.setString(inboxItemsKey, jsonEncode(items));
  }

  /// معالج الضغط على الإشعار — فتح نافذة طلب التكسي
  static void _onNotificationAction(NotificationResponse response) {
    final payload = response.payload ?? '';
    if (payload.startsWith('taxi_request:')) {
      final reqId = payload.replaceFirst('taxi_request:', '');
      if (reqId.isNotEmpty) {
        debugPrint('PushAction: فتح طلب تكسي $reqId من الإشعار');
        onTaxiNotificationTapped?.call(reqId);
      }
    }
  }

  /// Callback عندما يضغط السائق على الإشعار لفتح نافذة الطلب
  static void Function(String requestId)? onTaxiNotificationTapped;

  static Future<void> clearUnread() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(unreadCountKey, 0);
    await prefs.remove(inboxItemsKey);
    if (_pluginReady) {
      await _localNotifications.cancel(summaryNotificationId);
    }
  }

  static Future<int> unreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(unreadCountKey) ?? 0;
  }

  static Future<void> _showSummary({
    required int count,
    required String latestTitle,
    required String latestBody,
    String? orderId,
  }) async {
    final String title;
    final String body;

    if (count <= 1) {
      title = latestTitle;
      body = latestBody;
    } else {
      title = 'الغيث';
      body = 'لديك $count إشعارات لم تقرأها';
    }

    await _localNotifications.show(
      summaryNotificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationSound.channelId,
          NotificationSound.channelName,
          channelDescription: NotificationSound.androidDetails.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: NotificationSound.androidSound,
          groupKey: 'alghaith_unread_group',
          setAsGroupSummary: true,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: NotificationSound.iosDetails,
      ),
      payload: orderId,
    );
  }

  static String _readTitle(RemoteMessage message) {
    final fromData = message.data['title']?.trim();
    if (fromData != null && fromData.isNotEmpty) return fromData;
    return message.notification?.title?.trim() ?? 'الغيث';
  }

  static String _readBody(RemoteMessage message) {
    final fromData = message.data['body']?.trim();
    if (fromData != null && fromData.isNotEmpty) return fromData;
    return message.notification?.body?.trim() ?? '';
  }

  static List<Map<String, dynamic>> _readItems(SharedPreferences prefs) {
    final raw = prefs.getString(inboxItemsKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (error) {
      debugPrint('Push inbox decode failed: $error');
      return <Map<String, dynamic>>[];
    }
  }
}
