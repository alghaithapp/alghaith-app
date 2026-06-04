import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/account_role_switch.dart';
import '../../widgets/app_image.dart';
import '../../widgets/app_logo.dart';
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
    final labels = provider.merchantActiveLabels;
    final profileImage = provider.merchantProfileImageBase64;
    final workSamples = provider.merchantWorkSampleImagesBase64;
    final showWorkSamples = provider.merchantActiveServiceId != 'restaurant' &&
        workSamples.isNotEmpty;
    final storeName = provider.merchantStoreName.trim().isNotEmpty
        ? provider.merchantStoreName
        : 'حساب التاجر';
    final cardColor = Theme.of(context).colorScheme.surface;

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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: profileImage != null && profileImage.isNotEmpty
                          ? AppImage(
                              imageData: profileImage,
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.deepOrange.withValues(alpha: 0.18),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                              ),
                            ),
                    ),
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
                          '${labels.storeLabelAr} - القائمة الإضافية',
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
          cardColor: cardColor,
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
        const SizedBox(height: 12),
        _SyncCatalogButton(cardColor: cardColor),
        const SizedBox(height: 16),
        _MoreTile(
          cardColor: cardColor,
          title: 'العروض والخصومات',
          subtitle: 'أنشئ عروضًا وخصومات بسهولة',
          icon: Icons.local_offer_rounded,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantOffersScreen())),
        ),
        _MoreTile(
          cardColor: cardColor,
          title: 'التقييمات',
          subtitle: 'اقرأ ورد على تقييمات العملاء',
          icon: Icons.star_rounded,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantReviewsScreen())),
        ),
        _MoreTile(
          cardColor: cardColor,
          title:
              labels.storeSettingsTitleAr,
          subtitle: 'تعديل بيانات ${labels.storeLabelAr} وأوقات العمل',
          icon: Icons.settings_rounded,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MerchantStoreSettingsScreen())),
        ),
        _MoreTile(
          cardColor: cardColor,
          title: 'الإشعارات',
          subtitle: 'تنبيهات ${labels.storeLabelAr} والطلبات والتقييمات',
          icon: Icons.notifications_rounded,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MerchantNotificationsScreen())),
        ),
        _MoreTile(
          cardColor: cardColor,
          title: 'الدعم الفني',
          subtitle: 'تواصل سريع عبر واتساب أو الاتصال مع فريق الدعم',
          icon: Icons.support_agent_rounded,
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantSupportScreen())),
        ),
        _MoreTile(
          cardColor: cardColor,
          title: 'الانتقال إلى حساب الزبون',
          subtitle: 'استخدم نفس التسجيل وانتقل لواجهة الزبون',
          icon: Icons.person_rounded,
          onTap: () => switchAccountRoleWithLoading(
            context,
            provider,
            'customer',
            loadingMessage: 'يرجى الانتظار... جارٍ التحويل إلى حساب الزبون',
            errorMessage: 'تعذر الانتقال إلى حساب الزبون حالياً.',
          ),
        ),
        _MoreTile(
          cardColor: cardColor,
          title: 'الانتقال إلى حساب مندوب التوصيل',
          subtitle: provider.hasCourierProfile
              ? 'استخدم نفس التسجيل وانتقل لواجهة المندوب'
              : 'سجّل بيانات المندوب أولاً لتفعيل الحساب',
          icon: Icons.delivery_dining_rounded,
          onTap: () => switchAccountRoleWithLoading(
            context,
            provider,
            'delivery',
            loadingMessage: 'يرجى الانتظار... جارٍ التحويل إلى حساب المندوب',
            errorMessage: 'تعذر الانتقال إلى حساب المندوب حالياً.',
          ),
        ),
        _MoreTile(
          cardColor: cardColor,
          title: 'تسجيل الخروج',
          subtitle: 'العودة إلى شاشة الدخول',
          icon: Icons.logout_rounded,
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('تسجيل الخروج'),
                content: const Text('هل تريد تسجيل الخروج من حساب التاجر؟'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('خروج')),
                ],
              ),
            );
            if (confirmed == true) {
              provider.resetAll();
            }
          },
        ),
      ],
    );
  }
}

class _MiniProfileCard extends StatelessWidget {
  final Color cardColor;
  final String phone;
  final String whatsapp;
  final bool showWorkSamples;
  final int workSamplesCount;
  final List<String> samples;
  final VoidCallback onOpenProfile;

  const _MiniProfileCard({
    required this.cardColor,
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
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص الملف',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          _RowInfo(label: 'الهاتف', value: phoneValue),
          _RowInfo(label: 'WhatsApp', value: whatsappValue),
          if (showWorkSamples)
            _RowInfo(
                label: 'نماذج الأعمال',
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
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AppImage(
                      imageData: samples[index],
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
              label: const Text('فتح الملف الكامل'),
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
  final Color cardColor;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MoreTile({
    required this.cardColor,
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
        color: cardColor,
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

class _SyncCatalogButton extends StatefulWidget {
  final Color cardColor;

  const _SyncCatalogButton({required this.cardColor});

  @override
  State<_SyncCatalogButton> createState() => _SyncCatalogButtonState();
}

class _SyncCatalogButtonState extends State<_SyncCatalogButton> {
  bool _isSyncing = false;

  String _syncErrorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('Missing authorization token') ||
        raw.contains('Invalid authorization token') ||
        raw.contains('401')) {
      return 'انتهت جلسة الدخول. سجل الخروج ثم ادخل مرة أخرى.';
    }
    if (raw.contains('Network error')) {
      return 'فشل الاتصال بالإنترنت أو بالخادم. حاول مرة أخرى.';
    }
    final cleaned = raw.replaceFirst('Exception: ', '').trim();
    if (cleaned.isNotEmpty) return cleaned;
    return 'تعذرت المزامنة الآن. تحقق من الاتصال ثم أعد المحاولة.';
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await context.read<AppProvider>().syncMerchantCatalogToCloud();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت مزامنة بيانات المطعم والمنتجات بنجاح.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_syncErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isSyncing ? null : _syncNow,
          icon: _isSyncing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded, size: 18),
          label: Text(_isSyncing ? 'جاري المزامنة' : 'مزامنة بيانات المطعم والمنتجات'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepOrange,
            side: const BorderSide(color: Colors.deepOrange),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}
