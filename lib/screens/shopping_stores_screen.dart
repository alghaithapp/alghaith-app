import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

enum MerchantStoreKind { shopping, restaurant }

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

  bool _storeMatchesCuisineFilter(Map profile) {
    if (!widget.showCuisineFilters || _selectedFilter == 'الكل') {
      return true;
    }
    // في البازار: متاجر المنتجات تبقى ظاهرة دائماً،
    // وفلتر المطبخ يطبّق على المطاعم فقط.
    if (_isBazaarChannel && !_isRestaurantStore(profile)) {
      return true;
    }
    final resCat = profile['restaurantCategory']?.toString() ?? '';
    return resCat == _selectedFilter;
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
      return raw?.toString().trim() == subId;
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
                      _ModernBackButton(hide: widget.hideBack),
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
                  _SearchBar(
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
                      child: _ErrorState(
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
                            child: _NoResultsState(
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
                                return _PremiumRestaurantCard(
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

/// زر رجوع عصري وجميل مع تأثيرات بصرية
class _ModernBackButton extends StatelessWidget {
  final bool hide;

  const _ModernBackButton({this.hide = false});

  @override
  Widget build(BuildContext context) {
    if (hide) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE84A3A).withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE84A3A).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 20,
              color: const Color(0xFFE84A3A),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumRestaurantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isRestaurant;
  final VoidCallback onTap;

  const _PremiumRestaurantCard({
    required this.data,
    required this.isRestaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(data['profile'] as Map);
    final products = (data['products'] as List).cast<Map<String, dynamic>>();
    final isOpen = profile['is_open'] as bool? ?? true;

    final dbRating = profile['rating']?.toDouble() ?? 0.0;
    final hasRating = dbRating > 0;
    final ratingLabel = hasRating ? dbRating.toStringAsFixed(1) : 'جديد';

    final primaryOrange = const Color(0xFFF5A01D);
    final customerPhone = MerchantProfileFields.customerVisiblePhone(profile);
    final customerWhatsApp = MerchantProfileFields.customerVisibleWhatsApp(profile);

    // إحصائيات حقيقية من الباكند — لا بيانات وهمية
    final productsCount = profile['totalProducts'] ?? products.length;
    final dynamic completedOrdersRaw = profile['completedOrders'];
    final ordersCount = (completedOrdersRaw is num && completedOrdersRaw > 0)
        ? completedOrdersRaw.toString()
        : '0';
    final dynamic totalClientsRaw = profile['totalClients'];
    final clientsCount = (totalClientsRaw is num && totalClientsRaw > 0)
        ? totalClientsRaw.toString()
        : '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Header — الغلاف كامل العرض مع معلومات التاجر
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                // الغلاف — كامل المساحة
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    child: AppImage(
                      imageData: ImageStorageService.merchantUploadedImageRef(
                        profile['cover_image_url'] ?? profile['coverImageBase64'],
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // طبقة شفافة من اليمين لتحسين النص
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.black.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.35, 0.65],
                      ),
                    ),
                  ),
                ),
                // معلومات التاجر + الصورة الدائرية
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                profile['store_name']?.toString() ?? 'المتجر',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                profile['description']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.location_on, color: Colors.white.withValues(alpha: 0.6), size: 12),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      MerchantProfileFields.addressFromMap(profile),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 10,
                                        color: Colors.white.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // الصورة الدائرية (اللوجو)
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: AppImage(
                                  imageData: ImageStorageService.merchantUploadedImageRef(
                                    profile['logo_image_url'] ??
                                        profile['logoImageBase64'] ??
                                        profile['profile_image_base64'],
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.verified, color: primaryOrange, size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // شريط الحالة — مفتوح الآن + التقييم
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOpen ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOpen ? 'مفتوح الآن' : 'مغلق',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isOpen ? Colors.green : Colors.grey,
                          ),
                        ),
                        if (hasRating) ...[
                          const SizedBox(width: 8),
                          Container(width: 1, height: 14, color: Colors.grey.shade300),
                          const SizedBox(width: 8),
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            ratingLabel,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Stats Bar — إحصائيات حقيقية من الباكند
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'منتج', value: '$productsCount', icon: Icons.shopping_bag_outlined),
                  _divider(),
                  _StatItem(label: 'طلب', value: ordersCount, icon: Icons.shopping_cart_outlined),
                  _divider(),
                  _StatItem(label: 'عميل', value: clientsCount, icon: Icons.groups_outlined),
                  _divider(),
                  _StatItem(label: 'التقييم', value: ratingLabel, icon: Icons.star_outline_rounded, color: Colors.amber),
                ],
              ),
            ),
          ),

          // 3. Product Gallery
          if (products.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'أحدث المنتجات',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  Icon(Icons.chevron_left, color: Colors.grey.shade400, size: 18),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                itemBuilder: (context, idx) {
                  final price = (products[idx]['price'] as num?)?.toInt() ?? 0;
                  return Container(
                    width: 90,
                    margin: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF0F0F0)),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: AppImage(
                              imageData: products[idx]['image_base64'] ?? products[idx]['image'],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                            ),
                            child: Text(
                              '${price.toPrice()} د.ع',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 4. Action Bar — 3 أزرار صغيرة + زر مستطيل بالعرض كامل تحتها
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    _MiniActionBtn(
                      label: 'مراسلة',
                      icon: Icons.chat_bubble_outline_rounded,
                      color: Colors.blueGrey,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ميزة المراسلة قريباً...', style: TextStyle(fontFamily: 'Cairo'))),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _MiniActionBtn(
                      label: 'اتصال',
                      icon: Icons.phone_outlined,
                      color: Colors.green,
                      onTap: () {
                        if (customerPhone.isNotEmpty) AppHelpers.makePhoneCall(customerPhone);
                      },
                    ),
                    const SizedBox(width: 8),
                    _MiniActionBtn(
                      label: 'واتساب',
                      icon: Icons.chat_outlined,
                      color: const Color(0xFF25D366),
                      onTap: () {
                        if (customerWhatsApp.isNotEmpty) AppHelpers.launchWhatsApp(customerWhatsApp, 'مرحباً، أريد الاستفسار عن منتجاتكم.');
                      },
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 12),
                // زر عرض المتجر — مستطيل بعرض كامل
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primaryOrange, const Color(0xFFFF8A00)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: primaryOrange.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: onTap,
                      icon: const Icon(Icons.store_outlined, color: Colors.white, size: 20),
                      label: const Text(
                        'عرض المتجر',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 24, color: Colors.grey.shade200);
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, height: 1),
        ),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey, height: 1.2),
        ),
      ],
    );
  }
}

