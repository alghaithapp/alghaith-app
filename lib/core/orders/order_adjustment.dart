import '../../models/app_models.dart';

int orderLineItemsSubtotal(
  List<OrderLineItem> items, {
  bool onlyAvailable = false,
}) {
  return items
      .where((item) => !onlyAvailable || item.isAvailable)
      .fold(0, (sum, item) => sum + item.price * item.quantity);
}

int orderAvailableItemsCount(List<OrderLineItem> items) {
  return items
      .where((item) => item.isAvailable)
      .fold(0, (sum, item) => sum + item.quantity);
}

String orderAvailableItemsLabelAr(List<OrderLineItem> items) {
  return items
      .where((item) => item.isAvailable)
      .map((item) => item.nameAr)
      .join(' ، ');
}

String orderAvailableItemsLabelEn(List<OrderLineItem> items) {
  return items
      .where((item) => item.isAvailable)
      .map((item) => item.nameEn)
      .join(', ');
}

int resolveOrderItemsSubtotal(ActiveOrder order) {
  return order.itemsSubtotalIqd ?? orderLineItemsSubtotal(order.lineItems);
}

int resolveOrderDeliveryFee(ActiveOrder order) {
  return order.deliveryFeeIqd ?? 0;
}

int resolveOrderPromoDiscount(ActiveOrder order) {
  return order.promoDiscountIqd ?? 0;
}

int computeAdjustedOrderTotal(
  ActiveOrder order,
  List<OrderLineItem> lineItems,
) {
  final subtotal = orderLineItemsSubtotal(lineItems, onlyAvailable: true);
  final delivery = resolveOrderDeliveryFee(order);
  final promo = resolveOrderPromoDiscount(order).clamp(0, subtotal);
  return subtotal + delivery - promo;
}

List<String> unavailableItemNamesAr(List<OrderLineItem> items) {
  return items
      .where((item) => !item.isAvailable)
      .map((item) => item.nameAr)
      .toList();
}

bool orderHasUnavailableItems(List<OrderLineItem> items) {
  return items.any((item) => !item.isAvailable);
}

bool isCustomerRejectedAdjustment(ActiveOrder order) {
  return order.noteAr.contains('رفض الزبون الطلب المعدّل') ||
      order.noteEn.contains('Customer rejected adjusted order');
}

bool isCustomerApprovedAdjustment(ActiveOrder order) {
  return order.noteAr.contains('وافق الزبون على الطلب المعدّل') ||
      order.noteEn.contains('Customer approved adjusted order');
}
