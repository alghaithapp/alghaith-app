import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isAr = appProvider.lang == 'ar';

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(isAr ? "الإشعارات" : "Notifications", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
      child: SafeArea(
        child: appProvider.notifications.isEmpty
            ? Center(child: Text(isAr ? "لا توجد إشعارات" : "No notifications", style: const TextStyle(fontFamily: 'Cairo')))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: appProvider.notifications.length,
                itemBuilder: (context, index) {
                  final note = appProvider.notifications[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        const CircleAvatar(backgroundColor: Colors.orange, child: Icon(CupertinoIcons.bell_fill, color: Colors.white, size: 18)),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(note['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: Colors.black)),
                              const SizedBox(height: 4),
                              Text(note['body']!, style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Cairo')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
