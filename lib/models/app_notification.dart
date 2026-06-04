/// فئة الإشعار داخل التطبيق.

enum NotificationCategory {

  order,

  promo,

  review,

  account,

  system,

  taxi,

  delivery,

  admin,

}



/// أولوية العرض (البانرات تتجاهل التسويق عند إيقاف التنبيهات المنبثقة فقط).

enum NotificationPriority {

  urgent,

  normal,

  marketing,

}



/// إشعار داخل التطبيق مرتبط بدور: customer | merchant | delivery | driver | admin

class AppNotificationItem {

  final String id;

  final String title;

  final String body;

  final String audience;

  final bool read;

  final int createdAtMs;

  final String? orderNumber;

  final NotificationCategory category;

  final NotificationPriority priority;

  /// مفتاح فريد لمنع التكرار (مثلاً order:123:accepted).

  final String? eventKey;



  const AppNotificationItem({

    required this.id,

    required this.title,

    required this.body,

    required this.audience,

    this.read = false,

    required this.createdAtMs,

    this.orderNumber,

    this.category = NotificationCategory.system,

    this.priority = NotificationPriority.normal,

    this.eventKey,

  });



  bool get isMarketing => priority == NotificationPriority.marketing;



  AppNotificationItem copyWith({bool? read}) {

    return AppNotificationItem(

      id: id,

      title: title,

      body: body,

      audience: audience,

      read: read ?? this.read,

      createdAtMs: createdAtMs,

      orderNumber: orderNumber,

      category: category,

      priority: priority,

      eventKey: eventKey,

    );

  }



  Map<String, dynamic> toMap() {

    return {

      'id': id,

      'title': title,

      'body': body,

      'audience': audience,

      'read': read,

      'createdAtMs': createdAtMs,

      if (orderNumber != null) 'orderNumber': orderNumber,

      'category': category.name,

      'priority': priority.name,

      if (eventKey != null) 'eventKey': eventKey,

    };

  }



  static NotificationCategory _parseCategory(String? raw) {

    return NotificationCategory.values.firstWhere(

      (e) => e.name == raw,

      orElse: () => NotificationCategory.system,

    );

  }



  static NotificationPriority _parsePriority(String? raw) {

    return NotificationPriority.values.firstWhere(

      (e) => e.name == raw,

      orElse: () => NotificationPriority.normal,

    );

  }



  factory AppNotificationItem.fromMap(Map<String, dynamic> map) {

    return AppNotificationItem(

      id: map['id']?.toString() ?? '',

      title: map['title']?.toString() ?? '',

      body: map['body']?.toString() ?? '',

      audience: map['audience']?.toString() ?? 'customer',

      read: map['read'] == true,

      createdAtMs: map['createdAtMs'] is int

          ? map['createdAtMs'] as int

          : int.tryParse(map['createdAtMs']?.toString() ?? '') ??

              DateTime.now().millisecondsSinceEpoch,

      orderNumber: map['orderNumber']?.toString(),

      category: _parseCategory(map['category']?.toString()),

      priority: _parsePriority(map['priority']?.toString()),

      eventKey: map['eventKey']?.toString(),

    );

  }



  factory AppNotificationItem.fromLegacyMap(

    Map map, {

    required String audience,

    String? id,

  }) {

    final title = map['title']?.toString() ?? '';

    final body = map['body']?.toString() ?? '';

    final ms = DateTime.now().millisecondsSinceEpoch;

    return AppNotificationItem(

      id: id ?? 'legacy-$ms-${title.hashCode}',

      title: title,

      body: body,

      audience: map['audience']?.toString() ?? audience,

      read: map['read'] == true,

      createdAtMs: map['createdAtMs'] is int

          ? map['createdAtMs'] as int

          : ms,

      orderNumber: map['orderNumber']?.toString(),

    );

  }

}



/// جمهور الإشعار حسب دور المستخدم الحالي.

String? notificationAudienceForRole(String? role) {

  switch (role) {

    case 'merchant':

      return 'merchant';

    case 'customer':

      return 'customer';

    case 'delivery':

      return 'delivery';

    case 'driver':

      return 'driver';

    case 'admin':

      return 'admin';

    default:

      return null;

  }

}


