# notifications

FCM registration, foreground banners, inbox, role-specific push handlers.

## Owns

- `services/notification_hub.dart` — in-app notification routing per role
- `services/push_notification_service.dart` — FCM token + foreground handling
- `services/push_notification_inbox.dart` — local notification tray + background handler
- `services/notification_sound.dart` — branded Android/iOS sound config
- `widgets/push_notification_lifecycle_scope.dart` — resume hooks
- `widgets/in_app_notification_banner.dart` — top overlay banners
- `widgets/customer_order_notifications.dart` — customer order status banners

## Legacy shims

`lib/core/notifications/*` and related `lib/widgets/*` re-export from here (deprecated).
