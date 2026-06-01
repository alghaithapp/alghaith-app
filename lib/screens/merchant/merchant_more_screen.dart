import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/whatsapp_icon.dart';
import 'merchant_notifications_screen.dart';
import 'merchant_offers_screen.dart';
import 'merchant_profile_screen.dart';
import 'merchant_reviews_screen.dart';
import 'merchant_store_settings_screen.dart';
import 'merchant_support_screen.dart';

class MerchantMoreScreen extends StatelessWidget {
  const MerchantMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';
    final labels = provider.merchantActiveLabels;
    final profileImageBase64 = provider.merchantProfileImageBase64;
    final workSamples = provider.merchantWorkSampleImagesBase64;
    final showWorkSamples = provider.merchantActiveServiceId != 'restaurant' &&
        workSamples.isNotEmpty;
    final storeName = provider.merchantStoreName.trim().isNotEmpty
        ? provider.merchantStoreName
        : (isAr ? 'حساب التاجر' : 'Merchant account');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF111111), Color(0xFF2E2E2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(size: 28),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(18),
                      image: profileImageBase64 != null &&
                              profileImageBase64.isNotEmpty
                          ? DecorationImage(
                              image:
                                  MemoryImage(base64Decode(profileImageBase64)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: profileImageBase64 != null &&
                            profileImageBase64.isNotEmpty
                        ? null
                        : const Icon(Icons.storefront_rounded,
                            color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAr
                              ? '${labels.storeLabelAr} - القائمة الإضافية'
                              : '${labels.storeLabelEn} - More options',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MiniProfileCard(
          isAr: isAr,
          phone: provider.merchantPhone,
          whatsapp: provider.merchantWhatsApp,
          showWorkSamples: showWorkSamples,
          workSamplesCount: workSamples.length,
          samples: workSamples,
          onOpenProfile: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const MerchantProfileScreen(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _MoreTile(
          title: isAr ? 'العروض والخصومات' : 'Offers & Discounts',
          subtitle:
              isAr ? 'أنشئ عروضًا وخصومات بسهولة' : 'Create and manage offers',
          icon: Icons.local_offer_rounded,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantOffersScreen())),
        ),
        _MoreTile(
          title: isAr ? 'التقييمات' : 'Reviews',
          subtitle: isAr
              ? 'اقرأ ورد على تقييمات العملاء'
              : 'Read and reply to customer reviews',
          icon: Icons.star_rounded,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantReviewsScreen())),
        ),
        _MoreTile(
          title:
              isAr ? labels.storeSettingsTitleAr : labels.storeSettingsTitleEn,
          subtitle: isAr
              ? 'تعديل بيانات ${labels.storeLabelAr} وأوقات العمل'
              : 'Edit store details and business hours',
          icon: Icons.settings_rounded,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MerchantStoreSettingsScreen())),
        ),
        _MoreTile(
          title: isAr ? 'الإشعارات' : 'Notifications',
          subtitle: isAr
              ? 'تنبيهات ${labels.storeLabelAr} والطلبات والتقييمات'
              : 'Orders, reviews and commission alerts',
          icon: Icons.notifications_rounded,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MerchantNotificationsScreen())),
        ),
        _MoreTile(
          title: isAr ? 'الدعم الفني' : 'Support',
          subtitle: isAr
              ? 'تواصل سريع عبر واتساب أو الاتصال بخصوص ${labels.storeLabelAr}'
              : 'Quick help via WhatsApp or phone',
          icon: Icons.support_agent_rounded,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantSupportScreen())),
        ),
        _MoreTile(
          title: isAr ? 'الانتقال إلى حساب الزبون' : 'Switch to customer',
          subtitle: isAr
              ? 'استخدم نفس التسجيل وانتقل لواجهة الزبون'
              : 'Keep the same login and open the customer view',
          icon: Icons.person_rounded,
          onTap: () => provider.setUserRole('customer'),
        ),
        _MoreTile(
          title: isAr ? 'تسجيل الخروج' : 'Logout',
          subtitle:
              isAr ? 'العودة إلى شاشة الدخول' : 'Return to the login screen',
          icon: Icons.logout_rounded,
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(isAr ? 'تسجيل الخروج' : 'Logout'),
                content: Text(isAr
                    ? 'هل تريد تسجيل الخروج من حساب التاجر؟'
                    : 'Do you want to log out of the merchant account?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(isAr ? 'إلغاء' : 'Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(isAr ? 'خروج' : 'Logout')),
                ],
              ),
            );
            if (confirmed == true) {
              provider.resetAll();
            }
          },
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => AppHelpers.launchWhatsApp(
              AppHelpers.supportWhatsAppNumber,
              isAr
                  ? 'مرحبا، أحتاج إلى الدعم الفني في الغيث'
                  : 'Hello, I need support for Al-Ghaith.'),
          icon: const WhatsAppIcon(size: 36),
          label: Text(isAr ? 'واتساب الدعم' : 'Support WhatsApp'),
        ),
      ],
    );
  }
}

class _MiniProfileCard extends StatelessWidget {
  final bool isAr;
  final String phone;
  final String whatsapp;
  final bool showWorkSamples;
  final int workSamplesCount;
  final List<String> samples;
  final VoidCallback onOpenProfile;

  const _MiniProfileCard({
    required this.isAr,
    required this.phone,
    required this.whatsapp,
    required this.showWorkSamples,
    required this.workSamplesCount,
    required this.samples,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final phoneValue = phone.trim().isNotEmpty ? phone : '-';
    final whatsappValue = whatsapp.trim().isNotEmpty ? whatsapp : '-';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'ملخص الملف' : 'Profile summary',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          _RowInfo(label: isAr ? 'الهاتف' : 'Phone', value: phoneValue),
          _RowInfo(label: 'WhatsApp', value: whatsappValue),
          if (showWorkSamples)
            _RowInfo(
                label: isAr ? 'نماذج الأعمال' : 'Work samples',
                value: workSamplesCount.toString()),
          const SizedBox(height: 10),
          if (showWorkSamples && samples.isNotEmpty) ...[
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: samples.take(4).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final image = samples[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      base64Decode(image),
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onOpenProfile,
              icon: const Icon(Icons.badge_rounded, size: 18),
              label: Text(isAr ? 'فتح الملف الكامل' : 'Open full profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowInfo extends StatelessWidget {
  final String label;
  final String value;

  const _RowInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontFamily: 'Cairo',
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MoreTile({
    required this.title,
    required this.subtitle,
    required this.icon,
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.deepOrange),
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
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
