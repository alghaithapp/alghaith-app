import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_update_policy.dart';
import '../widgets/app_logo.dart';

class ForceUpdateScreen extends StatelessWidget {
  final AppUpdatePolicy policy;
  final String? storeUrl;
  final int currentBuildNumber;
  final String currentVersionName;

  const ForceUpdateScreen({
    super.key,
    required this.policy,
    required this.currentBuildNumber,
    required this.currentVersionName,
    this.storeUrl,
  });

  Future<void> _openStore() async {
    final url = storeUrl?.trim() ?? '';
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                const AppLogo(size: 120),
                const SizedBox(height: 24),
                const Text(
                  'تحديث مطلوب',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  policy.messageAr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    height: 1.7,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6E8F0)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'إصدارك الحالي: $currentVersionName ($currentBuildNumber)',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Color(0xFF636366),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'الحد الأدنى المطلوب: ${policy.minVersionName} (${policy.minBuildNumber})',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE84A3A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: storeUrl == null || storeUrl!.trim().isEmpty
                        ? null
                        : _openStore,
                    icon: const Icon(Icons.system_update_alt_rounded),
                    label: const Text(
                      'تحديث الآن من المتجر',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE84A3A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
