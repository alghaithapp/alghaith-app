/// طبقة قراءة مُنمذجة وآمنة فوق سجل المستخدم (`app_users`) القادم من السيرفر.
class AppUserView {
  const AppUserView(this._map);

  final Map<String, dynamic>? _map;

  bool get exists => _map != null;
  Map<String, dynamic>? get raw => _map;

  static String? _trim(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String? _first(List<String> keys) {
    final map = _map;
    if (map == null) return null;
    for (final key in keys) {
      final value = _trim(map[key]);
      if (value != null) return value;
    }
    return null;
  }

  String? get fullName => _first(['full_name', 'fullName', 'name']);
  String? get email => _first(['email', 'customer_email', 'customerEmail']);
  String? get role => _first(['role']);
  String? get accountType => _first(['account_type', 'accountType']);
}
