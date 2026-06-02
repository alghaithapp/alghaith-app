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

    late http.Response response;
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
    } catch (error) {
      if (error is ApiException) rethrow;
      debugPrint('ApiClient network error: $error');
      throw ApiException('Network error. Check your connection.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
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
