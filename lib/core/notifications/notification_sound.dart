import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Branded notification sound for Al-Ghaith.
///
/// Replace `assets/sounds/alghaith_notify.wav` with your own clip, then run:
/// `node scripts/generate_notification_sound.cjs`
/// (or copy the same file to Android `res/raw/` and `ios/Runner/`).
class NotificationSound {
  NotificationSound._();

  static const String fileName = 'alghaith_notify.wav';
  static const String androidResource = 'alghaith_notify';
  static const String channelId = 'alghaith_orders_v3';
  static const String channelName = 'طلبات الغيث';

  static const AndroidNotificationSound androidSound =
      RawResourceAndroidNotificationSound(androidResource);

  static const AndroidNotificationChannel androidChannel =
      AndroidNotificationChannel(
    channelId,
    channelName,
    description: 'إشعارات الطلبات والتوصيل بصوت الغيث',
    importance: Importance.high,
    playSound: true,
    sound: androidSound,
  );

  static const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: 'إشعارات الطلبات والتوصيل بصوت الغيث',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    sound: androidSound,
  );

  static const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    sound: fileName,
    presentSound: true,
    threadIdentifier: 'alghaith_unread',
  );

  static const String incomingCallFileName = 'alghaith_incoming_call.wav';
  static const String incomingCallAndroidResource = 'alghaith_incoming_call';
  static const String incomingCallChannelId = 'alghaith_incoming_calls_v2';
  static const String incomingCallChannelName = 'المكالمات الواردة';

  static const AndroidNotificationSound incomingCallAndroidSound =
      RawResourceAndroidNotificationSound(incomingCallAndroidResource);

  static const AndroidNotificationChannel incomingCallAndroidChannel =
      AndroidNotificationChannel(
    incomingCallChannelId,
    incomingCallChannelName,
    description: 'رنين المكالمات الصوتية داخل التطبيق',
    importance: Importance.max,
    playSound: true,
    sound: incomingCallAndroidSound,
  );

  static const AndroidNotificationDetails incomingCallAndroidDetails =
      AndroidNotificationDetails(
    incomingCallChannelId,
    incomingCallChannelName,
    channelDescription: 'رنين المكالمات الصوتية داخل التطبيق',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: incomingCallAndroidSound,
    category: AndroidNotificationCategory.call,
    ongoing: true,
    autoCancel: false,
  );

  static const DarwinNotificationDetails incomingCallIosDetails =
      DarwinNotificationDetails(
    sound: incomingCallFileName,
    presentSound: true,
    presentAlert: true,
    presentBadge: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );
}
