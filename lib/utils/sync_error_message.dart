String syncErrorMessage(Object error) {
  final raw = error.toString();
  if (raw.contains('Missing authorization token') ||
      raw.contains('Invalid authorization token') ||
      raw.contains('401')) {
    return 'انتهت جلسة الدخول. سجل الخروج ثم ادخل مرة أخرى.';
  }
  if (raw.contains('Network error')) {
    return 'فشل الاتصال بالإنترنت أو بالخادم. حاول مرة أخرى.';
  }
  final cleaned = raw.replaceFirst('Exception: ', '').trim();
  if (cleaned.isNotEmpty) return cleaned;
  return 'تعذرت المزامنة الآن. تحقق من الاتصال ثم أعد المحاولة.';
}
