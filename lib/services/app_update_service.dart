import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../core/config/app_config.dart';
import '../models/app_update_policy.dart';

class AppUpdateCheckResult {
  final bool requiresUpdate;
  final AppUpdatePolicy? policy;
  final int currentBuildNumber;
  final String currentVersionName;
  final String? storeUrl;

  const AppUpdateCheckResult({
    required this.requiresUpdate,
    required this.currentBuildNumber,
    required this.currentVersionName,
    this.policy,
    this.storeUrl,
  });
}

class AppUpdateService {
  const AppUpdateService._();

  static const Duration policyTimeout = Duration(seconds: 8);

  static Future<AppUpdateCheckResult> evaluate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuildNumber =
        int.tryParse(packageInfo.buildNumber.trim()) ?? 0;
    final currentVersionName = packageInfo.version.trim();

    try {
      final baseUrl = AppConfig.normalizedDatabaseUrl;
      if (baseUrl.isEmpty) {
        return AppUpdateCheckResult(
          requiresUpdate: false,
          currentBuildNumber: currentBuildNumber,
          currentVersionName: currentVersionName,
        );
      }

      final uri = Uri.parse('$baseUrl/app/update-policy');
      final response = await http
          .get(uri, headers: const {'Content-Type': 'application/json'})
          .timeout(policyTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'APP_UPDATE_CHECK_SKIPPED: status ${response.statusCode}',
        );
        return AppUpdateCheckResult(
          requiresUpdate: false,
          currentBuildNumber: currentBuildNumber,
          currentVersionName: currentVersionName,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return AppUpdateCheckResult(
          requiresUpdate: false,
          currentBuildNumber: currentBuildNumber,
          currentVersionName: currentVersionName,
        );
      }

      final policy = AppUpdatePolicy.fromMap(decoded);
      final requiresUpdate = currentBuildNumber < policy.minBuildNumber;
      final storeUrl = _resolveStoreUrl(policy);

      return AppUpdateCheckResult(
        requiresUpdate: requiresUpdate,
        policy: policy,
        currentBuildNumber: currentBuildNumber,
        currentVersionName: currentVersionName,
        storeUrl: storeUrl,
      );
    } catch (error) {
      debugPrint('APP_UPDATE_CHECK_OFFLINE: $error');
      return AppUpdateCheckResult(
        requiresUpdate: false,
        currentBuildNumber: currentBuildNumber,
        currentVersionName: currentVersionName,
      );
    }
  }

  static String? _resolveStoreUrl(AppUpdatePolicy policy) {
    if (!kIsWeb && Platform.isIOS) {
      return policy.iosStoreUrl.trim().isNotEmpty
          ? policy.iosStoreUrl.trim()
          : null;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return policy.androidStoreUrl.trim().isNotEmpty
          ? policy.androidStoreUrl.trim()
          : null;
    }
    final android = policy.androidStoreUrl.trim();
    final ios = policy.iosStoreUrl.trim();
    if (android.isNotEmpty) return android;
    if (ios.isNotEmpty) return ios;
    return null;
  }
}
