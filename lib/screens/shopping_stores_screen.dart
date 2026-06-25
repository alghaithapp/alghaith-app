import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/catalog/marketplace_catalog.dart';
import '../core/storage/catalog_cache.dart';
import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../utils/extensions.dart';
import '../utils/guest_gate.dart';
import '../utils/helpers.dart';
import '../services/image_storage_service.dart';
import '../utils/merchant_product_sections.dart';
import '../utils/merchant_profile_fields.dart';
import '../widgets/app_image.dart';
import '../widgets/product_image_preview.dart';
import '../widgets/service_navigation_buttons.dart';
import 'cart_screen.dart';
import 'restaurant_menu_screen.dart';
import 'shopping_shared_widgets.dart';
import 'shopping_store_menu_screen.dart';

class ShoppingStoresScreen extends StatefulWidget {
  final ServiceCategory? subCategory;
  final MerchantStoreKind storeKind;
  final String? serviceId;
  final String? productCategory;
  final String? titleAr;
  final String? subtitleAr;
  final bool showCuisineFilters;
  final bool hideBack;

  /// مثال: product | global_shopping | restaurant
  final String? marketplaceCategory;

  const ShoppingStoresScreen({
    super.key,
    this.subCategory,
    this.storeKind = MerchantStoreKind.shopping,
    this.serviceId,
    this.productCategory,
    this.marketplaceCategory,
    this.titleAr,
    this.subtitleAr,
    this.showCuisineFilters = false,
    this.hideBack = false,
  });

  @override
  State<ShoppingStoresScreen> createState() => _ShoppingStoresScreenState();
}

