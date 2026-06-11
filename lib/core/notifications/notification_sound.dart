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
  static const String channelId = 'alghaith_orders_v2';
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
}
