/// توحيد أرقام الهاتف العراقية — استخدم هذا في كل الطبقات.
class PhoneUtils {
  const PhoneUtils._();

  /// يحوّل الأرقام العربية (٠١٢…) والفارسية (۰۱۲…) إلى أرقام لاتينية.
  static String toWesternDigits(String input) {
    final buffer = StringBuffer();
    for (final codeUnit in input.runes) {
      if (codeUnit >= 0x0660 && codeUnit <= 0x0669) {
        buffer.writeCharCode(0x0030 + (codeUnit - 0x0660));
      } else if (codeUnit >= 0x06F0 && codeUnit <= 0x06F9) {
        buffer.writeCharCode(0x0030 + (codeUnit - 0x06F0));
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  /// يستخرج الأرقام فقط بعد تحويلها إلى صيغة لاتينية.
  static String digitsOnly(String input) {
    return toWesternDigits(input).replaceAll(RegExp(r'\D'), '');
  }

  static String normalize(String phone) {
    final digits = digitsOnly(phone);
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
    final digits = digitsOnly(phone);
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
