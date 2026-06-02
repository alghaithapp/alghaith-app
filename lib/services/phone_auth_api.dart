import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';

class PhoneAuthSession {
  const PhoneAuthSession({
    required this.token,
    required this.phoneNumber,
  });

  final String token;
  final String phoneNumber;
}

class PhoneAuthApi {
  PhoneAuthApi({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl();

  final String baseUrl;

  static String _defaultBaseUrl() => AppConfig.normalizedPhoneAuthUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<void> sendCode(String phone, {required String channel}) async {
    final response = await http.post(
      _uri('/auth/send-code'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'channel': channel}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractMessage(response.body));
    }
  }

  Future<PhoneAuthSession> verifyCode(String phone, String code) async {
    final response = await http.post(
      _uri('/auth/verify-code'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractMessage(response.body));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('استجابة غير صالحة من الخادم');
    }

    final token = decoded['token']?.toString().trim() ?? '';
    final phoneNumber = decoded['phoneNumber']?.toString().trim() ?? '';
    if (token.isEmpty || phoneNumber.isEmpty) {
      throw Exception('تعذر إنشاء جلسة تسجيل الدخول');
    }

    return PhoneAuthSession(token: token, phoneNumber: phoneNumber);
  }

  String _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return 'تعذر إتمام الطلب';
  }
}
