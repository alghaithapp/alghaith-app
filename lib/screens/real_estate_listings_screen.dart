import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../utils/dummy_data.dart';
import '../utils/extensions.dart';
import '../utils/guest_gate.dart';
import '../utils/helpers.dart';
import '../widgets/app_image.dart';
import '../widgets/service_navigation_buttons.dart';

class RealEstateListingsScreen extends StatefulWidget {
  final String? subCategoryId;
  final String? listingMode;
  final String? titleAr;

  const RealEstateListingsScreen({
    super.key,
    this.subCategoryId,
    this.listingMode,
    this.titleAr,
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
      listingMode: widget.listingMode,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filters = DummyData.realEstateSubCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        leadingWidth: 56,
        leading: const Center(child: ServiceBackButton()),
        title: Text(
          widget.titleAr?.trim().isNotEmpty == true
              ? widget.titleAr!.trim()
              : 'العقارات',
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
            placeholder: 'ابحث عن عقار',
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
                    filter.titleAr,
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedSubCategoryId = selected ? null : filter.id;
                      _futureListings = SupabaseService.loadRealEstateListings(
                        subCategoryId: _selectedSubCategoryId,
                        listingMode: widget.listingMode,
                      );
                    });
                  },
                  selectedColor: const Color(0xFFF5A01D),
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
                return const _EmptyState(
                  message: 'تعذر تحميل العقارات',
                );
              }

              final listings = snapshot.data ?? const [];
              final filtered = listings.where((entry) {
                final product =
                    Map<String, dynamic>.from(entry['product'] as Map);
                final nameAr =
                    product['name_ar']?.toString().toLowerCase() ?? '';
                final address =
                    product['address']?.toString().toLowerCase() ?? '';
                final descriptionAr =
                    product['description_ar']?.toString().toLowerCase() ?? '';
                if (query.isEmpty) return true;
                return nameAr.contains(query) ||
                    address.contains(query) ||
                    descriptionAr.contains(query);
              }).toList();

              if (filtered.isEmpty) {
                return _EmptyState(
                  message: query.isEmpty
                      ? 'لا توجد عقارات منشورة بعد'
                      : 'لا توجد نتائج مطابقة',
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
  final Map<String, dynamic> product;
  final Map<String, dynamic> merchant;

  const _PropertyCard({
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
                  product['name_ar']?.toString() ?? '',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product['description_ar']?.toString() ?? '',
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
                      label: product['address']?.toString() ?? 'غير محدد',
                    ),
                    if (product['area_square_meter'] != null)
                      _InfoChip(
                        icon: Icons.square_foot_outlined,
                        label: '${product['area_square_meter']} م²',
                      ),
                    if (product['bedrooms'] != null)
                      _InfoChip(
                        icon: Icons.bed_outlined,
                        label: '${product['bedrooms']} غرف',
                      ),
                    if (product['bathrooms'] != null)
                      _InfoChip(
                        icon: Icons.bathtub_outlined,
                        label: '${product['bathrooms']} حمامات',
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
                          const Text(
                            'السعر',
                            style: TextStyle(
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
                              color: const Color(0xFFF5A01D),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: phone == null || phone.isEmpty
                          ? null
                          : () {
                              if (!GuestGate.requireAccount(
                                context,
                                message: 'سجّل دخولك للتواصل مع المعلن.',
                              )) {
                                return;
                              }
                              AppHelpers.launchWhatsApp(
                                phone,
                                'مرحبًا، أريد الاستفسار عن العقار ${product['name_ar'] ?? ''}',
                              );
                            },
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text(
                        'تواصل',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                ),
                if (merchantName != null && merchantName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'الناشر: $merchantName',
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
  final String message;

  const _EmptyState({
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
