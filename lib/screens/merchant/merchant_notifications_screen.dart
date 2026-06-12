import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification.dart';
import '../../providers/app_provider.dart';
import '../../core/ui/app_spacing.dart';
import '../../widgets/app_state_views.dart';

class MerchantNotificationsScreen extends StatelessWidget {
  const MerchantNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.merchantLabels;
    final items = provider.notifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        title: Text(
          'إشعارات ${labels.storeLabelAr}',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            color: Color(0xFF1C1C1E),
          ),
        ),
        actions: [
          if (items.any((n) => !n.read))
            TextButton(
              onPressed: () {
                for (final n in items.where((e) => !e.read)) {
                  provider.markNotificationRead(n.id);
                }
              },
              child: const Text(
                'قراءة الكل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF5A01D),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: EmptyStateView(
                icon: Icons.notifications_none_rounded,
                title: 'لا توجد إشعارات بعد',
                message: 'ستظهر هنا إشعارات الطلبات وتحديثات متجرك.',
              ),
            )
          else
            ...items.map((item) => _MerchantNotificationTile(item: item)),
        ],
      ),
    );
  }
}

class _MerchantNotificationTile extends StatelessWidget {
  final AppNotificationItem item;

  const _MerchantNotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
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
                : const Color(0xFFF5A01D).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: item.read
                  ? Colors.grey.shade100
                  : const Color(0xFFFFEBEE),
              child: Icon(
                Icons.campaign_rounded,
                color: item.read ? Colors.grey : const Color(0xFFF5A01D),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Cairo',
                      color: item.read ? Colors.black54 : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      height: 1.4,
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
