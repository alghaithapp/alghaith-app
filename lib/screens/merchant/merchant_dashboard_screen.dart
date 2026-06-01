import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';
import '../../utils/helpers.dart';
import '../../utils/merchant_service_labels.dart';
import '../../widgets/app_image.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/merchant/merchant_components.dart';
import 'merchant_profile_screen.dart';
import 'order_details_screen.dart';
import 'merchant_store_settings_screen.dart';
import '../real_estate_form_screen.dart';
import 'product_form_screen.dart';

class MerchantDashboardScreen extends StatelessWidget {
  const MerchantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';
    final labels = provider.merchantActiveLabels;
    final recentOrders = provider.orders.take(3).toList();
    final alerts = provider.notifications.take(3).toList();
    final profileImageBase64 = provider.merchantProfileImageBase64;
    final workSamples = provider.merchantWorkSampleImagesBase64;
    final showWorkSamples = provider.merchantActiveServiceId != 'restaurant' &&
        workSamples.isNotEmpty;
    final storeName = provider.merchantStoreName.trim().isNotEmpty
        ? provider.merchantStoreName
        : (isAr ? 'حساب التاجر' : 'Merchant account');
    final coverImage = provider.merchantCoverImage.trim();
    DecorationImage? headerImage;
    if (coverImage.isNotEmpty) {
      final looksBase64 =
          coverImage.startsWith('iVBOR') || coverImage.startsWith('/9j/');
      if (looksBase64) {
        headerImage =
            DecorationImage(image: MemoryImage(base64Decode(coverImage)), fit: BoxFit.cover);
      }
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF111111), Color(0xFF272727)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: headerImage,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppLogo(size: 26),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: AppImage(
                        imageData: profileImageBase64,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${isAr ? 'أهلاً' : 'Welcome'} $storeName',
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
                                ? labels.dashboardIntroAr
                                : labels.dashboardIntroEn,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _OpenStatusChip(
                            isAr: isAr,
                            isOpen: provider.isMerchantStoreOpen,
                            onTap: provider.toggleMerchantOpenStatus,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MerchantQuickInfoRow(
                  isAr: isAr,
                  phone: provider.merchantPhone,
                  whatsapp: provider.merchantWhatsApp.isNotEmpty ? provider.merchantWhatsApp : provider.merchantPhone,
                  showWorkSamples: showWorkSamples,
                  workSamplesCount: workSamples.length,
                ),
                if (showWorkSamples) ...[
                  const SizedBox(height: 10),
                  _WorkSamplesStrip(
                    isAr: isAr,
                    samples: workSamples,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MerchantProfileScreen(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MerchantProfileScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.badge_rounded, size: 18),
                    label:
                        Text(isAr ? 'عرض الملف الكامل' : 'Open full profile'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _QuickPublishPanel(
              isAr: isAr,
              serviceIds: provider.merchantServiceIds,
              activeServiceId: provider.merchantActiveServiceId,
              onActivate: provider.setMerchantActiveService,
              onPublish: (serviceId) async {
                await provider.setMerchantActiveService(serviceId);
                if (serviceId == 'professionals') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MerchantStoreSettingsScreen(),
                    ),
                  );
                  return;
                }
                if (serviceId == 'real_estate') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RealEstateFormScreen(mode: 'sell'),
                    ),
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
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.35,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                MerchantMetricCard(
                  label: isAr ? 'إجمالي ${labels.itemPluralAr}' : 'Total ${labels.itemPluralEn}',
                  value: '${provider.merchantProductCount}',
                  icon: Icons.inventory_2_rounded,
                  color: Colors.blue,
                ),
                MerchantMetricCard(
                  label: isAr ? 'طلبات جديدة' : 'New Orders',
                  value: '${provider.merchantPendingOrdersCount}',
                  icon: Icons.notifications_active_rounded,
                  color: Colors.orange,
                ),
                MerchantMetricCard(
                  label: isAr ? 'المكتملة' : 'Completed',
                  value: '${provider.merchantCompletedOrdersCount}',
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                ),
                MerchantMetricCard(
                  label: isAr ? 'مبيعات اليوم' : 'Today Sales',
                  value: '${provider.totalSales.toPrice()} د.ع',
                  icon: Icons.payments_rounded,
                  color: Colors.purple,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: MerchantSectionHeader(
              title: isAr
                  ? 'آخر طلبات ${labels.storeLabelAr}'
                  : 'Latest ${labels.storeLabelEn} Orders',
              subtitle: isAr
                  ? 'اضغط على أي طلب لعرض التفاصيل وتنفيذ الإجراءات.'
                  : 'Tap an order to view details and act fast.',
            ),
          ),
        ),
        if (recentOrders.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: _EmptyDashboardCard(),
            ),
          )
        else
          SliverList.separated(
            itemCount: recentOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = recentOrders[index];
              return Padding(
                padding: EdgeInsets.fromLTRB(16, index == 0 ? 12 : 0, 16, 0),
                child: _RecentOrderCard(
                  orderNumber: order.orderNumber,
                  title: isAr ? order.itemsNameAr : order.itemsNameEn,
                  subtitle: isAr ? order.dateAr : order.dateEn,
                  price: order.price,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsScreen(order: order),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MerchantSectionHeader(
                  title: isAr ? 'تنبيهات مهمة' : 'Important Alerts',
                ),
                const SizedBox(height: 12),
                ...alerts.map(
                  (alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.campaign_rounded,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert['title']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alert['body']?.toString() ?? '',
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
                          Text(
                            '',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickPublishPanel extends StatelessWidget {
  final bool isAr;
  final List<String> serviceIds;
  final String activeServiceId;
  final Future<void> Function(String serviceId) onActivate;
  final Future<void> Function(String serviceId) onPublish;

  const _QuickPublishPanel({
    required this.isAr,
    required this.serviceIds,
    required this.activeServiceId,
    required this.onActivate,
    required this.onPublish,
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
          Text(
            isAr ? 'نشر سريع حسب الخدمة' : 'Quick publish by service',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAr
                ? 'اضغط على الخدمة المناسبة ثم ابدأ النشر مباشرة.'
                : 'Tap the right service and start publishing immediately.',
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
            final publishLabel = _publishLabel(serviceId, isAr);
            final subtitle = _publishSubtitle(serviceId, isAr);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ServicePublishCard(
                isAr: isAr,
                title: isAr ? labels.storeLabelAr : labels.storeLabelEn,
                subtitle: subtitle,
                active: selected,
                publishLabel: publishLabel,
                onActivate: selected ? null : () => onActivate(serviceId),
                onPublish: () async => onPublish(serviceId),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ServicePublishCard extends StatelessWidget {
  final bool isAr;
  final String title;
  final String subtitle;
  final bool active;
  final String publishLabel;
  final VoidCallback? onActivate;
  final Future<void> Function() onPublish;

  const _ServicePublishCard({
    required this.isAr,
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
                          active
                              ? (isAr ? 'الحالية' : 'Current')
                              : (isAr ? 'مفعلة' : 'Enabled'),
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
String _publishLabel(String serviceId, bool isAr) {
  switch (serviceId) {
    case 'restaurant':
      return isAr ? 'نشر منيو' : 'Publish menu';
    case 'product':
      return isAr ? 'نشر منتجات' : 'Publish products';
    case 'real_estate':
      return isAr ? 'نشر عقار' : 'Publish property';
    case 'professionals':
      return isAr ? 'تحديث الملف' : 'Update profile';
    case 'cars':
      return isAr ? 'نشر سيارة' : 'Publish car';
    default:
      return isAr ? 'نشر الآن' : 'Publish now';
  }
}

String _publishSubtitle(String serviceId, bool isAr) {
  switch (serviceId) {
    case 'restaurant':
      return isAr
          ? 'أضف وجباتك ومنيو مطعمك مباشرة.'
          : 'Add your meals and restaurant menu directly.';
    case 'product':
      return isAr
          ? 'أنشئ منتجًا واختر القسم الفرعي المناسب.'
          : 'Create a product and choose the right sub-category.';
    case 'real_estate':
      return isAr
          ? 'أنشئ إعلان بيع أو إيجار للعقار.'
          : 'Create a sale or rent property listing.';
    case 'professionals':
      return isAr
          ? 'حدّث ملفك المهني وبيانات التواصل.'
          : 'Update your professional profile and contact details.';
    case 'cars':
      return isAr
          ? 'أنشئ إعلانًا أو خدمة خاصة بالسيارات.'
          : 'Create a car listing or related service.';
    default:
      return isAr
          ? 'ابدأ النشر في هذه الخدمة.'
          : 'Start publishing in this service.';
  }
}

class _MerchantQuickInfoRow extends StatelessWidget {
  final bool isAr;
  final String phone;
  final String whatsapp;
  final bool showWorkSamples;
  final int workSamplesCount;

  const _MerchantQuickInfoRow({
    required this.isAr,
    required this.phone,
    required this.whatsapp,
    required this.showWorkSamples,
    required this.workSamplesCount,
  });

  @override
  Widget build(BuildContext context) {
    final phoneValue = phone.trim().isNotEmpty ? phone : '-';
    final whatsappValue = whatsapp.trim().isNotEmpty ? whatsapp : '-';
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MiniInfoChip(
          label: isAr ? 'الهاتف' : 'Phone',
          value: phoneValue,
          icon: Icons.call_rounded,
        ),
        _MiniInfoChip(
          label: 'WhatsApp',
          value: whatsappValue,
          icon: Icons.chat_rounded,
          onTap: whatsappValue != '-' ? () => AppHelpers.launchWhatsApp(whatsapp, "اختبار واتساب المتجر") : null,
        ),
        if (showWorkSamples)
          _MiniInfoChip(
            label: isAr ? 'نماذج الأعمال' : 'Samples',
            value: workSamplesCount.toString(),
            icon: Icons.photo_library_rounded,
          ),
      ],
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _MiniInfoChip({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: onTap != null 
              ? Colors.green.withValues(alpha: 0.3) 
              : Colors.white.withValues(alpha: 0.10)
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: onTap != null ? Colors.greenAccent : Colors.white, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkSamplesStrip extends StatelessWidget {
  final bool isAr;
  final List<String> samples;
  final VoidCallback onTap;

  const _WorkSamplesStrip({
    required this.isAr,
    required this.samples,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Text(
            isAr
                ? 'لا توجد صور أعمال بعد. اضغط لفتح الملف الكامل.'
                : 'No work samples yet. Tap to open the full profile.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      );
    }

    final displaySamples = samples.take(4).toList();
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'معاينة صور الأعمال' : 'Work samples preview',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: displaySamples.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    base64Decode(displaySamples[index]),
                    width: 78,
                    height: 78,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenStatusChip extends StatelessWidget {
  final bool isAr;
  final bool isOpen;
  final VoidCallback onTap;

  const _OpenStatusChip({
    required this.isAr,
    required this.isOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOpen
                  ? Icons.store_mall_directory_rounded
                  : Icons.do_not_disturb_on_rounded,
              color: isOpen ? Colors.greenAccent : Colors.redAccent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isOpen
                  ? (isAr ? 'المتجر مفتوح' : 'Store Open')
                  : (isAr ? 'المتجر مغلق' : 'Store Closed'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  final String orderNumber;
  final String title;
  final String subtitle;
  final int price;
  final VoidCallback onTap;

  const _RecentOrderCard({
    required this.orderNumber,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Colors.deepOrange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${price.toPrice()} د.ع',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.deepOrange,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDashboardCard extends StatelessWidget {
  const _EmptyDashboardCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 54, color: Colors.deepOrange),
          SizedBox(height: 10),
          Text(
            'لا توجد طلبات بعد',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
