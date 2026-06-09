import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/catalog/marketplace_catalog.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../utils/extensions.dart';
import '../utils/guest_gate.dart';
import '../widgets/app_image.dart';
import '../widgets/catalog_contact_buttons.dart';
import 'cart_screen.dart';

class CatalogProductsScreen extends StatefulWidget {
  final String category;
  final String? subCategoryId;
  final String titleAr;
  final String? subtitleAr;

  const CatalogProductsScreen({
    super.key,
    required this.category,
    this.subCategoryId,
    required this.titleAr,
    this.subtitleAr,
  });

  bool get _contactOnly =>
      MarketplaceCatalog.isContactListingCategory(category);

  @override
  State<CatalogProductsScreen> createState() => _CatalogProductsScreenState();
}

class _CatalogProductsScreenState extends State<CatalogProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<ListItem>> _futureProducts;
  String _query = '';

  bool get _contactOnly => widget._contactOnly;

  @override
  void initState() {
    super.initState();
    _futureProducts = _loadProducts();
  }

  Future<List<ListItem>> _loadProducts() async {
    final rows = await SupabaseService.loadCatalog(
      category: widget.category,
      subCategoryId: widget.subCategoryId,
    );
    if (!mounted) return const [];
    final provider = context.read<AppProvider>();
    return rows.map(provider.catalogItemFromRow).toList();
  }

  void _reload() {
    setState(() {
      _futureProducts = _loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ListItem> _filter(List<ListItem> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where(
          (item) =>
              item.nameAr.toLowerCase().contains(q) ||
              item.descriptionAr.toLowerCase().contains(q) ||
              (item.merchantStoreName ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.titleAr,
          style: const TextStyle(
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
            if (!_contactOnly)
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
            if (widget.subtitleAr != null || _contactOnly)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _contactOnly
                        ? 'تواصل مع صاحب الإعلان عبر واتساب أو الاتصال'
                        : widget.subtitleAr!,
                    style: const TextStyle(
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
                placeholder: 'ابحث في ${widget.titleAr}...',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ListItem>>(
                future: _futureProducts,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorState(
                      message: 'تعذّر تحميل المنتجات',
                      onRetry: _reload,
                    );
                  }

                  final items = _filter(snapshot.data ?? const []);
                  if (items.isEmpty) {
                    return _EmptyState(
                      hasQuery: _query.trim().isNotEmpty,
                      category: widget.titleAr,
                      contactOnly: _contactOnly,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _CatalogProductCard(
                        item: item,
                        contactOnly: _contactOnly,
                        onAdd: () {
                          if (!GuestGate.requireAccount(
                            context,
                            message:
                                'سجّل دخولك لإضافة المنتجات إلى السلة والتسوق.',
                          )) {
                            return;
                          }
                          provider.addToCart(item);
                        },
                        onToggleFavorite: () =>
                            provider.toggleFavoriteItem(item),
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

class _CatalogProductCard extends StatelessWidget {
  final ListItem item;
  final bool contactOnly;
  final VoidCallback onAdd;
  final VoidCallback onToggleFavorite;

  const _CatalogProductCard({
    required this.item,
    required this.contactOnly,
    required this.onAdd,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
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
          AppImage(
            imageData: item.image,
            height: 160,
            width: double.infinity,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (item.descriptionAr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.descriptionAr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (contactOnly) ...[
                  if (item.price > 0)
                    Text(
                      '${item.price.toLocaleString()} د.ع',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFFF5A01D),
                        fontFamily: 'Cairo',
                      ),
                    ),
                  if (item.price > 0) const SizedBox(height: 10),
                  CatalogContactButtons(item: item),
                ] else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.price.toLocaleString()} د.ع',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFFF5A01D),
                          fontFamily: 'Cairo',
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        color: const Color(0xFFF5A01D),
                        borderRadius: BorderRadius.circular(20),
                        onPressed: item.isAvailable ? onAdd : null,
                        child: Text(
                          item.actionLabelAr.isNotEmpty
                              ? item.actionLabelAr
                              : 'أضف للسلة',
                          style: const TextStyle(
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

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  final String category;
  final bool contactOnly;

  const _EmptyState({
    required this.hasQuery,
    required this.category,
    required this.contactOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasQuery ? CupertinoIcons.search : CupertinoIcons.cube_box,
              size: 56,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery
                  ? 'لا توجد نتائج'
                  : contactOnly
                      ? 'لا توجد إعلانات في $category حاليًا'
                      : 'لا توجد منتجات في $category حاليًا',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: CupertinoColors.systemGrey,
              ),
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 8),
              Text(
                contactOnly
                    ? 'سيظهر المحتوى هنا عندما ينشر التجار إعلانات في هذا القسم'
                    : 'سيظهر المحتوى هنا عندما ينشر التجار منتجات في هذا القسم',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: CupertinoColors.systemGrey2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 12),
          CupertinoButton.filled(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
