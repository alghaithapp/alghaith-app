/// Deep-link and push-notification tab routing (customer, merchant, courier, driver).
class AppNavigationState {
  int? pendingMainTab;
  int? pendingMerchantTab;
  int? pendingDeliveryTab;
  int? pendingDriverTab;

  String? pendingOrderIdCustomer;
  String? pendingOrderIdMerchant;
  String? pendingOrderIdDelivery;
  String? pendingOrderIdDriver;

  void reset() {
    pendingMainTab = null;
    pendingMerchantTab = null;
    pendingDeliveryTab = null;
    pendingDriverTab = null;
    pendingOrderIdCustomer = null;
    pendingOrderIdMerchant = null;
    pendingOrderIdDelivery = null;
    pendingOrderIdDriver = null;
  }

  void requestMainShellTab(int index) {
    if (index < 0) return;
    pendingMainTab = index;
  }

  int? takePendingMainTab() {
    final tab = pendingMainTab;
    pendingMainTab = null;
    return tab;
  }

  int? takePendingMerchantTab() {
    final tab = pendingMerchantTab;
    pendingMerchantTab = null;
    return tab;
  }

  int? takePendingDeliveryTab() {
    final tab = pendingDeliveryTab;
    pendingDeliveryTab = null;
    return tab;
  }

  int? takePendingDriverTab() {
    final tab = pendingDriverTab;
    pendingDriverTab = null;
    return tab;
  }

  void setPendingOrderId(String role, String? orderId) {
    switch (role) {
      case 'customer':
        pendingOrderIdCustomer = orderId;
        break;
      case 'merchant':
        pendingOrderIdMerchant = orderId;
        break;
      case 'delivery':
        pendingOrderIdDelivery = orderId;
        break;
      case 'driver':
        pendingOrderIdDriver = orderId;
        break;
    }
  }

  String? takePendingOrderId(String role) {
    switch (role) {
      case 'customer':
        final id = pendingOrderIdCustomer;
        pendingOrderIdCustomer = null;
        return id;
      case 'merchant':
        final id = pendingOrderIdMerchant;
        pendingOrderIdMerchant = null;
        return id;
      case 'delivery':
        final id = pendingOrderIdDelivery;
        pendingOrderIdDelivery = null;
        return id;
      case 'driver':
        final id = pendingOrderIdDriver;
        pendingOrderIdDriver = null;
        return id;
      default:
        return null;
    }
  }

  void requestTabForRole(String role, int index) {
    if (index < 0) return;
    switch (role) {
      case 'customer':
        pendingMainTab = index;
        break;
      case 'merchant':
        pendingMerchantTab = index;
        break;
      case 'delivery':
        pendingDeliveryTab = index;
        break;
      case 'driver':
        pendingDriverTab = index;
        break;
    }
  }
}
