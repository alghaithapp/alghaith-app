import 'dart:math' as math;

import '../models/app_notification.dart';

/// In-app notification list and read-state (extracted from [AppProvider]).
class AppNotificationInboxState {
  final List<AppNotificationItem> items = [];
  String? pendingUnreadPromptRole;

  void reset() {
    items.clear();
    pendingUnreadPromptRole = null;
  }

  void clearUnreadPrompt() {
    pendingUnreadPromptRole = null;
  }

  List<AppNotificationItem> forAudience(String audience) {
    return List<AppNotificationItem>.unmodifiable(
      items.where((n) => n.audience == audience),
    );
  }

  int unreadCountFor(String audience) {
    return items.where((n) => n.audience == audience && !n.read).length;
  }

  List<AppNotificationItem> unreadForRole(String role) {
    return items
        .where((n) => n.audience == role && !n.read)
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  }

  String? takePendingUnreadPromptRole() {
    final role = pendingUnreadPromptRole;
    pendingUnreadPromptRole = null;
    return role;
  }

  String add(
    String title,
    String body, {
    required String audience,
    String? orderNumber,
    NotificationCategory category = NotificationCategory.system,
    NotificationPriority priority = NotificationPriority.normal,
    String? eventKey,
  }) {
    if (eventKey != null) {
      final byKey = items.indexWhere(
        (n) => n.eventKey == eventKey && n.audience == audience,
      );
      if (byKey >= 0) return items[byKey].id;
    }
    final existing = items.indexWhere(
      (n) =>
          n.audience == audience &&
          n.title == title &&
          n.body == body &&
          (orderNumber == null || n.orderNumber == orderNumber),
    );
    if (existing >= 0) return items[existing].id;

    final item = AppNotificationItem(
      id: _newId(),
      title: title,
      body: body,
      audience: audience,
      read: false,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      orderNumber: orderNumber,
      category: category,
      priority: priority,
      eventKey: eventKey,
    );
    items.insert(0, item);
    if (items.length > 200) {
      items.removeRange(200, items.length);
    }
    return item.id;
  }

  bool markRead(String id) {
    final index = items.indexWhere((n) => n.id == id);
    if (index < 0 || items[index].read) return false;
    items[index] = items[index].copyWith(read: true);
    return true;
  }

  bool markReadForOrder(String orderNumber, String audience) {
    var changed = false;
    for (var i = 0; i < items.length; i++) {
      final n = items[i];
      if (n.audience == audience && !n.read && n.orderNumber == orderNumber) {
        items[i] = n.copyWith(read: true);
        changed = true;
      }
    }
    return changed;
  }

  bool markReadByTitleBody(String title, String body, String audience) {
    final index = items.indexWhere(
      (n) =>
          n.audience == audience &&
          !n.read &&
          n.title == title &&
          n.body == body,
    );
    if (index < 0) return false;
    return markRead(items[index].id);
  }

  static String _newId() {
    final rng = math.Random.secure();
    const hex = '0123456789abcdef';
    String seg(int len) =>
        List.generate(len, (_) => hex[rng.nextInt(16)]).join();
    return '${seg(8)}-${seg(4)}-4${seg(3)}-${hex[8 + rng.nextInt(4)]}${seg(3)}-${seg(12)}';
  }
}
