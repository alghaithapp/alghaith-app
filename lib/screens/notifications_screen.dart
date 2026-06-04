import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/app_provider.dart';

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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: items.isEmpty
            ? const Center(
                child: Text(
                  'لا توجد إشعارات',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
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
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationItem item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return GestureDetector(
      onTap: () {
        if (!item.read) provider.markNotificationRead(item.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.read
                ? Colors.transparent
                : const Color(0xFFF5A01D).withValues(alpha: 0.25),
            width: item.read ? 0 : 1.5,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: item.read
                  ? Colors.grey.shade200
                  : const Color(0xFFFFEBEE),
              child: Icon(
                CupertinoIcons.bell_fill,
                color: item.read ? Colors.grey : const Color(0xFFF5A01D),
                size: 18,
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
                      fontSize: 14,
                      fontFamily: 'Cairo',
                      color: item.read ? Colors.black54 : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            if (!item.read)
              Container(
                width: 8,
                height: 8,
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
