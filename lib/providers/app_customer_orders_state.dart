import '../../models/app_models.dart';

/// Customer orders and saved addresses (extracted from [AppProvider]).
class AppCustomerOrdersState {
  List<ActiveOrder> orders = [];
  DateTime? lastFetch;
  final List<String> addresses = [];

  void reset() {
    orders = [];
    lastFetch = null;
    addresses.clear();
  }

  int get activeCount => orders
      .where((order) =>
          order.statusKey != 'completed' &&
          order.statusKey != 'rejected' &&
          order.statusKey != 'cancelled')
      .length;

  int? indexOf(String orderId) {
    final index = orders.indexWhere((order) => order.id == orderId);
    return index >= 0 ? index : null;
  }

  void prependOrders(Iterable<ActiveOrder> newOrders) {
    final existingIds = {for (final order in orders) order.id};
    for (final order in newOrders) {
      if (!existingIds.contains(order.id)) {
        orders.insert(0, order);
      }
    }
  }

  bool addAddress(String address) {
    final value = address.trim();
    if (value.isEmpty || addresses.contains(value)) return false;
    addresses.insert(0, value);
    return true;
  }

  String? removeAddressAt(int index) {
    if (index < 0 || index >= addresses.length) return null;
    return addresses.removeAt(index);
  }
}
