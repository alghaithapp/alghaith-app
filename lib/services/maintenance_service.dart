import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../models/maintenance_policy.dart';

class MaintenanceCheckResult {
  final bool isActive;
  final MaintenancePolicy? policy;

  const MaintenanceCheckResult({
    required this.isActive,
    this.policy,
  });
}

class MaintenanceService {
  const MaintenanceService._();

  static const Duration policyTimeout = Duration(seconds: 8);

  static Future<MaintenanceCheckResult> evaluate({
    bool isAdmin = false,
  }) async {
    final policy = await _loadPolicy();
    if (policy == null || !policy.enabled) {
      return const MaintenanceCheckResult(isActive: false);
    }

    if (policy.allowAdminBypass && isAdmin) {
      return MaintenanceCheckResult(isActive: false, policy: policy);
    }

    return MaintenanceCheckResult(isActive: true, policy: policy);
  }

  static Future<MaintenancePolicy?> _loadPolicy() async {
    try {
      final baseUrl = AppConfig.normalizedDatabaseUrl;
      if (baseUrl.isEmpty) return null;

      final uri = Uri.parse('$baseUrl/app/maintenance');
      final response = await http
          .get(uri, headers: const {'Content-Type': 'application/json'})
          .timeout(policyTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'MAINTENANCE_POLICY_SKIPPED: status ${response.statusCode}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return MaintenancePolicy.fromMap(decoded);
    } catch (error) {
      debugPrint('MAINTENANCE_POLICY_OFFLINE: $error');
      return null;
    }
  }
}
