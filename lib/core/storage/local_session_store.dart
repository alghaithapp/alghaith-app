import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/phone_utils.dart';
import '../../data/models/account_snapshot.dart';

class StoredSession {
  const StoredSession({required this.phone, this.token});

  final String phone;
  final String? token;
}

/// تخزين الجلسة والنسخة المحلية — بدون منطق أعمال.
class LocalSessionStore {
  LocalSessionStore._();

  static final LocalSessionStore instance = LocalSessionStore._();

  static const _phoneKey = 'auth_phone';
  static const _tokenKey = 'auth_session_token';

  Future<StoredSession?> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_phoneKey);
    if (phone == null || phone.trim().isEmpty) return null;
    final token = prefs.getString(_tokenKey);
    return StoredSession(
      phone: PhoneUtils.normalize(phone),
      token: token?.trim().isEmpty == true ? null : token?.trim(),
    );
  }

  Future<void> writeSession({
    required String phone,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, PhoneUtils.normalize(phone));
    final normalizedToken = token?.trim();
    if (normalizedToken != null && normalizedToken.isNotEmpty) {
      await prefs.setString(_tokenKey, normalizedToken);
    } else {
      await prefs.remove(_tokenKey);
    }
  }

  Future<void> clearSession({String? phone}) async {
    final prefs = await SharedPreferences.getInstance();
    final previousPhone = phone ?? prefs.getString(_phoneKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_tokenKey);
    if (previousPhone != null && previousPhone.trim().isNotEmpty) {
      await prefs.remove(_snapshotKey(previousPhone));
    }
  }

  Future<AccountSnapshot?> readSnapshot(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotKey(phone));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AccountSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSnapshot(String phone, AccountSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _snapshotKey(phone),
      jsonEncode(snapshot.toJson()),
    );
  }

  String _snapshotKey(String phone) {
    final digits = PhoneUtils.normalize(phone).replaceAll(RegExp(r'\D'), '');
    return 'account_snapshot_v2_$digits';
  }
}
