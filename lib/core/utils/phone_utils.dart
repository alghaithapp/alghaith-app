/// توحيد أرقام الهاتف العراقية — استخدم هذا في كل الطبقات.
class PhoneUtils {
  const PhoneUtils._();

  static String normalize(String phone) {
    final digits = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('0') && digits.length >= 11) {
      return '+964${digits.substring(1)}';
    }
    if (digits.startsWith('964')) {
      return '+$digits';
    }
    if (digits.length == 10 && digits.startsWith('7')) {
      return '+964$digits';
    }
    return phone.trim().startsWith('+') ? phone.trim() : '+$digits';
  }

  static List<String> variants(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      final trimmed = phone.trim();
      return trimmed.isEmpty ? const [] : [trimmed];
    }
    final core = digits.substring(digits.length - 10);
    return ['+964$core', '964$core', '0$core', core];
  }

  static bool isValidIraqiMobile(String phone) {
    final normalized = normalize(phone);
    return RegExp(r'^\+9647\d{9}$').hasMatch(normalized);
  }
}
