import '../../models/app_models.dart';
import '../../models/app_notification.dart';
import '../../models/merchant_models.dart';

/// لقطة حالة الحساب للتخزين المحلي والمزامنة.
class AccountSnapshot {
  const AccountSnapshot({
    this.userRole,
    this.hasAdminAccess = false,
    this.accountType,
    this.customerName = '',
    this.customerPhone = '',
    this.customerAddress = '',
    this.customerLatitude,
    this.customerLongitude,
    this.customerAvatarRef,
    this.darkMode = false,
    this.inAppAlertsEnabled = true,
    this.driverType,
    this.driverProfile,
    this.courierProfile,
    this.merchantStore,
    this.merchantOffers = const [],
    this.merchantReviews = const [],
    this.items = const [],
    this.orders = const [],
    this.addresses = const [],
    this.favoriteItemIds = const [],
    this.selectedCategory = 'all',
    this.activeSubCategory,
    this.pendingOrderStatusSyncQueue = const [],
    this.notifications = const [],
    this.skippedCustomerSetup = false,
  });

  final String? userRole;
  final bool hasAdminAccess;
  final String? accountType;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final double? customerLatitude;
  final double? customerLongitude;
  final String? customerAvatarRef;
  final bool darkMode;
  final bool inAppAlertsEnabled;
  final String? driverType;
  final Map<String, dynamic>? driverProfile;
  final Map<String, dynamic>? courierProfile;
  final Map<String, dynamic>? merchantStore;
  final List<MerchantOffer> merchantOffers;
  final List<MerchantReview> merchantReviews;
  final List<ListItem> items;
  final List<ActiveOrder> orders;
  final List<String> addresses;
  final List<String> favoriteItemIds;
  final String selectedCategory;
  final String? activeSubCategory;
  final List<Map<String, dynamic>> pendingOrderStatusSyncQueue;
  final List<AppNotificationItem> notifications;
  final bool skippedCustomerSetup;

  Map<String, dynamic> toJson() {
    return {
      'userRole': userRole,
      'adminAccess': hasAdminAccess,
      'accountType': accountType,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
      'customerAvatarBase64': customerAvatarRef,
      'darkMode': darkMode,
      'inAppAlertsEnabled': inAppAlertsEnabled,
      'driverType': driverType,
      'driverProfile': driverProfile,
      'courierProfile': courierProfile,
      'merchantStore': merchantStore,
      'merchantOffers': merchantOffers.map((e) => e.toMap()).toList(),
      'merchantReviews': merchantReviews.map((e) => e.toMap()).toList(),
      'items': items.map((e) => e.toMap()).toList(),
      'orders': orders.map((e) => e.toMap()).toList(),
      'addresses': addresses,
      'favoriteItemIds': favoriteItemIds,
      'selectedCategory': selectedCategory,
      'activeSubCategory': activeSubCategory,
      'pendingOrderStatusSyncQueue': pendingOrderStatusSyncQueue,
      'notifications': notifications.map((e) => e.toMap()).toList(),
      'skippedCustomerSetup': skippedCustomerSetup,
    };
  }

  factory AccountSnapshot.fromJson(Map<String, dynamic> json) {
    return AccountSnapshot(
      userRole: json['userRole']?.toString(),
      hasAdminAccess: json['adminAccess'] as bool? ?? false,
      accountType: json['accountType']?.toString(),
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      customerAddress: json['customerAddress']?.toString() ?? '',
      customerLatitude: (json['customerLatitude'] as num?)?.toDouble(),
      customerLongitude: (json['customerLongitude'] as num?)?.toDouble(),
      customerAvatarRef: json['customerAvatarBase64']?.toString(),
      darkMode: json['darkMode'] as bool? ?? false,
      inAppAlertsEnabled: json['inAppAlertsEnabled'] as bool? ??
          json['notificationsEnabled'] as bool? ??
          true,
      driverType: json['driverType']?.toString(),
      driverProfile: json['driverProfile'] is Map
          ? Map<String, dynamic>.from(json['driverProfile'] as Map)
          : null,
      courierProfile: json['courierProfile'] is Map
          ? Map<String, dynamic>.from(json['courierProfile'] as Map)
          : null,
      merchantStore: json['merchantStore'] is Map
          ? Map<String, dynamic>.from(json['merchantStore'] as Map)
          : null,
      merchantOffers: _parseOffers(json['merchantOffers']),
      merchantReviews: _parseReviews(json['merchantReviews']),
      items: _parseItems(json['items']),
      orders: _parseOrders(json['orders']),
      addresses: _parseStrings(json['addresses']),
      favoriteItemIds: _parseStrings(json['favoriteItemIds']),
      selectedCategory: json['selectedCategory']?.toString() ?? 'all',
      activeSubCategory: json['activeSubCategory']?.toString(),
      pendingOrderStatusSyncQueue: _parseDynamicMaps(
        json['pendingOrderStatusSyncQueue'],
      ),
      notifications: _parseNotifications(json['notifications']),
      skippedCustomerSetup: json['skippedCustomerSetup'] as bool? ?? false,
    );
  }

  static List<AppNotificationItem> _parseNotifications(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => AppNotificationItem.fromMap(Map<String, dynamic>.from(e)))
        .where((n) => n.id.isNotEmpty && n.title.isNotEmpty)
        .toList();
  }

  static List<MerchantOffer> _parseOffers(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => MerchantOffer.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<MerchantReview> _parseReviews(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => MerchantReview.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<ListItem> _parseItems(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => ListItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<ActiveOrder> _parseOrders(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => ActiveOrder.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<String> _parseStrings(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }

  static List<Map<String, dynamic>> _parseDynamicMaps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

/// بيانات مسترجعة من السحابة دفعة واحدة.
class RemoteAccountBundle {
  const RemoteAccountBundle({
    this.appUser,
    this.customerProfile,
    this.merchantProfile,
    this.userState,
    this.addresses = const [],
    this.favoriteIds = const [],
    this.orders = const [],
    this.products = const [],
  });

  final Map<String, dynamic>? appUser;
  final Map<String, dynamic>? customerProfile;
  final Map<String, dynamic>? merchantProfile;
  final Map<String, dynamic>? userState;
  final List<String> addresses;
  final List<String> favoriteIds;
  final List<ActiveOrder> orders;
  final List<Map<String, dynamic>> products;
}
