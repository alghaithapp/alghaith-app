import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';

class AppUpdateChecker {
  AppUpdateChecker._();

  static Future<void> checkAndPrompt(BuildContext context) async {
    if (!context.mounted) return;

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const PopScope(
        canPop: false,
        child: Center(child: CupertinoActivityIndicator(radius: 16)),
      ),
    );

    final result = await AppUpdateService.evaluate();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (result.requiresUpdate) {
      await _promptUpdate(context, result);
      return;
    }

    await _showUpToDate(context, result);
  }

  static Future<void> _promptUpdate(
    BuildContext context,
    AppUpdateCheckResult result,
  ) async {
    final policy = result.policy;
    final message = policy?.messageAr.trim().isNotEmpty == true
        ? policy!.messageAr
        : 'يتوفر إصدار أحدث من التطبيق. يرجى التحديث من المتجر.';
    final minVersion = policy != null
        ? '${policy.minVersionName} (${policy.minBuildNumber})'
        : '';
    final storeUrl = result.storeUrl?.trim() ?? '';

    if (storeUrl.isEmpty) {
      if (!context.mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text(
            'تحديث متوفر',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
          ),
          content: Text(
            '$message\n\nتعذر فتح رابط المتجر حالياً.',
            style: const TextStyle(fontFamily: 'Cairo', height: 1.5),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final goToStore = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text(
          'تحديث متوفر',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
        content: Text(
          minVersion.isNotEmpty
              ? '$message\n\nالإصدار المطلوب: $minVersion\nإصدارك: ${result.currentVersionName} (${result.currentBuildNumber})'
              : message,
          style: const TextStyle(fontFamily: 'Cairo', height: 1.5),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('لاحقاً', style: TextStyle(fontFamily: 'Cairo')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'الذهاب للمتجر',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (goToStore == true) {
      await _openStore(storeUrl);
    }
  }

  static Future<void> _showUpToDate(
    BuildContext context,
    AppUpdateCheckResult result,
  ) async {
    if (!context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text(
          'لا يوجد تحديث',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
        content: Text(
          'أنت تستخدم أحدث إصدار متاح.\n'
          'الإصدار الحالي: ${result.currentVersionName} (${result.currentBuildNumber})',
          style: const TextStyle(fontFamily: 'Cairo', height: 1.5),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  static Future<void> _openStore(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
