import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'phone_auth_api.dart';

class CloudflareService {
  const CloudflareService._();

  static const Duration _uploadTimeout = Duration(seconds: 45);

  /// رفع صورة إلى التخزين عبر Worker (Supabase Storage خلفياً).
  static Future<String?> uploadFile(File file, {String bucket = 'uploads'}) async {
    try {
      final baseUrl = PhoneAuthApi().baseUrl.trim();
      if (baseUrl.isEmpty) {
        debugPrint('CLOUDFLARE_UPLOAD: Missing PHONE_AUTH_BASE_URL');
        return null;
      }

      final uri = Uri.parse('$baseUrl/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['bucket'] = bucket;

      final mimeType = _mimeTypeForPath(file.path);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: http.MediaType.parse(mimeType),
        ),
      );

      final streamedResponse =
          await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      final decoded = _decodeBody(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map &&
          decoded['success'] == true) {
        final url = decoded['url']?.toString().trim();
        if (url != null && url.isNotEmpty) {
          return url;
        }
      }

      final message = decoded is Map
          ? decoded['message']?.toString()
          : response.body;
      debugPrint(
        'CLOUDFLARE_UPLOAD_FAILED (${response.statusCode}): $message',
      );
      return null;
    } catch (error) {
      debugPrint('CLOUDFLARE_UPLOAD_ERROR: $error');
      return null;
    }
  }

  static dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }
}
