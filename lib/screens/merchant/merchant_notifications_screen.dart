import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';

class MerchantNotificationsScreen extends StatelessWidget {
  const MerchantNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.merchantLabels;
    final items = provider.notifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: Text(
          'إشعارات ${labels.storeLabelAr}',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: const Text('لا توجد إشعارات بعد.', style: TextStyle(fontFamily: 'Cairo')),
            )
          else
            ...items.map((item) {
              final title = item['title']?.toString() ?? '';
              final body  = item['body']?.toString()  ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.deepOrange.withValues(alpha: 0.10),
                      child: const Icon(Icons.campaign_rounded, color: Colors.deepOrange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
                          const SizedBox(height: 4),
                          Text(body, style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4, fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
