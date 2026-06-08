/// حساب تجريبي لمراجعي App Store — لا يُرسل OTP حقيقي.
class AppleReviewAuth {
  const AppleReviewAuth._();

  static const String demoCode = '123456';

  static const Set<String> _demoDigits = {
    '000000000',
    '07000000000',
    '96400000000',
    '9647000000000',
    '7000000000',
  };

  static String digitsOnly(String phone) =>
      phone.trim().replaceAll(RegExp(r'\D'), '');

  static bool isDemoPhone(String phone) {
    final digits = digitsOnly(phone);
    if (digits.isEmpty) return false;
    if (_demoDigits.contains(digits)) return true;
    if (digits.endsWith('000000000') && digits.replaceAll('0', '').length <= 2) {
      return true;
    }
    return false;
  }

  /// يحوّل 000000000 إلى 07000000000 ليتوافق مع التحقق العراقي.
  static String canonicalizeInput(String phone) {
    final digits = digitsOnly(phone);
    if (digits == '000000000') return '07000000000';
    return phone.trim();
  }

  static String toE164(String phone) {
    final canonical = canonicalizeInput(phone);
    final digits = digitsOnly(canonical);
    if (digits.startsWith('964')) return '+$digits';
    if (digits.startsWith('0') && digits.length == 11) {
      return '+964${digits.substring(1)}';
    }
    if (digits.length == 10) return '+964$digits';
    return '+964$digits';
  }
}
