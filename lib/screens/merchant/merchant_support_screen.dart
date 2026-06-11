import 'package:flutter/material.dart';

import '../../utils/helpers.dart';
import '../../widgets/whatsapp_icon.dart';

class MerchantSupportScreen extends StatelessWidget {
  const MerchantSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text(
          'الدعم الفني',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SupportCard(
            title: 'واتساب',
            subtitle: AppHelpers.supportPhoneNumber,
            iconWidget: const WhatsAppIcon(size: 36),
            onTap: () => AppHelpers.launchWhatsApp(
              AppHelpers.supportWhatsAppNumber,
              'مرحبا، أحتاج إلى الدعم الفني في الغيث',
            ),
          ),
          _SupportCard(
            title: 'اتصال',
            subtitle: AppHelpers.supportPhoneNumber,
            icon: Icons.phone_rounded,
            onTap: () => AppHelpers.makePhoneCall(AppHelpers.supportPhoneNumber),
          ),
          _SupportCard(
            title: 'فيسبوك',
            subtitle: 'صفحة الغيث الرسمية',
            icon: Icons.facebook_rounded,
            onTap: AppHelpers.openFacebookPage,
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onTap;

  const _SupportCard({
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepOrange.withValues(alpha: 0.10),
                  child: iconWidget ?? Icon(icon, color: Colors.deepOrange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
