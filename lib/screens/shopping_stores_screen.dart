import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/supabase_service.dart';
import '../utils/extensions.dart';
import '../utils/helpers.dart';
import '../../widgets/app_image.dart';

class ShoppingStoresScreen extends StatefulWidget {
  final ServiceCategory subCategory;

  const ShoppingStoresScreen({
    super.key,
    required this.subCategory,
  });

  @override
  State<ShoppingStoresScreen> createState() => _ShoppingStoresScreenState();
}

class _ShoppingStoresScreenState extends State<ShoppingStoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _futureStores;

  @override
  void initState() {
    super.initState();
    _futureStores = SupabaseService.loadShoppingStores(
      subCategoryId: widget.subCategory.id,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final query = _searchController.text.trim().toLowerCase();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? widget.subCategory.titleAr : widget.subCategory.titleEn,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        previousPageTitle: isAr ? 'الرجوع' : 'Back',
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: isAr ? 'ابحث عن سوق أو محل' : 'Search a store',
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _futureStores,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }

                  if (snapshot.hasError) {
                    return _EmptyState(
                      message:
                          isAr ? 'تعذر تحميل الأسواق' : 'Failed to load stores',
                      isAr: isAr,
                    );
                  }

                  final stores = snapshot.data ?? const [];
                  final filtered = stores.where((store) {
                    final profile = Map<String, dynamic>.from(
                      store['profile'] as Map,
                    );
                    final storeName =
                        profile['store_name']?.toString().toLowerCase() ?? '';
                    final description =
                        profile['description']?.toString().toLowerCase() ?? '';
                    if (query.isEmpty) return true;
                    return storeName.contains(query) ||
                        description.contains(query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return _EmptyState(
                      isAr: isAr,
                      message: query.isEmpty
                          ? (isAr
                              ? 'لا توجد أسواق أو محلات في هذا القسم بعد'
                              : 'No stores in this category yet')
                          : (isAr
                              ? 'لا توجد نتائج مطابقة'
                              : 'No matching stores'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _StoreCard(
                        isAr: isAr,
                        data: filtered[index],
                        subCategory: widget.subCategory,
                      );
                    },
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

class _StoreCard extends StatelessWidget {
  final bool isAr;
  final Map<String, dynamic> data;
  final ServiceCategory subCategory;

  const _StoreCard({
    required this.isAr,
    required this.data,
    required this.subCategory,
  });

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(data['profile'] as Map);
    final products = (data['products'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final profileImageBase64 = profile['profile_image_base64']?.toString();
    final workSamples = profile['work_sample_images_base64'];
    final samples = workSamples is List
        ? workSamples.map((item) => item.toString()).toList()
        : const <String>[];
    final address = profile['address']?.toString().trim() ?? '';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF4E7), Color(0xFFFFFBF5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: AppImage(
                    imageData: profileImageBase64,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile['store_name']?.toString() ??
                            (isAr ? 'متجر' : 'Store'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile['description']?.toString() ??
                            (isAr
                                ? 'منيو حقيقي من نفس المتجر'
                                : 'Live menu from the same store'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.grey,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: CupertinoIcons.location_solid,
                      label: address.isNotEmpty
                          ? address
                          : (isAr ? 'بدون عنوان' : 'No address'),
                    ),
                    _InfoChip(
                      icon: CupertinoIcons.time,
                      label:
                          '${profile['open_time']?.toString() ?? ''} - ${profile['close_time']?.toString() ?? ''}',
                    ),
                    _InfoChip(
                      icon: CupertinoIcons.cube_box_fill,
                      label: '${products.length} ${isAr ? 'منتج' : 'products'}',
                    ),
                  ],
                ),
                if (samples.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: samples.take(4).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final image = samples[index];
                        return AppImage(
                          imageData: image,
                          width: 74,
                          height: 74,
                          borderRadius: BorderRadius.circular(14),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ShoppingStoreMenuScreen(
                            isAr: isAr,
                            profile: profile,
                            products: products,
                            subCategory: subCategory,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(isAr ? 'فتح المنيو' : 'Open menu'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShoppingStoreMenuScreen extends StatefulWidget {
  final bool isAr;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> products;
  final ServiceCategory subCategory;

  const ShoppingStoreMenuScreen({
    super.key,
    required this.isAr,
    required this.profile,
    required this.products,
    required this.subCategory,
  });

  @override
  State<ShoppingStoreMenuScreen> createState() =>
      _ShoppingStoreMenuScreenState();
}

class _ShoppingStoreMenuScreenState extends State<ShoppingStoreMenuScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final products = widget.products.where((row) {
      final nameAr = row['name_ar']?.toString().toLowerCase() ?? '';
      final nameEn = row['name_en']?.toString().toLowerCase() ?? '';
      final descriptionAr =
          row['description_ar']?.toString().toLowerCase() ?? '';
      final descriptionEn =
          row['description_en']?.toString().toLowerCase() ?? '';
      if (query.isEmpty) return true;
      return nameAr.contains(query) ||
          nameEn.contains(query) ||
          descriptionAr.contains(query) ||
          descriptionEn.contains(query);
    }).toList();

    final whatsappText = widget.profile['whatsapp']?.toString().trim() ?? '';
    final whatsapp = whatsappText.isNotEmpty
        ? whatsappText
        : AppHelpers.supportWhatsAppNumber;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          widget.isAr
              ? (widget.profile['store_name']?.toString() ?? 'المحل')
              : (widget.profile['store_name']?.toString() ?? 'Store'),
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StoreHeader(
            isAr: widget.isAr,
            profile: widget.profile,
            whatsapp: whatsapp,
          ),
          const SizedBox(height: 12),
          CupertinoSearchTextField(
            controller: _searchController,
            placeholder: widget.isAr ? 'ابحث داخل المتجر' : 'Search this store',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            _EmptyState(
              isAr: widget.isAr,
              message: widget.isAr
                  ? 'لا توجد منتجات مطابقة'
                  : 'No matching products',
            )
          else
            ...products.map((row) {
              final item = Map<String, dynamic>.from(row);
              return _ProductCard(
                isAr: widget.isAr,
                item: item,
                onWhatsApp: () => AppHelpers.launchWhatsApp(
                  whatsapp,
                  widget.isAr
                      ? 'مرحبًا، أريد الاستفسار عن ${item['name_ar']?.toString() ?? ''}'
                      : 'Hello, I want to ask about ${item['name_en']?.toString() ?? ''}',
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final bool isAr;
  final Map<String, dynamic> profile;
  final String whatsapp;

  const _StoreHeader({
    required this.isAr,
    required this.profile,
    required this.whatsapp,
  });

  @override
  Widget build(BuildContext context) {
    final address = profile['address']?.toString() ?? '';
    final phone = profile['phone']?.toString().trim() ?? '';
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
            profile['store_name']?.toString() ?? '',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profile['description']?.toString() ?? '',
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: CupertinoIcons.location_solid,
                label: address.isNotEmpty
                    ? address
                    : (isAr ? 'بدون عنوان' : 'No address'),
              ),
              _InfoChip(
                icon: CupertinoIcons.time,
                label:
                    '${profile['open_time']?.toString() ?? ''} - ${profile['close_time']?.toString() ?? ''}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => AppHelpers.launchWhatsApp(
                    whatsapp,
                    isAr
                        ? 'مرحبًا، أريد الاستفسار عن المحل.'
                        : 'Hello, I want to inquire about the store.',
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(isAr ? 'واتساب' : 'WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Colors.deepOrange,
                    side: const BorderSide(color: Colors.deepOrange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => AppHelpers.makePhoneCall(
                    phone.isNotEmpty ? phone : whatsapp,
                  ),
                  icon: const Icon(Icons.call_rounded),
                  label: Text(isAr ? 'اتصال' : 'Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final bool isAr;
  final Map<String, dynamic> item;
  final VoidCallback onWhatsApp;

  const _ProductCard({
    required this.isAr,
    required this.item,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final imageBase64 = item['image_base64']?.toString();
    final image = AppImage(
      imageData: imageBase64 != null && imageBase64.isNotEmpty
          ? imageBase64
          : item['image']?.toString(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(22)),
            child: SizedBox(width: 110, height: 120, child: image),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr
                        ? (item['name_ar']?.toString() ?? '')
                        : (item['name_en']?.toString() ?? ''),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAr
                        ? (item['description_ar']?.toString() ?? '')
                        : (item['description_en']?.toString() ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '${price.toPrice()} د.ع',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        minSize: 0,
                        color: Colors.deepOrange,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: onWhatsApp,
                        child: Text(
                          isAr ? 'واتساب' : 'WhatsApp',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isAr;
  final String message;

  const _EmptyState({
    required this.isAr,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.deepOrange,
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'ستظهر هنا المتاجر والمنتجات الحقيقية من قاعدة البيانات.'
                  : 'Live stores and products from the database will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

