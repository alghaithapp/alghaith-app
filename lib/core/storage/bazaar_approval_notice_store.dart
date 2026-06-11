import 'package:shared_preferences/shared_preferences.dart';

import '../utils/phone_utils.dart';

/// يتتبع ما إذا شاهد التاجر إشعار موافقة البازار مرة واحدة على هذا الجهاز.
class BazaarApprovalNoticeStore {
  BazaarApprovalNoticeStore._();

  static String _key(String phone) {
    final digits = PhoneUtils.digitsOnly(phone);
    return 'bazaar_approval_notice_seen_$digits';
  }

  static Future<bool> hasSeen(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(phone)) ?? false;
  }

  static Future<void> markSeen(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(phone), true);
  }

  /// يُعاد ضبط الإشعار عند إلغاء عضوية البازار ليظهر مجدداً عند موافقة لاحقة.
  static Future<void> clearSeen(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(phone));
  }
}
