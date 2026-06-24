import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../utils/dummy_data.dart';
import '../utils/extensions.dart';
import '../utils/guest_gate.dart';
import '../utils/chat_navigation.dart';
import '../utils/merchant_profile_fields.dart';
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

class _PropertyCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> merchant;

  const _PropertyCard({
    required this.product,
    required this.merchant,
  });

  @override
  State<_PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<_PropertyCard> {
  int _imageIndex = 0;

  List<String> _galleryImages() {
    final raw = widget.product['gallery_images_base64'];
    if (raw is List) {
      final parsed = raw
          .map((entry) => entry?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }
    final single = widget.product['image_base64']?.toString().trim() ?? '';
    if (single.isNotEmpty) return [single];
    final asset = widget.product['image']?.toString().trim() ?? '';
    if (asset.isNotEmpty) return [asset];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final merchant = widget.merchant;
    final price = (product['price'] as num?)?.toInt() ?? 0;
    final gallery = _galleryImages();
    final imageData = gallery.isNotEmpty
        ? gallery[_imageIndex.clamp(0, gallery.length - 1)]
        : product['image']?.toString();

    final merchantName = merchant['store_name']?.toString().trim();
    final merchantPhone =
        MerchantProfileFields.merchantInternalContactPhone(merchant).trim();
    final neighborhood = product['neighborhood']?.toString().trim();
    final facade = product['facade']?.toString().trim();
    final floors = product['floor_count'];
    final subCategoryId = product['sub_category']?.toString();
    final propertyType = DummyData.realEstateSubCategories
        .where((entry) => entry.id == subCategoryId)
        .map((entry) => entry.titleAr)
        .firstOrNull;

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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(imageData: imageData),
                  if (gallery.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(gallery.length, (index) {
                          final active = index == _imageIndex;
                          return GestureDetector(
                            onTap: () => setState(() => _imageIndex = index),
                            child: Container(
                              width: active ? 18 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
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
                    if (propertyType != null && propertyType.isNotEmpty)
                      _InfoChip(
                        icon: Icons.home_work_outlined,
                        label: propertyType,
                      ),
                    if (neighborhood != null && neighborhood.isNotEmpty)
                      _InfoChip(
                        icon: Icons.location_on_outlined,
                        label: 'الحي: $neighborhood',
                      ),
                    if (facade != null && facade.isNotEmpty)
                      _InfoChip(
                        icon: Icons.signpost_outlined,
                        label: 'الواجهة: $facade',
                      ),
                    if (floors != null)
                      _InfoChip(
                        icon: Icons.stairs_outlined,
                        label: 'النزال: $floors',
                      ),
                    if (product['area_square_meter'] != null)
                      _InfoChip(
                        icon: Icons.square_foot_outlined,
                        label: '${product['area_square_meter']} م²',
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
                      onPressed: merchantPhone.isEmpty &&
                              (product['merchant_phone']?.toString().trim().isEmpty ?? true)
                          ? null
                          : () {
                              if (!GuestGate.requireAccount(
                                context,
                                message: 'سجّل دخولك للتواصل مع المعلن.',
                              )) {
                                return;
                              }
                              final contact =
                                  (product['merchant_phone']?.toString().trim().isNotEmpty == true)
                                      ? product['merchant_phone'].toString().trim()
                                      : merchantPhone.trim();
                              if (contact.isEmpty) return;
                              ChatNavigation.openStoreChat(
                                context,
                                merchantPhone: contact,
                                storeName: merchantName ?? product['name_ar']?.toString() ?? 'المعلن',
                                merchantProfile: merchant,
                              );
                            },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text(
                        'مراسلة',
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
