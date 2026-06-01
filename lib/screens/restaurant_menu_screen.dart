import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../utils/extensions.dart';
import '../widgets/app_image.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final ListItem restaurant;

  const RestaurantMenuScreen({super.key, required this.restaurant});

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';
    final query = _searchController.text.trim().toLowerCase();

    final menuItems = provider.items
        .where((item) => item.category == 'restaurant' && item.isAvailable)
        .where((item) {
      if (query.isEmpty) return true;
      return item.nameAr.toLowerCase().contains(query) ||
          item.nameEn.toLowerCase().contains(query) ||
          item.descriptionAr.toLowerCase().contains(query) ||
          item.descriptionEn.toLowerCase().contains(query);
    }).toList();

    final sortedItems = [...menuItems]..sort((a, b) {
        final favoriteCompare =
            (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0);
        if (favoriteCompare != 0) return favoriteCompare;
        return (b.rating ?? 0).compareTo(a.rating ?? 0);
      });

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        border: const Border(bottom: BorderSide(color: Color(0x11000000))),
        middle: Text(
          isAr ? widget.restaurant.nameAr : widget.restaurant.nameEn,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
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
              child: _HeaderCard(
                restaurant: widget.restaurant,
                isAr: isAr,
                menuCount: sortedItems.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: isAr ? 'ابحث في المنيو' : 'Search menu',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: sortedItems.isEmpty
                  ? _EmptyState(isAr: isAr, hasSearch: query.isNotEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: sortedItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = sortedItems[index];
                        return _MenuItemCard(
                          item: item,
                          isAr: isAr,
                          onAdd: () {
                            provider.addToCart(item);
                            showCupertinoDialog(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: Text(isAr ? 'تمت الإضافة' : 'Added'),
                                content: Text(
                                  isAr
                                      ? 'تمت إضافة ${item.nameAr} إلى السلة.'
                                      : '${item.nameEn} was added to cart.',
                                ),
                                actions: [
                                  CupertinoDialogAction(
                                    child: Text(isAr ? 'حسنًا' : 'OK'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
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

class _HeaderCard extends StatelessWidget {
  final ListItem restaurant;
  final bool isAr;
  final int menuCount;

  const _HeaderCard({
    required this.restaurant,
    required this.isAr,
    required this.menuCount,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = AppImage(
      imageData: restaurant.imageBase64 != null && restaurant.imageBase64!.isNotEmpty
          ? restaurant.imageBase64
          : restaurant.image,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4E7), Color(0xFFFFFBF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x1A000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageWidget,
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.02),
                          Colors.black.withValues(alpha: 0.30),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isAr
                                ? 'منيو حقيقي من قاعدة البيانات'
                                : 'Live menu from Supabase',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isAr ? restaurant.nameAr : restaurant.nameEn,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
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
                  isAr ? restaurant.descriptionAr : restaurant.descriptionEn,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF5A5A5A),
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: CupertinoIcons.star_fill,
                      label: restaurant.rating == null
                          ? (isAr ? 'تقييم' : 'Rating')
                          : restaurant.rating!.toStringAsFixed(1),
                      color: Colors.amber,
                    ),
                    _InfoChip(
                      icon: CupertinoIcons.clock_fill,
                      label: restaurant.prepMinutes == null
                          ? (isAr ? 'سريع' : 'Fast')
                          : '${restaurant.prepMinutes} ${isAr ? 'د' : 'min'}',
                      color: Colors.deepOrange,
                    ),
                    _InfoChip(
                      icon: CupertinoIcons.square_grid_2x2_fill,
                      label: '$menuCount ${isAr ? 'صنف' : 'items'}',
                      color: Colors.green,
                    ),
                  ],
                ),
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
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final ListItem item;
  final bool isAr;
  final VoidCallback onAdd;

  const _MenuItemCard({
    required this.item,
    required this.isAr,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = AppImage(
      imageData: item.imageBase64 != null && item.imageBase64!.isNotEmpty
          ? item.imageBase64
          : item.image,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x0F000000)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(22)),
            child: SizedBox(
              width: 110,
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageWidget,
                  if (item.rating != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? item.nameAr : item.nameEn,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Cairo',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAr ? item.descriptionAr : item.descriptionEn,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B6B6B),
                      height: 1.3,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '${item.price.toPrice()} د.ع',
                        style: const TextStyle(
                          fontSize: 14,
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
                        color:
                            item.isAvailable ? Colors.deepOrange : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: item.isAvailable ? onAdd : null,
                        child: Text(
                          item.isAvailable
                              ? (isAr ? 'أضف' : 'Add')
                              : (isAr ? 'غير متاح' : 'Unavailable'),
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

class _EmptyState extends StatelessWidget {
  final bool isAr;
  final bool hasSearch;

  const _EmptyState({
    required this.isAr,
    required this.hasSearch,
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
                color: const Color(0xFFFFEAD9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: Colors.deepOrange,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch
                  ? (isAr ? 'لا توجد نتائج مطابقة' : 'No matching results')
                  : (isAr ? 'لا توجد وجبات مضافة بعد' : 'No menu items yet'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? (isAr
                      ? 'جرّب البحث بكلمة مختلفة'
                      : 'Try a different search term')
                  : (isAr
                      ? 'سيظهر المنيو الحقيقي هنا عندما يضيف التاجر وجباته.'
                      : 'The live menu will appear here when the merchant adds items.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B6B6B),
                fontSize: 13,
                height: 1.4,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
