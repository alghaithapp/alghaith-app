import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';
import '../../utils/dummy_data.dart';
import '../../widgets/app_image.dart';
import '../../widgets/merchant/quick_publish_panel.dart';
import '../real_estate_form_screen.dart';
import 'product_form_screen.dart';

class MerchantProductsScreen extends StatefulWidget {
  const MerchantProductsScreen({super.key});

  @override
  State<MerchantProductsScreen> createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  final _searchController = TextEditingController();
  bool _isSyncingCatalog = false;

  bool _ensureCanPublish(AppProvider provider, String serviceId) {
    if (provider.canPublishForService(serviceId)) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('حدد موقع المتجر على الخريطة قبل نشر المنتجات.'),
      ),
    );
    return false;
  }

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

  Future<void> _syncCatalogNow(AppProvider provider) async {
    if (_isSyncingCatalog) return;
    setState(() => _isSyncingCatalog = true);
    try {
      await provider.syncMerchantCatalogToCloud();
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
        setState(() => _isSyncingCatalog = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
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
                          service.titleAr,
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
                      label: 'الإجمالي',
                      value: '${provider.merchantProductCount}',
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'المتاح',
                      value: '${items.where((e) => e.isAvailable).length}',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'غير متاح',
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
                  hintText: labels.searchPlaceholderAr,
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
        MerchantQuickPublishPanel(
          serviceIds: provider.merchantServiceIds,
          activeServiceId: serviceId,
          onActivate: provider.setMerchantActiveService,
          subtitle: 'اختر الخدمة ثم ابدأ النشر مباشرة من هنا.',
          onPublish: (selectedServiceId) async {
            await provider.setMerchantActiveService(selectedServiceId);
            if (!context.mounted) return;
            if (!_ensureCanPublish(provider, selectedServiceId)) return;
            openMerchantPublisher(context, selectedServiceId);
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                labels.productsTitleAr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isSyncingCatalog
                  ? null
                  : () => _syncCatalogNow(provider),
              icon: _isSyncingCatalog
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(_isSyncingCatalog ? 'جاري' : 'مزامنة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                side: const BorderSide(color: Colors.deepOrange),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                if (!_ensureCanPublish(provider, serviceId)) return;
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
              label: Text(labels.addItemAr),
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
                'لا توجد ${labels.itemPluralAr} هنا',
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

class _ProductCard extends StatelessWidget {
  final ListItem item;
  final VoidCallback onToggleAvailability;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.item,
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
                  item.nameAr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.descriptionAr,
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
                            ? 'متوفر'
                            : 'غير متوفر',
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
