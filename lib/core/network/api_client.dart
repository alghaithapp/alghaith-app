import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

/// عميل HTTP واحد لكل طلبات Railway (/db/*).
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String? _sessionToken;

  void setSessionToken(String? token) {
    final normalized = token?.trim();
    _sessionToken =
        normalized == null || normalized.isEmpty ? null : normalized;
  }

  String? get sessionToken => _sessionToken;

  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return _request('GET', path, queryParameters: queryParameters);
  }

  Future<dynamic> put(String path, {Object? body}) {
    return _request('PUT', path, body: body);
  }

  Future<dynamic> post(String path, {Object? body}) {
    return _request('POST', path, body: body);
  }

  Future<dynamic> delete(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return _request('DELETE', path, queryParameters: queryParameters);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
  }) async {
    final baseUrl = AppConfig.normalizedDatabaseUrl;
    if (baseUrl.isEmpty) {
      throw ApiException('Backend URL is not configured.');
    }

    final uri = Uri.parse('$baseUrl$path')
        .replace(queryParameters: queryParameters);
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = _sessionToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    // إعادة المحاولة عند أخطاء الشبكة/المهلة (بما فيها POST الحرجة مثل طلب التكسي).
    final maxAttempts =
        method == 'GET' || path.startsWith('/db/taxi/') ? 3 : 1;

    late http.Response response;
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        switch (method) {
          case 'GET':
            response = await http
                .get(uri, headers: headers)
                .timeout(AppConfig.apiTimeout);
          case 'PUT':
            response = await http
                .put(uri, headers: headers, body: jsonEncode(body))
                .timeout(AppConfig.apiTimeout);
          case 'POST':
            response = await http
                .post(uri, headers: headers, body: jsonEncode(body))
                .timeout(AppConfig.apiTimeout);
          case 'DELETE':
            response = await http
                .delete(uri, headers: headers)
                .timeout(AppConfig.apiTimeout);
          default:
            throw ApiException('Unsupported method: $method');
        }
        break;
      } catch (error) {
        if (error is ApiException) rethrow;
        debugPrint('ApiClient network error (attempt $attempt): $error');
        if (attempt >= maxAttempts) {
          throw ApiException('خطأ في الاتصال. تحقق من الإنترنت وحاول مجدداً.');
        }
        // مهلة تصاعدية بسيطة قبل إعادة المحاولة (1ث، 2ث).
        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        final preview = response.body.trim();
        if (preview.length > 80) {
          throw ApiException('استجابة غير متوقعة من الخادم.');
        }
        throw ApiException(
          preview.isNotEmpty
              ? 'استجابة غير متوقعة من الخادم: $preview'
              : 'استجابة غير متوقعة من الخادم.',
        );
      }
    }

    var message = 'Server error (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String) {
        final backendMessage = (decoded['message'] as String).trim();
        if (backendMessage.isNotEmpty) message = backendMessage;
      }
    } catch (_) {}

    throw ApiException(message, statusCode: response.statusCode);
  }
}
