import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_sound.dart';

class PushNotificationInbox {
  PushNotificationInbox._();

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
    );

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(NotificationSound.androidChannel);
    }

    _pluginReady = true;
  }

  static Future<void> handleIncoming(RemoteMessage message) async {
    await ensureInitialized();

    final title = _readTitle(message);
    final body = _readBody(message);
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
        'eventKey': message.data['eventKey'] ?? '',
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
