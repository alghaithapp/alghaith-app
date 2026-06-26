import 'package:flutter/material.dart';

import '../../../models/maintenance_policy.dart';
import '../../../widgets/app_logo.dart';

class MaintenanceScreen extends StatelessWidget {
  final MaintenancePolicy policy;
  final VoidCallback? onRetry;

  const MaintenanceScreen({
    super.key,
    required this.policy,
    this.onRetry,
  });

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
                  'صيانة مؤقتة',
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
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFE0A3)),
                  ),
                  child: const Text(
                    'نعمل على تحسين المنصة. يرجى المحاولة لاحقاً.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF8A6D1D),
                    ),
                  ),
                ),
                const Spacer(),
                if (onRetry != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        'إعادة المحاولة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