class _ShoppingStoresScreenState extends State<ShoppingStoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _stores = const [];
  Object? _storesLoadError;
  bool _isLoadingStores = true;
  String _selectedFilter = 'الكل';
  String _bazaarKindFilter = 'all';

  final List<String> _filters = [
    'الكل',
    'مشويات',
    'وجبات سريعة',
  ];

  Future<List<Map<String, dynamic>>> _loadStores() {
    if (widget.serviceId != null && widget.serviceId!.trim().isNotEmpty) {
      return SupabaseService.loadServiceStores(
        serviceId: widget.serviceId!,
        productCategory: widget.productCategory ?? widget.serviceId,
        subCategoryId: widget.subCategory?.id,
        marketplaceCategory: widget.marketplaceCategory,
      );
    }
    if (widget.storeKind == MerchantStoreKind.restaurant) {
      return SupabaseService.loadRestaurantStores(
        subCategoryId: widget.subCategory?.id,
      );
    }
    return SupabaseService.loadShoppingStores(
      subCategoryId: widget.subCategory?.id,
    );
  }

  String get _storesCacheBucket {
    final parts = <String>[
      widget.storeKind.name,
      widget.serviceId?.trim() ?? '',
      widget.productCategory?.trim() ?? '',
      widget.marketplaceCategory?.trim() ?? '',
      widget.subCategory?.id.trim() ?? '',
    ];
    return parts
        .map((part) => part.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_'))
        .join('__');
  }

  Future<void> _bootstrapStores() async {
    final cached = await CatalogCache.readStoresBucket(_storesCacheBucket);
    if (!mounted) return;
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _stores = cached;
        _storesLoadError = null;
        _isLoadingStores = false;
      });
    }
    unawaited(_refreshStores(showLoading: cached == null || cached.isEmpty));
  }

  Future<void> _refreshStores({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoadingStores = true;
        _storesLoadError = null;
      });
    }
    try {
      final fresh = await _loadStores();
      await CatalogCache.writeStoresBucket(_storesCacheBucket, fresh);
      if (!mounted) return;
      setState(() {
        _stores = fresh;
        _storesLoadError = null;
        _isLoadingStores = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _storesLoadError = error;
        _isLoadingStores = false;
      });
    }
  }

  void _reloadStores() {
    unawaited(_refreshStores(showLoading: _stores.isEmpty));
  }

  bool get _isBazaarChannel =>
      widget.serviceId == 'bazar_ghaith' ||
      widget.marketplaceCategory == 'bazar_ghaith';

  bool _isRestaurantStore(Map profile) {
    final primary = profile['primary_service_id']?.toString() ?? '';
    final services = profile['service_ids'];
    if (services is List) {
      return services.map((e) => e.toString()).contains('restaurant');
    }
    return primary == 'restaurant';
  }

  bool _storeMatchesBazaarKind(Map profile) {
    if (!_isBazaarChannel || _bazaarKindFilter == 'all') return true;
    final isRestaurant = _isRestaurantStore(profile);
    if (_bazaarKindFilter == 'restaurant') return isRestaurant;
    return !isRestaurant;
  }

  String _restaurantCategoryFromProfile(Map profile) {
    final direct =
        profile['restaurantCategory'] ?? profile['restaurant_category'];
    final value = direct?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;

    final storeData = profile['store_data'] ?? profile['storeData'];
    if (storeData is Map) {
      final nested = storeData['restaurantCategory'] ??
          storeData['restaurant_category'];
      return nested?.toString().trim() ?? '';
    }
    return '';
  }

  bool _storeMatchesCuisineFilter(Map profile) {
    if (!widget.showCuisineFilters || _selectedFilter == 'الكل') {
      return true;
    }
    // في البازار: متاجر المنتجات تبقى ظاهرة دائماً،
    // وفلتر المطبخ يطبّق على المطاعم فقط.
    if (_isBazaarChannel && !_isRestaurantStore(profile)) {
      return true;
    }
    return _restaurantCategoryFromProfile(profile) == _selectedFilter;
  }

  bool _storeHasVisibleProducts(Map<String, dynamic> store) {
    final products = store['products'];
    if (products is! List || products.isEmpty) return false;
    final subId = widget.subCategory?.id.trim() ?? '';
    if (subId.isEmpty) return true;
    return products.any((entry) {
      if (entry is! Map) return false;
      final map = Map<String, dynamic>.from(entry);
      final raw = map['sub_category'] ?? map['subCategory'];
      return MarketplaceCatalog.shoppingSubCategoryMatches(
        raw?.toString().trim(),
        subId,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapStores());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final primaryRed = const Color(0xFFF5A01D);
    final headerTitle = widget.titleAr ??
        (widget.storeKind == MerchantStoreKind.restaurant
            ? 'المطاعم'
            : 'المتاجر');
    final headerSubtitle = widget.subtitleAr ??
        (widget.storeKind == MerchantStoreKind.restaurant
            ? 'اختر مطعمك المفضل واطلب بسهولة'
            : 'اختر متجرك واطلب بسهولة');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header ثابت لا يتحرك مع التمرير
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      ShopBackButton(hide: widget.hideBack),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              headerTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              headerSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ServiceRefreshButton(
                        onPressed: _reloadStores,
                        isLoading: _isLoadingStores,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ShopSearchBar(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            // المحتوى القابل للتمرير
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Bazaar Banner
                  if (_isBazaarChannel)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF007A7A).withValues(alpha: 0.08),
                              const Color(0xFFF5A01D).withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFF5A01D).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF5A01D),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shopping_cart_checkout_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'يمكنك التسوق من كافة متاجر ومطاعم هذا القسم في سلة واحدة وبكلفة توصيل واحدة فقط.',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. Category Filters
                  if (widget.showCuisineFilters &&
                      (!_isBazaarChannel || _bazaarKindFilter == 'restaurant'))
                    SliverToBoxAdapter(
                      child: Container(
                        height: 55,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filters.length,
                          itemBuilder: (context, index) {
                            final filter = _filters[index];
                            final isSelected = _selectedFilter == filter;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedFilter = filter),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 5,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryRed
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: primaryRed.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF4A4A4A),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // 3. Restaurants List
                  if (_isLoadingStores && _stores.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  else if (_storesLoadError != null && _stores.isEmpty)
                    SliverFillRemaining(
                      child: ShopErrorState(
                        label: headerTitle,
                        onRetry: _reloadStores,
                      ),
                    )
                  else
                    Builder(
                      builder: (context) {
                        var stores =
                            _stores.where(_storeHasVisibleProducts).toList();

                        // Sorting: Open restaurants first
                        stores.sort((a, b) {
                          final aOpen =
                              (a['profile'] as Map)['is_open'] as bool? ?? true;
                          final bOpen =
                              (b['profile'] as Map)['is_open'] as bool? ?? true;
                          if (aOpen && !bOpen) return -1;
                          if (!aOpen && bOpen) return 1;
                          return 0;
                        });

                        // Search and Category Filter
                        final filtered = stores.where((s) {
                          final p = s['profile'] as Map;
                          final name =
                              p['store_name']?.toString().toLowerCase() ?? '';
                          final desc =
                              p['description']?.toString().toLowerCase() ?? '';

                          final matchesQuery =
                              name.contains(query) || desc.contains(query);
                          final matchesFilter = _storeMatchesCuisineFilter(p);
                          final matchesBazaarKind = _storeMatchesBazaarKind(p);

                          return matchesQuery &&
                              matchesFilter &&
                              matchesBazaarKind;
                        }).toList();

                        if (filtered.isEmpty) {
                          return SliverFillRemaining(
                            child: ShopNoResultsState(
                              isBazaar: _isBazaarChannel,
                              hasStores: stores.isNotEmpty,
                              hasSearch: query.isNotEmpty,
                              hasCuisineFilter: widget.showCuisineFilters &&
                                  _selectedFilter != 'الكل',
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final profile = Map<String, dynamic>.from(
                                  filtered[index]['profile'] as Map,
                                );
                                final products =
                                    (filtered[index]['products'] as List)
                                        .cast<Map<String, dynamic>>();
                                final openAsRestaurant = widget.storeKind ==
                                        MerchantStoreKind.restaurant ||
                                    (_isBazaarChannel &&
                                        _isRestaurantStore(profile));
                                return ShopRestaurantCard(
                                  data: filtered[index],
                                  isRestaurant: openAsRestaurant,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(
                                        builder: (_) => openAsRestaurant
                                            ? RestaurantMenuScreen(
                                                storeProfile: profile,
                                                storeProducts: products,
                                              )
                                            : ShoppingStoreMenuScreen(
                                                profile: profile,
                                                products: products,
                                                subCategory: widget.subCategory,
                                                storeKind: widget.storeKind,
                                              ),
                                      ),
                                    );
                                  },
                                );
                              },
                              childCount: filtered.length,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
