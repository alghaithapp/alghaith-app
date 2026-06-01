import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../utils/dummy_data.dart';
import '../utils/extensions.dart';
import '../utils/helpers.dart';
import '../widgets/app_image.dart';

class RealEstateListingsScreen extends StatefulWidget {
  final String? subCategoryId;

  const RealEstateListingsScreen({
    super.key,
    this.subCategoryId,
  });

  @override
  State<RealEstateListingsScreen> createState() =>
      _RealEstateListingsScreenState();
}

class _RealEstateListingsScreenState extends State<RealEstateListingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _futureListings;
  String? _selectedSubCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedSubCategoryId = widget.subCategoryId;
    _futureListings = SupabaseService.loadRealEstateListings(
      subCategoryId: _selectedSubCategoryId,
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
    final filters = DummyData.realEstateSubCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          isAr ? 'العقارات' : 'Real Estate',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CupertinoSearchTextField(
            controller: _searchController,
            placeholder: isAr ? 'ابحث عن عقار' : 'Search property',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = filters[index];
                final selected = _selectedSubCategoryId == filter.id;
                return ChoiceChip(
                  label: Text(
                    isAr ? filter.titleAr : filter.titleEn,
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedSubCategoryId = selected ? null : filter.id;
                      _futureListings = SupabaseService.loadRealEstateListings(
                        subCategoryId: _selectedSubCategoryId,
                      );
                    });
                  },
                  selectedColor: Colors.deepOrange,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _futureListings,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _EmptyState(
                  isAr: isAr,
                  message: isAr
                      ? 'تعذر تحميل العقارات'
                      : 'Failed to load listings',
                );
              }

              final listings = snapshot.data ?? const [];
              final filtered = listings.where((entry) {
                final product =
                    Map<String, dynamic>.from(entry['product'] as Map);
                final nameAr =
                    product['name_ar']?.toString().toLowerCase() ?? '';
                final nameEn =
                    product['name_en']?.toString().toLowerCase() ?? '';
                final address =
                    product['address']?.toString().toLowerCase() ?? '';
                final descriptionAr =
                    product['description_ar']?.toString().toLowerCase() ?? '';
                final descriptionEn =
                    product['description_en']?.toString().toLowerCase() ?? '';
                if (query.isEmpty) return true;
                return nameAr.contains(query) ||
                    nameEn.contains(query) ||
                    address.contains(query) ||
                    descriptionAr.contains(query) ||
                    descriptionEn.contains(query);
              }).toList();

              if (filtered.isEmpty) {
                return _EmptyState(
                  isAr: isAr,
                  message: query.isEmpty
                      ? (isAr
                          ? 'لا توجد عقارات منشورة بعد'
                          : 'No properties published yet')
                      : (isAr
                          ? 'لا توجد نتائج مطابقة'
                          : 'No matching properties'),
                );
              }

              return Column(
                children: filtered.map((entry) {
                  final product =
                      Map<String, dynamic>.from(entry['product'] as Map);
                  final merchant = entry['merchant'] is Map
                      ? Map<String, dynamic>.from(entry['merchant'] as Map)
                      : <String, dynamic>{};
                  return _PropertyCard(
                    isAr: isAr,
                    product: product,
                    merchant: merchant,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final bool isAr;
  final Map<String, dynamic> product;
  final Map<String, dynamic> merchant;

  const _PropertyCard({
    required this.isAr,
    required this.product,
    required this.merchant,
  });

  @override
  Widget build(BuildContext context) {
    final price = (product['price'] as num?)?.toInt() ?? 0;
    final imageBase64 = product['image_base64']?.toString();
    final image = AppImage(
      imageData: imageBase64 != null && imageBase64.isNotEmpty
          ? imageBase64
          : product['image']?.toString(),
    );

    final merchantName = merchant['store_name']?.toString().trim();
    final phone = merchant['phone']?.toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SizedBox(
              height: 210,
              width: double.infinity,
              child: image,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr
                      ? (product['name_ar']?.toString() ?? '')
                      : (product['name_en']?.toString() ?? ''),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAr
                      ? (product['description_ar']?.toString() ?? '')
                      : (product['description_en']?.toString() ?? ''),
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
                      icon: Icons.location_on_outlined,
                      label: product['address']?.toString() ??
                          (isAr ? 'غير محدد' : 'Unknown'),
                    ),
                    if (product['area_square_meter'] != null)
                      _InfoChip(
                        icon: Icons.square_foot_outlined,
                        label:
                            '${product['area_square_meter']} ${isAr ? 'م²' : 'm²'}',
                      ),
                    if (product['bedrooms'] != null)
                      _InfoChip(
                        icon: Icons.bed_outlined,
                        label:
                            '${product['bedrooms']} ${isAr ? 'غرف' : 'beds'}',
                      ),
                    if (product['bathrooms'] != null)
                      _InfoChip(
                        icon: Icons.bathtub_outlined,
                        label:
                            '${product['bathrooms']} ${isAr ? 'حمامات' : 'baths'}',
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'السعر' : 'Price',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${price.toLocaleString()} د.ع',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              color: Colors.deepOrange,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: phone == null || phone.isEmpty
                          ? null
                          : () => AppHelpers.launchWhatsApp(
                                phone,
                                isAr
                                    ? 'مرحبًا، أريد الاستفسار عن العقار ${product['name_ar'] ?? ''}'
                                    : 'Hello, I want to ask about ${product['name_en'] ?? ''}',
                              ),
                      icon: const Icon(Icons.chat_outlined),
                      label: Text(
                        isAr ? 'تواصل' : 'Contact',
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                ),
                if (merchantName != null && merchantName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    isAr ? 'الناشر: $merchantName' : 'Listed by: $merchantName',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
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
        color: const Color(0xFFF4F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.deepOrange),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.home_work_outlined,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
