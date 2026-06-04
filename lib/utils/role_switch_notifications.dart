import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/app_provider.dart';
import '../screens/merchant/merchant_notifications_screen.dart';
import '../screens/notifications_screen.dart';
import '../widgets/in_app_notification_banner.dart';

/// يعرض تنبيهاً بالإشعارات غير المقروءة بعد تبديل الدور، ثم البانرات التفاعلية.
class RoleSwitchNotificationPresenter {
  static Future<void> showIfNeeded(BuildContext context) async {
    final provider = context.read<AppProvider>();
    if (!provider.inAppAlertsEnabled) {
      provider.takePendingUnreadPromptRole();
      return;
    }
    final role = provider.takePendingUnreadPromptRole();
    if (role == null || !context.mounted) return;
    if (provider.userRole != role) return;

    final unread = provider.unreadNotificationsForRole(role);
    if (unread.isEmpty || !context.mounted) return;

    await _showUnreadSummaryDialog(context, unread.length);
    if (!context.mounted) return;

    await _presentUnreadBanners(context, provider, unread);
  }

  static Future<void> _showUnreadSummaryDialog(
    BuildContext context,
    int count,
  ) async {
    final label = count == 1 ? 'إشعاراً' : 'إشعارات';
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: Color(0xFFF5A01D)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'إشعارات جديدة',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'لديك $count $label لم تقرأها بعد تبديل الحساب.',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً', style: TextStyle(fontFamily: 'Cairo')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openInbox(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF5A01D),
            ),
            child: const Text(
              'عرض الكل',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  static void _openInbox(BuildContext context) {
    final provider = context.read<AppProvider>();
    final Widget page;
    if (provider.isMerchant) {
      page = const MerchantNotificationsScreen();
    } else if (provider.userRole == 'delivery' ||
        provider.userRole == 'driver' ||
        provider.userRole == 'admin') {
      page = const NotificationsScreen();
    } else {
      page = const NotificationsScreen();
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  static Future<void> _presentUnreadBanners(
    BuildContext context,
    AppProvider provider,
    List<AppNotificationItem> unread,
  ) async {
    for (final item in unread) {
      if (!context.mounted) break;
      final marked = await showInAppNotificationBanner(
        context: context,
        title: item.title,
        body: item.body,
        accentColor: const Color(0xFFF5A01D),
        icon: Icons.notifications_rounded,
      );
      if (marked) {
        provider.markNotificationRead(item.id);
      }
    }
  }
}