class _MiniActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniActionBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 64,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _PremiumInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PremiumInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
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
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A4A4A)),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.search, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'ابحث عن مطعم أو وجبة...',
                hintStyle: TextStyle(
                    fontFamily: 'Cairo', color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            height: 35,
            width: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          const Icon(CupertinoIcons.slider_horizontal_3,
              color: Color(0xFFF5A01D)),
        ],
      ),
    );
  }
}

class _GuestModeBanner extends StatelessWidget {
  final VoidCallback onLogin;

  const _GuestModeBanner({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(CupertinoIcons.lock_shield_fill,
                color: Color(0xFFF5A01D), size: 32),
            const SizedBox(width: 15),
            const Expanded(
              child: Text(
                'يمكنك التصفح الآن، ولإكمال الطلب يرجى تسجيل الدخول',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.4),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5A01D),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('دخول',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final String label;
  const _ErrorState({required this.onRetry, this.label = 'المحتوى'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'تعذر تحميل $label حالياً',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'قد يحتاج الخادم لحظات للاستيقاظ، حاول مجددًا.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 12, color: Colors.grey),
          ),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  final bool isBazaar;
  final bool hasStores;
  final bool hasSearch;
  final bool hasCuisineFilter;

  const _NoResultsState({
    this.isBazaar = false,
    this.hasStores = false,
    this.hasSearch = false,
    this.hasCuisineFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    String message;
    if (hasSearch || hasCuisineFilter) {
      message = 'لا توجد نتائج مطابقة لبحثك أو الفلتر الحالي';
    } else if (isBazaar) {
      message = hasStores
          ? 'لا توجد متاجر مطابقة للفلتر الحالي'
          : 'لا توجد متاجر معتمدة في بازار ومطاعم الغيث حالياً.\n'
              'يظهر المتجر للزبائن بعد موافقة الإدارة على عضوية البازار.';
    } else {
      message = 'لا توجد متاجر متاحة حالياً';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.search, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Keep the existing Menu Screen as is or minimal styling if needed
class ShoppingStoreMenuScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> products;
  final ServiceCategory? subCategory;
  final MerchantStoreKind storeKind;

  const ShoppingStoreMenuScreen({
    super.key,
    required this.profile,
    required this.products,
    required this.subCategory,
    this.storeKind = MerchantStoreKind.shopping,
  });

  @override
  State<ShoppingStoreMenuScreen> createState() =>
      _ShoppingStoreMenuScreenState();
}

class _ShoppingStoreMenuScreenState extends State<ShoppingStoreMenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _cartIconKey = GlobalKey();
  int _cartPulseTick = 0;
  String? _selectedSectionKey;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _animateAddToCart() {
    if (mounted) {
      setState(() {
        _cartPulseTick++;
      });
    }
  }

  List<Map<String, dynamic>> _filterProducts(List<Map<String, dynamic>> rows) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return rows;

    return rows.where((row) {
      final searchable = [
        row['name_ar']?.toString(),
        row['name_en']?.toString(),
        row['description_ar']?.toString(),
        row['description_en']?.toString(),
      ].whereType<String>().join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final allProducts =
        widget.products.map((row) => Map<String, dynamic>.from(row)).toList();
    final storeSections =
        MerchantProductSections.parseFromProfile(widget.profile);
    final sectionTabs = MerchantProductSections.tabsForStore(
      sections: storeSections,
      products: allProducts,
    );
    final filteredBySection = MerchantProductSections.filterProducts(
      products: allProducts,
      sections: storeSections,
      selectedKey: _selectedSectionKey,
    );
    final products = _filterProducts(filteredBySection);

    final customerPhone =
        MerchantProfileFields.customerVisiblePhone(widget.profile);
    final customerWhatsApp =
        MerchantProfileFields.customerVisibleWhatsApp(widget.profile);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leadingWidth: 56,
        leading: const Center(child: ServiceBackButton()),
        title: Text(
          widget.profile['store_name']?.toString() ?? 'المحل',
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Selector<AppProvider, int>(
              selector: (_, appProvider) => appProvider.cartCount,
              builder: (context, cartCount, _) => _StoreCartNavButton(
                key: _cartIconKey,
                count: cartCount,
                pulseTick: _cartPulseTick,
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StoreHeader(
              profile: widget.profile,
              visiblePhone: customerPhone,
              visibleWhatsApp: customerWhatsApp,
            ),
            const SizedBox(height: 12),
            CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'ابحث داخل المتجر',
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (sectionTabs.length > 1) ...[
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: sectionTabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final tab = sectionTabs[index];
                    final selected = _selectedSectionKey == tab.key;
                    return GestureDetector(
                      onTap: () => setState(
                        () => _selectedSectionKey = tab.key,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              selected ? const Color(0xFFF5A01D) : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFF5A01D)
                                : const Color(0xFFE8E8E8),
                          ),
                        ),
                        child: Text(
                          tab.label,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (products.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text(
                    (widget.storeKind == MerchantStoreKind.restaurant)
                        ? 'لا توجد وجبات متاحة حالياً'
                        : 'لا توجد منتجات متاحة حالياً',
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              )
            else
              ...products.map((item) {
                return _ProductCard(
                  item: item,
                  profile: widget.profile,
                  onWhatsApp: () {
                    if (!GuestGate.requireAccount(
                      context,
                      message: 'سجّل دخولك للتواصل مع المتجر.',
                    )) {
                      return;
                    }
                    if (customerWhatsApp.trim().isEmpty) return;
                    AppHelpers.launchWhatsApp(
                      customerWhatsApp,
                      'مرحبًا، أريد الاستفسار عن ${item['name_ar']?.toString() ?? ''}',
                    );
                  },
                  onAdd: (buttonContext) {
                    if (!GuestGate.requireAccount(
                      context,
                      message: 'سجّل دخولك لإضافة المنتجات إلى السلة والتسوق.',
                    )) {
                      return;
                    }
                    final added = provider.addStoreProductToCart(
                      item,
                      widget.profile,
                    );
                    if (!added) {
                      if (!context.mounted) return;
                      showCupertinoDialog(
                        context: context,
                        builder: (dialogContext) => CupertinoAlertDialog(
                          content: const Text(
                            'السلة تحتوي منتجات من قسم آخر (مثل العقارات أو السيارات) لا يمكن دمجها. أكمل طلبك الحالي أو افرغ السلة أولاً.',
                          ),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('حسنًا'),
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    _animateAddToCart();
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String visiblePhone;
  final String visibleWhatsApp;

  const _StoreHeader({
    required this.profile,
    required this.visiblePhone,
    required this.visibleWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final address = MerchantProfileFields.addressFromMap(profile);
    final hasWhatsApp = visibleWhatsApp.trim().isNotEmpty;
    final hasPhone = visiblePhone.trim().isNotEmpty;
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
                label: address.isNotEmpty ? address : 'بدون عنوان',
              ),
              _InfoChip(
                icon: CupertinoIcons.time,
                label: MerchantProfileFields.workingHoursLabel(profile),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasWhatsApp && !hasPhone)
            const Text(
              'التاجر أخفى وسائل التواصل حالياً.',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.grey,
                fontSize: 12,
              ),
            )
          else
            Row(
              children: [
                if (hasWhatsApp)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (!GuestGate.requireAccount(
                          context,
                          message: 'سجّل دخولك للتواصل مع المتجر.',
                        )) {
                          return;
                        }
                        AppHelpers.launchWhatsApp(
                          visibleWhatsApp,
                          'مرحبًا، أريد الاستفسار عن المحل.',
                        );
                      },
                      icon: const Icon(Icons.chat_rounded),
                      label: const Text('واتساب'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: const Color(0xFFF5A01D),
                        side: const BorderSide(color: Color(0xFFF5A01D)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                if (hasWhatsApp && hasPhone) const SizedBox(width: 10),
                if (hasPhone)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!GuestGate.requireAccount(
                          context,
                          message: 'سجّل دخولك للتواصل مع المتجر.',
                        )) {
                          return;
                        }
                        AppHelpers.makePhoneCall(visiblePhone);
                      },
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('اتصال'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5A01D),
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
  final Map<String, dynamic> item;
  final Map<String, dynamic> profile;
  final VoidCallback onWhatsApp;
  final void Function(BuildContext buttonContext) onAdd;

  const _ProductCard({
    required this.item,
    required this.profile,
    required this.onWhatsApp,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final productId = item['id']?.toString() ?? '';
    final isFavorite = context.select<AppProvider, bool>(
      (appProvider) => appProvider.isFavoriteId(productId),
    );
    final price = (item['price'] as num?)?.toInt() ?? 0;
    final imageBase64 = item['image_base64']?.toString();
    final image = AppImage(
      imageData: imageBase64 != null && imageBase64.isNotEmpty
          ? imageBase64
          : item['image']?.toString(),
    );

    final imageSource = imageBase64 != null && imageBase64.isNotEmpty
        ? imageBase64
        : item['image']?.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
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
                child: SizedBox(
                  width: 110,
                  height: 120,
                  child: GestureDetector(
                    onTap: () => showProductImagePreview(
                      context,
                      imageData: imageSource,
                      title: item['name_ar']?.toString(),
                    ),
                    child: image,
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
                        item['name_ar']?.toString() ?? '',
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
                        item['description_ar']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.grey,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '${price.toPrice()} د.ع',
                            style: const TextStyle(
                              color: Color(0xFFF5A01D),
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const Spacer(),
                          Builder(
                            builder: (buttonContext) => CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              minimumSize: const Size(82, 44),
                              color: const Color(0xFFF5A01D),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: () => onAdd(buttonContext),
                              child: const Text(
                                'أضف للسلة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Cairo',
                                ),
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
        ),
        Positioned(
          top: 8,
          left: 8,
          child: ProductFavoriteCornerButton(
            isFavorite: isFavorite,
            onTap: () => provider.toggleFavoriteStoreProduct(item, profile),
            activeColor: const Color(0xFFF5A01D),
          ),
        ),
      ],
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

class _StoreCartNavButton extends StatelessWidget {
  final int count;
  final int pulseTick;
  final VoidCallback onTap;

  const _StoreCartNavButton({
    super.key,
    required this.count,
    required this.pulseTick,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(pulseTick),
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: pulseTick > 0 ? 1.2 : 1.0, end: 1.0),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(
                  child: Icon(
                    CupertinoIcons.cart_fill,
                    size: 24,
                    color: AppColors.accent,
                  ),
                ),
                if (count > 0)
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BazaarKindChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _BazaarKindChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: selected ? color : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(25),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: selected ? Colors.white : const Color(0xFF4A4A4A),
            ),
          ),
        ),
      ),
    );
  }
}
