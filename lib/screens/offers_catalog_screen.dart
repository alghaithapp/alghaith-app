import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../utils/extensions.dart';
import '../widgets/app_image.dart';
import 'cart_screen.dart';

class OffersCatalogScreen extends StatefulWidget {
  const OffersCatalogScreen({super.key});

  @override
  State<OffersCatalogScreen> createState() => _OffersCatalogScreenState();
}

class _OffersCatalogScreenState extends State<OffersCatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<_OfferItem>> _futureOffers;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _futureOffers = _loadOffers();
  }

  Future<List<_OfferItem>> _loadOffers() async {
    final rows = await SupabaseService.loadOffersCatalog();
    if (!mounted) return const [];
    final provider = context.read<AppProvider>();
    return rows.map((row) {
      final item = provider.catalogItemFromRow(row);
      final original = (row['original_price'] as num?)?.toInt() ?? item.price;
      final discounted =
          (row['discounted_price'] as num?)?.toInt() ?? item.price;
      final discount =
          (row['offer_discount_percent'] as num?)?.toInt() ??
              (original > 0
                  ? (((original - discounted) / original) * 100).round()
                  : 0);
      final offerTitle = row['offer_title_ar']?.toString() ?? '';
      return _OfferItem(
        item: item.copyWith(price: discounted),
        originalPrice: original,
        discountPercent: discount,
        offerTitle: offerTitle,
      );
    }).toList();
  }

  void _reload() {
    setState(() {
      _futureOffers = _loadOffers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_OfferItem> _filter(List<_OfferItem> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (entry) =>
              entry.item.nameAr.toLowerCase().contains(q) ||
              entry.offerTitle.toLowerCase().contains(q) ||
              (entry.item.merchantStoreName ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'العروض والخصومات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _reload,
              child: const Icon(CupertinoIcons.refresh_thick, size: 22),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const CartScreen()),
              ),
              child: const Icon(CupertinoIcons.cart, size: 22),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'منتجات مخفّضة من المتاجر النشطة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'ابحث في العروض...',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<_OfferItem>>(
                future: _futureOffers,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'تعذّر تحميل العروض',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                          CupertinoButton(
                            onPressed: _reload,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    );
                  }

                  final items = _filter(snapshot.data ?? const []);
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.tag,
                              size: 56,
                              color: CupertinoColors.systemGrey3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _query.trim().isNotEmpty
                                  ? 'لا توجد نتائج'
                                  : 'لا توجد عروض نشطة حاليًا',
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                            if (_query.trim().isEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'ستظهر هنا عروض التجار عند تفعيلها',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final entry = items[index];
                      return _OfferCard(
                        entry: entry,
                        onAdd: () => provider.addToCart(entry.item),
                        onToggleFavorite: () =>
                            provider.toggleFavoriteItem(entry.item),
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

class _OfferItem {
  final ListItem item;
  final int originalPrice;
  final int discountPercent;
  final String offerTitle;

  const _OfferItem({
    required this.item,
    required this.originalPrice,
    required this.discountPercent,
    required this.offerTitle,
  });
}

class _OfferCard extends StatelessWidget {
  final _OfferItem entry;
  final VoidCallback onAdd;
  final VoidCallback onToggleFavorite;

  const _OfferCard({
    required this.entry,
    required this.onAdd,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AppImage(
                imageData: item.image,
                height: 160,
                width: double.infinity,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              if (entry.discountPercent > 0)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE60012),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '-${entry.discountPercent}%',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.offerTitle.isNotEmpty)
                  Text(
                    entry.offerTitle,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE60012),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.nameAr,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onToggleFavorite,
                      child: Icon(
                        item.isFavorite
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        color: item.isFavorite ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
                if ((item.merchantStoreName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.merchantStoreName!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.originalPrice > item.price)
                          Text(
                            '${entry.originalPrice.toLocaleString()} د.ع',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          '${item.price.toLocaleString()} د.ع',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFFE60012),
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      color: const Color(0xFFE60012),
                      borderRadius: BorderRadius.circular(20),
                      onPressed: onAdd,
                      child: const Text(
                        'أضف للسلة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
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
