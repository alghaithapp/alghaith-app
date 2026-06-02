import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/image_storage_service.dart';
import '../../utils/extensions.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_image.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/merchant/merchant_components.dart';
import '../../widgets/merchant/quick_publish_panel.dart';
import 'merchant_profile_screen.dart';
import 'order_details_screen.dart';

class MerchantDashboardScreen extends StatelessWidget {
  const MerchantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.merchantActiveLabels;
    final recentOrders = provider.merchantIncomingOrders.take(3).toList();
    final alerts = provider.notifications.take(3).toList();
    final profileImageBase64 = provider.merchantProfileImageBase64;
    final workSamples = provider.merchantWorkSampleImagesBase64;
    final showWorkSamples = provider.merchantActiveServiceId != 'restaurant' &&
        workSamples.isNotEmpty;
    final storeName = provider.merchantStoreName.trim().isNotEmpty
        ? provider.merchantStoreName
        : 'حساب التاجر';
    final coverImage = provider.merchantCoverImage.trim();
    DecorationImage? headerImage;
    if (coverImage.isNotEmpty) {
      if (ImageStorageService.isRemoteUrl(coverImage)) {
        headerImage =
            DecorationImage(image: NetworkImage(coverImage), fit: BoxFit.cover);
      } else {
        final looksBase64 =
            coverImage.startsWith('iVBOR') || coverImage.startsWith('/9j/');
        if (looksBase64) {
          headerImage = DecorationImage(
            image: MemoryImage(base64Decode(coverImage)),
            fit: BoxFit.cover,
          );
        }
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
                            'أهلاً $storeName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels.dashboardIntroAr,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _OpenStatusChip(
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
                  phone: provider.merchantPhone,
                  whatsapp: provider.merchantWhatsApp.isNotEmpty ? provider.merchantWhatsApp : provider.merchantPhone,
                  showWorkSamples: showWorkSamples,
                  workSamplesCount: workSamples.length,
                ),
                if (showWorkSamples) ...[
                  const SizedBox(height: 10),
                  _WorkSamplesStrip(
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
                        const Text('عرض الملف الكامل'),
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
            child: MerchantQuickPublishPanel(
              serviceIds: provider.merchantServiceIds,
              activeServiceId: provider.merchantActiveServiceId,
              onActivate: provider.setMerchantActiveService,
              onPublish: (serviceId) async {
                await provider.setMerchantActiveService(serviceId);
                if (!context.mounted) return;
                if (!provider.canPublishForService(serviceId)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('حدد موقع المتجر على الخريطة قبل نشر المنتجات.'),
                    ),
                  );
                  return;
                }
                openMerchantPublisher(context, serviceId);
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _DashboardSyncCatalogButton(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                MerchantMetricCard(
                  label: 'إجمالي ${labels.itemPluralAr}',
                  value: '${provider.merchantProductCount}',
                  icon: Icons.inventory_2_rounded,
                  color: Colors.blue,
                ),
                MerchantMetricCard(
                  label: 'طلبات جديدة',
                  value: '${provider.merchantPendingOrdersCount}',
                  icon: Icons.notifications_active_rounded,
                  color: Colors.orange,
                ),
                MerchantMetricCard(
                  label: 'المكتملة',
                  value: '${provider.merchantCompletedOrdersCount}',
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                ),
                MerchantMetricCard(
                  label: 'مبيعات اليوم',
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'معدل القبول',
                      value:
                          '${provider.merchantAcceptanceRate.toStringAsFixed(1)}%',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'معدل الرفض',
                      value:
                          '${provider.merchantRejectionRate.toStringAsFixed(1)}%',
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'متوسط الرد',
                      value:
                          '${provider.merchantAverageResponseMinutes.toStringAsFixed(1)} د',
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: MerchantSectionHeader(
              title: 'آخر طلبات ${labels.storeLabelAr}',
              subtitle: 'اضغط على أي طلب لعرض التفاصيل وتنفيذ الإجراءات.',
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
                  orderNumber: provider.displayOrderNumber(order),
                  title: order.itemsNameAr,
                  subtitle: order.dateAr,
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
                  title: 'تنبيهات مهمة',
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MerchantQuickInfoRow extends StatelessWidget {
  final String phone;
  final String whatsapp;
  final bool showWorkSamples;
  final int workSamplesCount;

  const _MerchantQuickInfoRow({
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
          label: 'الهاتف',
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
            label: 'نماذج الأعمال',
            value: workSamplesCount.toString(),
            icon: Icons.photo_library_rounded,
          ),
      ],
    );
  }
}

class _DashboardSyncCatalogButton extends StatefulWidget {
  const _DashboardSyncCatalogButton();

  @override
  State<_DashboardSyncCatalogButton> createState() =>
      _DashboardSyncCatalogButtonState();
}

class _DashboardSyncCatalogButtonState extends State<_DashboardSyncCatalogButton> {
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
    return SizedBox(
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
          backgroundColor: Colors.white,
        ),
      ),
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
    final isActionChip = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActionChip
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActionChip ? Colors.greenAccent : Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkSamplesStrip extends StatelessWidget {
  final List<String> samples;
  final VoidCallback onTap;

  const _WorkSamplesStrip({
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
          child: const Text(
            'لا توجد صور أعمال بعد. اضغط لفتح الملف الكامل.',
            style: TextStyle(
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
            'معاينة صور الأعمال',
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
                  child: AppImage(
                    imageData: displaySamples[index],
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
  final bool isOpen;
  final VoidCallback onTap;

  const _OpenStatusChip({
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
                  ? 'المتجر مفتوح'
                  : 'المتجر مغلق',
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
