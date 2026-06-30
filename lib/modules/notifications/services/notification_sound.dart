import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationSound {
  NotificationSound._();

  static const String channelId = 'alghaith_orders_v5';
  static const String channelName = 'طلبات الغيث';

  static const AndroidNotificationChannel androidChannel =
      AndroidNotificationChannel(
    channelId,
    channelName,
    description: 'إشعارات الطلبات والتوصيل',
    importance: Importance.high,
    playSound: true,
  );

  static const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: 'إشعارات الطلبات والتوصيل',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  static const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentSound: true,
    threadIdentifier: 'alghaith_unread',
  );

  static const String incomingCallChannelId = 'alghaith_incoming_calls_v3';
  static const String incomingCallChannelName = 'المكالمات الواردة';

  static const AndroidNotificationChannel incomingCallAndroidChannel =
      AndroidNotificationChannel(
    incomingCallChannelId,
    incomingCallChannelName,
    description: 'رنين المكالمات الصوتية داخل التطبيق',
    importance: Importance.max,
    playSound: true,
  );

  static const AndroidNotificationDetails incomingCallAndroidDetails =
      AndroidNotificationDetails(
    incomingCallChannelId,
    incomingCallChannelName,
    channelDescription: 'رنين المكالمات الصوتية داخل التطبيق',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    category: AndroidNotificationCategory.call,
    ongoing: true,
    autoCancel: false,
  );

  static const DarwinNotificationDetails incomingCallIosDetails =
      DarwinNotificationDetails(
    presentSound: true,
    presentAlert: true,
    presentBadge: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  static const String taxiRequestChannelId = channelId;
  static const String taxiRequestChannelName = channelName;

  static const AndroidNotificationChannel taxiRequestAndroidChannel =
      AndroidNotificationChannel(
    taxiRequestChannelId,
    taxiRequestChannelName,
    description: 'طلبات التكسي الجديدة',
    importance: Importance.high,
    playSound: true,
  );

  static const AndroidNotificationDetails taxiRequestAndroidDetails =
      AndroidNotificationDetails(
    taxiRequestChannelId,
    taxiRequestChannelName,
    channelDescription: 'طلبات التكسي الجديدة',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );
}
