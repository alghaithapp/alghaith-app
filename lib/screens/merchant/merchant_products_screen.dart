import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';
import '../../utils/dummy_data.dart';
import '../../utils/merchant_service_labels.dart';
import '../../widgets/app_image.dart';
import '../merchant/merchant_store_settings_screen.dart';
import '../real_estate_form_screen.dart';
import 'product_form_screen.dart';

class MerchantProductsScreen extends StatefulWidget {
  const MerchantProductsScreen({super.key});

  @override
  State<MerchantProductsScreen> createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';
    final labels = provider.merchantActiveLabels;
    final serviceId = provider.merchantActiveServiceId;
    final serviceIds = provider.merchantServiceIds;
    final query = _searchController.text.trim().toLowerCase();
    final items = provider.merchantItems.where((item) {
      if (query.isEmpty) return true;
      return item.nameAr.toLowerCase().contains(query) ||
          item.nameEn.toLowerCase().contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              if (provider.merchantHasMultipleServices) ...[
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final currentId = serviceIds[index];
                      final service = DummyData.categories.firstWhere(
                        (category) => category.id == currentId,
                        orElse: () => DummyData.categories.first,
                      );
                      final selected = currentId == serviceId;
                      return ChoiceChip(
                        label: Text(
                          isAr ? service.titleAr : service.titleEn,
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                        selected: selected,
                        onSelected: (_) =>
                            provider.setMerchantActiveService(currentId),
                        selectedColor: Colors.deepOrange,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: serviceIds.length,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: isAr ? 'الإجمالي' : 'Total',
                      value: '${provider.merchantProductCount}',
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: isAr ? 'المتاح' : 'Available',
                      value: '${items.where((e) => e.isAvailable).length}',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: isAr ? 'غير متاح' : 'Hidden',
                      value: '${items.where((e) => !e.isAvailable).length}',
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: isAr
                      ? labels.searchPlaceholderAr
                      : labels.searchPlaceholderEn,
                  filled: true,
                  fillColor: const Color(0xFFF6F6F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _QuickPublishPanel(
          isAr: isAr,
          serviceIds: provider.merchantServiceIds,
          activeServiceId: serviceId,
          onActivate: provider.setMerchantActiveService,
          onPublish: (selectedServiceId) async {
            await provider.setMerchantActiveService(selectedServiceId);
            if (!context.mounted) return;
            _openPublisher(context, selectedServiceId);
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                isAr ? labels.productsTitleAr : labels.productsTitleEn,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => serviceId == 'real_estate'
                        ? const RealEstateFormScreen(mode: 'sell')
                        : ProductFormScreen(
                            isRestaurant: serviceId == 'restaurant',
                            serviceId: serviceId,
                          ),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(isAr ? labels.addItemAr : labels.addItemEn),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                isAr
                    ? 'لا توجد ${labels.itemPluralAr} هنا'
                    : 'No ${labels.itemPluralEn} here',
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey),
              ),
            ),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProductCard(
                item: item,
                isAr: isAr,
                onToggleAvailability: () {
                  item.isAvailable = !item.isAvailable;
                  provider.updateProduct(item);
                },
                onEdit: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => serviceId == 'real_estate'
                          ? RealEstateFormScreen(
                              mode: item.listingMode ?? 'sell',
                              item: item,
                            )
                          : ProductFormScreen(
                              isRestaurant: serviceId == 'restaurant',
                              serviceId: serviceId,
                              item: item,
                            ),
                    ),
                  );
                },
                onDelete: () => provider.deleteProduct(item.id),
              ),
            ),
          ),
      ],
    );
  }
}

void _openPublisher(BuildContext context, String serviceId) {
  Widget page;
  if (serviceId == 'professionals') {
    page = const MerchantStoreSettingsScreen();
  } else if (serviceId == 'real_estate') {
    page = const RealEstateFormScreen(mode: 'sell');
  } else {
    page = ProductFormScreen(
      isRestaurant: serviceId == 'restaurant',
      serviceId: serviceId,
    );
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
              fontSize: 15,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAr
                ? 'اختر الخدمة ثم ابدأ النشر مباشرة من هنا.'
                : 'Choose a service and start publishing from here.',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              height: 1.4,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          ...serviceIds.map((serviceId) {
            final labels = merchantServiceLabels(serviceId);
            final selected = serviceId == activeServiceId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: selected ? null : () => onActivate(serviceId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.deepOrange.withValues(alpha: 0.06)
                        : const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
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
                                    isAr ? labels.storeLabelAr : labels.storeLabelEn,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.deepOrange.withValues(alpha: 0.12)
                                        : Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    selected
                                        ? (isAr ? 'الحالية' : 'Current')
                                        : (isAr ? 'مفعلة' : 'Enabled'),
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      color: selected ? Colors.deepOrange : Colors.green,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _publishSubtitle(serviceId, isAr),
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
                        onPressed: () async => onPublish(serviceId),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        tooltip: _publishLabel(serviceId, isAr),
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
              ),
            );
          }),
        ],
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
      return isAr ? 'ابدأ النشر في هذه الخدمة.' : 'Start publishing here.';
  }
}

class _ProductCard extends StatelessWidget {
  final ListItem item;
  final bool isAr;
  final VoidCallback onToggleAvailability;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.item,
    required this.isAr,
    required this.onToggleAvailability,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = AppImage(
      imageData: item.imageBase64 != null && item.imageBase64!.isNotEmpty
          ? item.imageBase64
          : item.image,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 74,
              height: 74,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageWidget,
                  if (!item.isAvailable)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: Text(
                          'غير متوفر',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo',
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? item.nameAr : item.nameEn,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAr ? item.descriptionAr : item.descriptionEn,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${item.price.toPrice()} د.ع',
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (item.isAvailable ? Colors.green : Colors.red)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.isAvailable
                            ? (isAr ? 'متوفر' : 'Available')
                            : (isAr ? 'غير متوفر' : 'Unavailable'),
                        style: TextStyle(
                          color: item.isAvailable ? Colors.green : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onToggleAvailability,
                icon: Icon(
                  item.isAvailable
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: item.isAvailable ? Colors.green : Colors.red,
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_rounded, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
