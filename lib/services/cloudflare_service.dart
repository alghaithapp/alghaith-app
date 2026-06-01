import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class CloudflareService {
  const CloudflareService._();

  static Future<String?> uploadFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (error) {
      debugPrint('IMAGE_ENCODE_ERROR: $error');
      return null;
    }
  }

  static Future<String?> uploadBase64(String base64String) async {
    final trimmed = base64String.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}
