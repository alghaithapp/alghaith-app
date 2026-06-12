import '../utils/merchant_profile_fields.dart';

/// طبقة قراءة مُنمذجة وآمنة فوق خريطة بيانات المتجر (`Map<String,dynamic>`).
///
/// تُركّز كل الوصول للحقول في مكان واحد مع قراءة آمنة للأنواع، بدل تكرار
/// عمليات الـ cast الهشّة (`as bool?`, `as int?`) في كل مكان. لا تُعدّل البيانات
/// الأصلية؛ هي عرض للقراءة فقط.
class MerchantStoreView {
  const MerchantStoreView(this._map);

  final Map<String, dynamic>? _map;

  bool get exists => _map != null;
  Map<String, dynamic>? get raw => _map;

  String _string(List<String> keys) {
    final map = _map;
    if (map == null) return '';
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String get name => _string(['name', 'store_name']);
  String get description => _string(['description', 'store_description']);
  String get phone => _string(['phone', 'merchant_phone']);
  String get whatsapp => _string(['whatsapp', 'whatsApp', 'merchant_whatsapp']);

  bool get isOpen =>
      MerchantProfileFields.boolValue(_map?['isOpen'] ?? _map?['is_open'],
          fallback: true);
  bool get isFrozen => MerchantProfileFields.boolValue(
      _map?['isFrozen'] ?? _map?['is_frozen'],
      fallback: false);
  bool get isBazaarMember => MerchantProfileFields.boolValue(
      _map?['isBazaarMember'] ?? _map?['is_bazaar_member'],
      fallback: false);

  int get deliveryFee =>
      MerchantProfileFields.intValue(_map?['deliveryFee'] ?? _map?['delivery_fee']);

  bool get isApproved => MerchantProfileFields.isApproved(_map);
  bool get isRejected => MerchantProfileFields.isRejected(_map);
  String get approvalStatus => MerchantProfileFields.approvalStatus(_map);
  String get rejectionMessage => MerchantProfileFields.rejectionMessage(_map);

  bool get showPhoneToCustomers =>
      MerchantProfileFields.showPhoneToCustomers(_map);
  bool get showWhatsAppToCustomers =>
      MerchantProfileFields.showWhatsAppToCustomers(_map);

  String get address => MerchantProfileFields.addressFromMap(_map);
}
