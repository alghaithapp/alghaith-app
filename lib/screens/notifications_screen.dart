import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/app_provider.dart';
import '../core/ui/app_spacing.dart';
import '../widgets/app_state_views.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final items = appProvider.notifications;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'الإشعارات',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: items.any((n) => !n.read)
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  for (final n in items.where((e) => !e.read)) {
                    appProvider.markNotificationRead(n.id);
                  }
                },
                child: const Text(
                  'قراءة الكل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: items.isEmpty
              ? const EmptyStateView(
                  icon: CupertinoIcons.bell,
                  title: 'لا توجد إشعارات',
                  message: 'ستظهر هنا تحديثات طلباتك وإشعارات حسابك.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final note = items[index];
                    return _NotificationTile(item: note);
                  },
                ),
        ),
      ),
    );
  }
}

/// تحويل milliseconds إلى نص عربي للوقت والتاريخ
String _formatNotificationTime(int createdAtMs) {
  final date = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  final now = DateTime.now();
  final diff = now.difference(date);

  // أقل من دقيقة
  if (diff.inSeconds < 60) {
    return 'الآن';
  }

  // أقل من ساعة
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    if (m == 1) return 'منذ دقيقة';
    return 'منذ $m دقائق';
  }

  // أقل من 24 ساعة
  if (diff.inHours < 24) {
    final h = diff.inHours;
    if (h == 1) return 'منذ ساعة';
    return 'منذ $h ساعات';
  }

  // أقل من 48 ساعة (أمس)
  if (diff.inHours < 48) {
    final time = DateFormat('h:mm a', 'en').format(date);
    return 'أمس $time';
  }

  // أقل من 7 أيام
  if (diff.inDays < 7) {
    final dayNames = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final dayName = dayNames[date.weekday - 1];
    final time = DateFormat('h:mm a', 'en').format(date);
    return '$dayName $time';
  }

  // تاريخ كامل
  final formatted = DateFormat('d MMMM yyyy', 'ar').format(date);
  final time = DateFormat('h:mm a', 'en').format(date);
  return '$formatted $time';
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationItem item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final timeText = _formatNotificationTime(item.createdAtMs);
    return GestureDetector(
      onTap: () {
        if (!item.read) provider.markNotificationRead(item.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: item.read
                ? Colors.transparent
                : const Color(0xFFF5A01D).withValues(alpha: 0.25),
            width: item.read ? 0 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: item.read
                  ? Colors.grey.shade200
                  : const Color(0xFFFFEBEE),
              child: Icon(
                CupertinoIcons.bell_fill,
                color: item.read ? Colors.grey : const Color(0xFFF5A01D),
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      fontFamily: 'Cairo',
                      color: item.read ? Colors.black54 : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.time,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeText,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!item.read)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5A01D),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
