import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/dummy_data.dart';
import '../../utils/extensions.dart';
import '../../utils/merchant_service_labels.dart';
import 'merchant_store_settings_screen.dart';
import '../real_estate_form_screen.dart';
import 'product_form_screen.dart';

class ManageProducts extends StatefulWidget {
  const ManageProducts({super.key});

  @override
  State<ManageProducts> createState() => _ManageProductsState();
}

class _ManageProductsState extends State<ManageProducts> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isAr = appProvider.lang == 'ar';
    final labels = appProvider.merchantActiveLabels;
    final activeServiceId = appProvider.merchantActiveServiceId;
    final serviceIds = appProvider.merchantServiceIds;
    final isRestaurant = activeServiceId == 'restaurant';
    final title = isAr ? labels.productsTitleAr : labels.productsTitleEn;
    final allItems = appProvider.merchantItems;
    final search = _searchController.text.trim().toLowerCase();
    final products = search.isEmpty
        ? allItems
        : allItems.where((item) {
            return item.nameAr.toLowerCase().contains(search) ||
                item.nameEn.toLowerCase().contains(search);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: Color(0x11000000))),
        middle: Text(
          title,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => activeServiceId == 'real_estate'
                  ? const RealEstateFormScreen(mode: 'sell')
                  : ProductFormScreen(
                      isRestaurant: isRestaurant,
                      serviceId: activeServiceId,
                    ),
            ),
          ),
          child: const Icon(CupertinoIcons.add_circled_solid,
              color: Colors.orange),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    if (appProvider.merchantHasMultipleServices) ...[
                      SizedBox(
                        height: 46,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: serviceIds.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final serviceId = serviceIds[index];
                            final category = DummyData.categories.firstWhere(
                              (element) => element.id == serviceId,
                              orElse: () => DummyData.categories.first,
                            );
                            final selected = serviceId == activeServiceId;
                            return ChoiceChip(
                              label: Text(
                                isAr ? category.titleAr : category.titleEn,
                                style: const TextStyle(fontFamily: 'Cairo'),
                              ),
                              selected: selected,
                              onSelected: (_) => appProvider
                                  .setMerchantActiveService(serviceId),
                              selectedColor: Colors.deepOrange,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            isAr ? 'الإجمالي' : 'Total',
                            '${allItems.length}',
                            CupertinoIcons.square_grid_2x2_fill,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                            isAr ? 'المعروض' : 'Visible',
                            '${products.length}',
                            CupertinoIcons.eye_fill,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CupertinoSearchTextField(
                      controller: _searchController,
                      placeholder: isAr
                          ? labels.searchPlaceholderAr
                          : labels.searchPlaceholderEn,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _QuickPublishPanel(
                isAr: isAr,
                serviceIds: serviceIds,
                activeServiceId: activeServiceId,
                onActivate: appProvider.setMerchantActiveService,
                onPublish: (selectedServiceId) async {
                  await appProvider.setMerchantActiveService(selectedServiceId);
                  if (!context.mounted) return;
                  _openPublisher(context, selectedServiceId);
                },
              ),
            ),
            Expanded(
              child: products.isEmpty
                  ? _EmptyProductsState(
                      isAr: isAr,
                      isRestaurant: isRestaurant,
                      itemSingularAr: labels.itemSingularAr,
                      itemSingularEn: labels.itemSingularEn,
                      itemPluralAr: labels.itemPluralAr,
                      itemPluralEn: labels.itemPluralEn,
                      addItemAr: labels.addItemAr,
                      addItemEn: labels.addItemEn,
                      onAdd: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => ProductFormScreen(
                            isRestaurant: isRestaurant,
                            serviceId: activeServiceId,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final item = products[index];
                        return _ProductCard(
                          item: item,
                          isAr: isAr,
                          isRestaurant: isRestaurant,
                          onEdit: () => Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => activeServiceId == 'real_estate'
                                  ? RealEstateFormScreen(
                                      mode: item.listingMode ?? 'sell',
                                      item: item,
                                    )
                                  : ProductFormScreen(
                                      isRestaurant: isRestaurant,
                                      serviceId: activeServiceId,
                                      item: item,
                                    ),
                            ),
                          ),
                          onDelete: () => appProvider.deleteProduct(item.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
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
  Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
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
                        onPressed: () async => onPublish(serviceId),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat(this.label, this.value, this.icon, this.color);

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
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ListItem item;
  final bool isAr;
  final bool isRestaurant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.item,
    required this.isAr,
    required this.isRestaurant,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = item.imageBase64 != null && item.imageBase64!.isNotEmpty
        ? Image.memory(
            base64Decode(item.imageBase64!),
            width: 74,
            height: 74,
            fit: BoxFit.cover,
          )
        : Image.asset(
            item.image,
            width: 74,
            height: 74,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 74,
                height: 74,
                color: Colors.grey.shade200,
                child: Icon(
                  isRestaurant
                      ? CupertinoIcons.bag_fill
                      : CupertinoIcons.cube_box_fill,
                  color: Colors.grey,
                ),
              );
            },
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageWidget,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? item.nameAr : item.nameEn,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 4),
                Text(
                  isAr ? item.descriptionAr : item.descriptionEn,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.price.toPrice()} د.ع',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                onPressed: onEdit,
                child: const Icon(CupertinoIcons.pencil_circle,
                    color: Colors.blue, size: 28),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                onPressed: onDelete,
                child: const Icon(CupertinoIcons.delete_solid,
                    color: Colors.red, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  final bool isAr;
  final bool isRestaurant;
  final String itemSingularAr;
  final String itemSingularEn;
  final String itemPluralAr;
  final String itemPluralEn;
  final String addItemAr;
  final String addItemEn;
  final VoidCallback onAdd;

  const _EmptyProductsState({
    required this.isAr,
    required this.isRestaurant,
    required this.itemSingularAr,
    required this.itemSingularEn,
    required this.itemPluralAr,
    required this.itemPluralEn,
    required this.addItemAr,
    required this.addItemEn,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRestaurant
                    ? CupertinoIcons.rectangle_stack_badge_plus
                    : CupertinoIcons.cube_box_fill,
                size: 56,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              Text(
                isAr ? 'لا توجد $itemPluralAr بعد' : 'No $itemPluralEn yet',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 6),
              Text(
                isAr
                    ? 'أضف أول $itemSingularAr حتى يظهر الحساب بشكل متكامل.'
                    : 'Add your first ${itemSingularEn.toLowerCase()} to complete the store experience.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.4,
                    fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(16),
                onPressed: onAdd,
                child: Text(
                  isAr ? addItemAr : addItemEn,
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
