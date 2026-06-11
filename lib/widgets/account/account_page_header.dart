import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/ui/account_ui.dart';
import '../../screens/notifications_screen.dart';
import '../app_logo.dart';

class AccountPageHeader extends StatelessWidget {
  final int notificationCount;
  final String title;

  const AccountPageHeader({
    super.key,
    required this.notificationCount,
    this.title = 'حسابي',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          const AppLogo(size: 32),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: accountHeadline,
                height: 1.15,
                letterSpacing: -0.3,
              ),
            ),
          ),
          AccountNotificationBell(count: notificationCount),
        ],
      ),
    );
  }
}

class AccountNotificationBell extends StatelessWidget {
  final int count;

  const AccountNotificationBell({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(builder: (_) => const NotificationsScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                CupertinoIcons.bell_fill,
                color: Colors.orange.shade700,
                size: 22,
              ),
              if (count > 0)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      gradient: AccountUi.brandGradient,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo',
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
