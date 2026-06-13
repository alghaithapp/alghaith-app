import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../core/config/app_config.dart';
import '../models/app_update_policy.dart';
import 'store_version_lookup.dart';

enum AppUpdateCheckStatus {
  upToDate,
  updateAvailable,
  checkFailed,
}

class AppUpdateCheckResult {
  final AppUpdateCheckStatus status;
  final bool requiresUpdate;
  final AppUpdatePolicy? policy;
  final int currentBuildNumber;
  final String currentVersionName;
  final String? storeUrl;
  final String? availableVersionLabel;

  const AppUpdateCheckResult({
    required this.status,
    required this.requiresUpdate,
    required this.currentBuildNumber,
    required this.currentVersionName,
    this.policy,
    this.storeUrl,
    this.availableVersionLabel,
  });
}

class AppUpdateService {
  const AppUpdateService._();

  static const Duration policyTimeout = Duration(seconds: 8);

  /// فحص التحديث الإجباري عند فتح التطبيق (أقل رقم بناء مسموح).
  static Future<AppUpdateCheckResult> evaluate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuildNumber =
        int.tryParse(packageInfo.buildNumber.trim()) ?? 0;
    final currentVersionName = packageInfo.version.trim();

    final policy = await _loadPolicy();
    if (policy == null) {
      return AppUpdateCheckResult(
        status: AppUpdateCheckStatus.upToDate,
        requiresUpdate: false,
        currentBuildNumber: currentBuildNumber,
        currentVersionName: currentVersionName,
      );
    }

    final requiresUpdate = currentBuildNumber < policy.minBuildNumber;
    return AppUpdateCheckResult(
      status: requiresUpdate
          ? AppUpdateCheckStatus.updateAvailable
          : AppUpdateCheckStatus.upToDate,
      requiresUpdate: requiresUpdate,
      policy: policy,
      currentBuildNumber: currentBuildNumber,
      currentVersionName: currentVersionName,
      storeUrl: _resolveStoreUrl(policy),
      availableVersionLabel: requiresUpdate
          ? '${policy.minVersionName} (${policy.minBuildNumber})'
          : null,
    );
  }

  /// فحص يدوي من الإعدادات: يقارن بأحدث إصدار في المتجر وليس فقط الحد الأدنى الإجباري.
  static Future<AppUpdateCheckResult> evaluateForManualCheck() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuildNumber =
        int.tryParse(packageInfo.buildNumber.trim()) ?? 0;
    final currentVersionName = packageInfo.version.trim();

    final policy = await _loadPolicy();
    final storeVersion = await StoreVersionLookup.fetch();

    var requiresUpdate = false;
    String? availableVersionLabel;

    if (policy != null) {
      if (policy.latestBuildNumber > currentBuildNumber) {
        requiresUpdate = true;
        availableVersionLabel =
            '${policy.latestVersionName} (${policy.latestBuildNumber})';
      } else if (policy.latestVersionName.trim().isNotEmpty &&
          compareVersionStrings(
                currentVersionName,
                policy.latestVersionName.trim(),
              ) <
              0) {
        requiresUpdate = true;
        availableVersionLabel = policy.latestVersionName.trim();
      }
    }

    if (storeVersion != null) {
      final storeIsNewer = compareVersionStrings(
            currentVersionName,
            storeVersion.version,
          ) <
          0;
      if (storeIsNewer) {
        requiresUpdate = true;
        availableVersionLabel = storeVersion.label;
      } else if (storeVersion.buildNumber != null &&
          storeVersion.buildNumber! > currentBuildNumber) {
        requiresUpdate = true;
        availableVersionLabel = storeVersion.label;
      }
    }

    if (policy == null && storeVersion == null) {
      return AppUpdateCheckResult(
        status: AppUpdateCheckStatus.checkFailed,
        requiresUpdate: false,
        currentBuildNumber: currentBuildNumber,
        currentVersionName: currentVersionName,
      );
    }

    return AppUpdateCheckResult(
      status: requiresUpdate
          ? AppUpdateCheckStatus.updateAvailable
          : AppUpdateCheckStatus.upToDate,
      requiresUpdate: requiresUpdate,
      policy: policy,
      currentBuildNumber: currentBuildNumber,
      currentVersionName: currentVersionName,
      storeUrl: policy != null ? _resolveStoreUrl(policy) : null,
      availableVersionLabel: availableVersionLabel,
    );
  }

  static Future<AppUpdatePolicy?> _loadPolicy() async {
    try {
      final baseUrl = AppConfig.normalizedDatabaseUrl;
      if (baseUrl.isEmpty) return null;

      final uri = Uri.parse('$baseUrl/app/update-policy');
      final response = await http
          .get(uri, headers: const {'Content-Type': 'application/json'})
          .timeout(policyTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'APP_UPDATE_POLICY_SKIPPED: status ${response.statusCode}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return AppUpdatePolicy.fromMap(decoded);
    } catch (error) {
      debugPrint('APP_UPDATE_POLICY_OFFLINE: $error');
      return null;
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
