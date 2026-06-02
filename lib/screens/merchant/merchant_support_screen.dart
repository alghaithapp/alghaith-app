import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/helpers.dart';
import '../../widgets/whatsapp_icon.dart';

class MerchantSupportScreen extends StatelessWidget {
  const MerchantSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.merchantLabels;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: Text(
          'دعم ${labels.storeLabelAr}',
          style: const TextStyle(
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
            subtitle: 'تواصل سريع مع فريق دعم ${labels.storeLabelAr}',
            iconWidget: const WhatsAppIcon(size: 36),
            onTap: () => AppHelpers.launchWhatsApp(
              AppHelpers.supportWhatsAppNumber,
              'مرحبا، لدي مشكلة في حساب ${labels.storeLabelAr}',
            ),
          ),
          _SupportCard(
            title: 'اتصال',
            subtitle: 'اتصل مباشرة بالدعم بخصوص ${labels.storeLabelAr}',
            icon: Icons.phone_rounded,
            onTap: () => AppHelpers.makePhoneCall('07701234567'),
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
