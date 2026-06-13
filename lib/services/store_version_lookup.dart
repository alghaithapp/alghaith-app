import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class StoreVersionInfo {
  final String version;
  final int? buildNumber;
  final String source;

  const StoreVersionInfo({
    required this.version,
    required this.source,
    this.buildNumber,
  });

  String get label {
    if (buildNumber != null && buildNumber! > 0) {
      return '$version ($buildNumber)';
    }
    return version;
  }
}

class StoreVersionLookup {
  const StoreVersionLookup._();

  static const Duration timeout = Duration(seconds: 10);
  static const String iosBundleId = 'com.alghaith.app';
  static const String iosAppId = '6776741811';
  static const String androidPackageId = 'com.alghaith.app';

  static Future<StoreVersionInfo?> fetch() async {
    if (kIsWeb) return null;
    try {
      if (Platform.isIOS) {
        return await _fetchIos();
      }
      if (Platform.isAndroid) {
        return await _fetchAndroid();
      }
    } catch (error) {
      debugPrint('STORE_VERSION_LOOKUP_ERROR: $error');
    }
    return null;
  }

  static Future<StoreVersionInfo?> _fetchIos() async {
    final uris = [
      Uri.parse(
        'https://itunes.apple.com/lookup?bundleId=$iosBundleId&country=iq',
      ),
      Uri.parse('https://itunes.apple.com/lookup?id=$iosAppId&country=iq'),
      Uri.parse('https://itunes.apple.com/lookup?bundleId=$iosBundleId'),
    ];

    for (final uri in uris) {
      final info = await _fetchItunes(uri);
      if (info != null) return info;
    }
    return null;
  }

  static Future<StoreVersionInfo?> _fetchItunes(Uri uri) async {
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    final results = decoded['results'];
    if (results is! List || results.isEmpty) return null;

    final first = results.first;
    if (first is! Map<String, dynamic>) return null;
    final version = (first['version'] ?? '').toString().trim();
    if (version.isEmpty) return null;

    return StoreVersionInfo(
      version: version,
      source: 'app_store',
    );
  }

  static Future<StoreVersionInfo?> _fetchAndroid() async {
    final uris = [
      Uri.parse(
        'https://play.google.com/store/apps/details?id=$androidPackageId&hl=ar',
      ),
      Uri.parse(
        'https://play.google.com/store/apps/details?id=$androidPackageId&hl=en',
      ),
    ];

    for (final uri in uris) {
      final response = await http
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              'Accept-Language': 'ar,en;q=0.9',
            },
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        continue;
      }

      final version = _parsePlayStoreVersion(response.body);
      if (version == null || version.isEmpty) continue;

      return StoreVersionInfo(
        version: version,
        source: 'play_store',
      );
    }
    return null;
  }

  static String? _parsePlayStoreVersion(String html) {
    final patterns = <RegExp>[
      RegExp(r'itemprop="softwareVersion"[^>]*content="([^"]+)"'),
      RegExp(r'itemprop="softwareVersion"[^>]*>([^<]+)<'),
      RegExp(r'\[\[\["([0-9]+(?:\.[0-9]+){1,3})"\]\]'),
      RegExp(r'Current Version</div><span[^>]*><div[^>]*><span[^>]*>([^<]+)<'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match == null) continue;
      final value = match.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}

int compareVersionStrings(String left, String right) {
  final leftParts = _versionParts(left);
  final rightParts = _versionParts(right);
  final maxLength = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (var index = 0; index < maxLength; index++) {
    final a = index < leftParts.length ? leftParts[index] : 0;
    final b = index < rightParts.length ? rightParts[index] : 0;
    if (a != b) return a.compareTo(b);
  }
  return 0;
}

List<int> _versionParts(String raw) {
  return raw
      .split('.')
      .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
