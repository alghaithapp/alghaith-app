import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';

class AdminNotificationsTab extends StatefulWidget {
  const AdminNotificationsTab({super.key});
  @override
  State<AdminNotificationsTab> createState() => _AdminNotificationsTabState();
}

class _AdminNotificationsTabState extends State<AdminNotificationsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().admin.refreshAdminNotifications(unreadOnly: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final admin = context.watch<AppProvider>().admin;
    final notifications = admin.adminNotifications;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('الإشعارات (${notifications.length})', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black)),
            ),
            if (notifications.isNotEmpty)
              TextButton(
                onPressed: () => admin.markNotificationsRead(),
                child: const Text('تحديد الكل كمقروء', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.blue)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (notifications.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: Text('لا توجد إشعارات', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.grey))),
          )
        else
          ...notifications.map((n) => _NotificationCard(notification: n, isDark: isDark, admin: admin)),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool isDark;
  final dynamic admin;
  const _NotificationCard({required this.notification, required this.isDark, required this.admin});

  Color _typeColor(String type) {
    switch (type) {
      case 'new_merchant': return Colors.blue;
      case 'new_courier': return Colors.orange;
      case 'new_driver': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'new_merchant': return Icons.store;
      case 'new_courier': return Icons.delivery_dining;
      case 'new_driver': return Icons.directions_car;
      default: return Icons.notifications;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = notification['title']?.toString() ?? '';
    final body = notification['body']?.toString() ?? '';
    final type = notification['type']?.toString() ?? '';
    final createdAt = notification['created_at']?.toString() ?? '';
    final isRead = notification['is_read'] == true;
    final bg = isDark ? const Color(0xFF1E1E1E) : (isRead ? Colors.white : Colors.blue.shade50);

    return Card(
      color: bg,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isRead ? BorderSide.none : const BorderSide(color: Colors.blue, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _typeColor(type).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(_typeIcon(type), size: 18, color: _typeColor(type)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: 'Cairo', color: isDark ? Colors.white : Colors.black)),
                  if (body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(body, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'Cairo'))),
                  if (createdAt.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(_formatDate(createdAt), style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontFamily: 'Cairo'))),
                ],
              ),
            ),
            if (!isRead)
              GestureDetector(
                onTap: () => admin.markNotificationsRead(ids: [notification['id']?.toString() ?? '']),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.check, size: 16, color: Colors.blue),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
