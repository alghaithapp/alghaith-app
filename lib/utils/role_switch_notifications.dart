import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../modules/merchant/screens/merchant_notifications_screen.dart';
import '../modules/common/screens/notifications_screen.dart';
import '../widgets/in_app_notification_banner.dart';

class RoleSwitchNotificationPresenter {
  static String? _lastPromptKey;

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
    final promptKey = '$role:${unread.length}:${unread.first.id}';
    if (_lastPromptKey == promptKey) return;
    _lastPromptKey = promptKey;

    final tapped = await showInAppNotificationBanner(
      context: context,
      title: 'لديك إشعارات غير مقروءة',
      body: unread.length == 1
          ? 'يوجد إشعار واحد بانتظارك في هذا الحساب.'
          : 'يوجد ${unread.length} إشعارات بانتظارك في هذا الحساب.',
      accentColor: const Color(0xFFF5A01D),
      icon: Icons.notifications_active_rounded,
      autoHide: const Duration(seconds: 5),
    );

    if (tapped && context.mounted) {
      _openInbox(context);
    }
  }

  static void _openInbox(BuildContext context) {
    final provider = context.read<AppProvider>();
    final Widget page;
    if (provider.isMerchant) {
      page = const MerchantNotificationsScreen();
    } else {
      page = const NotificationsScreen();
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
