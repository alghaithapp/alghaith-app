import 'package:flutter/material.dart';

import '../../screens/merchant/merchant_store_settings_screen.dart';
import '../../screens/merchant/product_form_screen.dart';
import '../../screens/real_estate_form_screen.dart';
import '../../utils/merchant_service_labels.dart';

/// يفتح شاشة النشر المناسبة حسب نوع الخدمة.
void openMerchantPublisher(BuildContext context, String serviceId) {
  if (serviceId == 'professionals') {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MerchantStoreSettingsScreen()),
    );
    return;
  }
  if (serviceId == 'real_estate') {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RealEstateFormScreen(mode: 'sell')),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductFormScreen(
        isRestaurant: serviceId == 'restaurant',
        serviceId: serviceId,
      ),
    ),
  );
}

String merchantPublishLabel(String serviceId) {
  switch (normalizeMerchantServiceId(serviceId)) {
    case 'restaurant':
      return 'نشر منيو';
    case 'product':
      return 'نشر منتجات';
    case 'offers':
      return 'نشر عرض';
    case 'real_estate':
      return 'نشر عقار';
    case 'professionals':
      return 'تحديث الملف';
    case 'cars':
      return 'نشر سيارة';
    case 'tourism':
      return 'نشر باقة';
    case 'used':
      return 'نشر إعلان';
    default:
      return 'نشر ${merchantServiceLabels(serviceId).itemSingularAr}';
  }
}

String merchantPublishSubtitle(String serviceId) {
  switch (normalizeMerchantServiceId(serviceId)) {
    case 'restaurant':
      return 'أضف وجباتك ومنيو مطعمك مباشرة.';
    case 'product':
      return 'أنشئ منتجًا واختر القسم الفرعي المناسب.';
    case 'offers':
      return 'أضف عروضك ومنتجاتك المخفّضة.';
    case 'real_estate':
      return 'أنشئ إعلان بيع أو إيجار للعقار.';
    case 'professionals':
      return 'حدّث ملفك المهني وبيانات التواصل.';
    case 'cars':
      return 'أنشئ إعلانًا أو خدمة خاصة بالسيارات.';
    case 'tourism':
      return 'أضف باقاتك وعروض السفر.';
    case 'used':
      return 'انشر إعلانات المستعمل.';
    default:
      return 'ابدأ النشر في هذه الخدمة.';
  }
}

class MerchantQuickPublishPanel extends StatelessWidget {
  final List<String> serviceIds;
  final String activeServiceId;
  final Future<void> Function(String serviceId) onActivate;
  final Future<void> Function(String serviceId) onPublish;
  final String? subtitle;

  const MerchantQuickPublishPanel({
    super.key,
    required this.serviceIds,
    required this.activeServiceId,
    required this.onActivate,
    required this.onPublish,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (serviceIds.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نشر سريع حسب الخدمة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle ?? 'اضغط على الخدمة المناسبة ثم ابدأ النشر مباشرة.',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              height: 1.4,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 14),
          ...serviceIds.map((serviceId) {
            final labels = merchantServiceLabels(serviceId);
            final selected = serviceId == activeServiceId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ServicePublishCard(
                title: labels.storeLabelAr,
                subtitle: merchantPublishSubtitle(serviceId),
                active: selected,
                publishLabel: merchantPublishLabel(serviceId),
                onActivate: selected ? null : () => onActivate(serviceId),
                onPublish: () => onPublish(serviceId),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ServicePublishCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final String publishLabel;
  final VoidCallback? onActivate;
  final Future<void> Function() onPublish;

  const _ServicePublishCard({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.publishLabel,
    required this.onActivate,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onActivate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Colors.deepOrange.withValues(alpha: 0.06)
              : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? Colors.deepOrange.withValues(alpha: 0.25)
                : const Color(0xFFE6E8F0),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsetsDirectional.only(end: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.deepOrange.withValues(alpha: 0.12)
                              : Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          active ? 'الحالية' : 'مفعلة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.deepOrange : Colors.green,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: () async => onPublish(),
              icon: const Icon(Icons.add_rounded, size: 18),
              tooltip: publishLabel,
              style: IconButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
