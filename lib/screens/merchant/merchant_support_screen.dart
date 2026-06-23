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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: iconWidget ?? Icon(icon, size: 32),
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Cairo')),
        onTap: onTap,
      ),
    );
  }
}
