import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// شريط تحميل يظهر أثناء جلب بيانات الحساب من السيرفر.
class AccountServerLoadingView extends StatelessWidget {
  const AccountServerLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE8ECF4),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'جارٍ تحميل بياناتك من السيرفر',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'لحظة من فضلك…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
