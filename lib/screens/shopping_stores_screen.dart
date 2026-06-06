import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../utils/extensions.dart';
import '../utils/helpers.dart';
import '../services/image_storage_service.dart';
import '../utils/merchant_product_sections.dart';
import '../utils/merchant_profile_fields.dart';
import '../widgets/app_image.dart';
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
  });

  @override
  State<ShoppingStoresScreen> createState() => _ShoppingStoresScreenState();
}

class _ShoppingStoresScreenState extends State<ShoppingStoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _futureStores;
  String _selectedFilter = 'الكل';

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

  void _reloadStores() {
    setState(() {
      _futureStores = _loadStores();
    });
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
    _futureStores = _loadStores();
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
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Header Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _IconButton(
                              icon: CupertinoIcons.refresh_thick, 
                              onTap: _reloadStores,
                              color: primaryRed,
                            ),
                            Column(
                              children: [
                                Text(
                                  headerTitle,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                Text(
                                  headerSubtitle,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            _IconButton(
                              icon: CupertinoIcons.house_fill, 
                              onTap: () {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              },
                              color: Colors.black87,
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
                ),

                // 2. Category Filters
                if (widget.showCuisineFilters)
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
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _futureStores,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()));
                    }

                    if (snapshot.hasError) {
                      return SliverFillRemaining(child: _ErrorState(onRetry: _reloadStores));
                    }

                    var stores = (snapshot.data ?? [])
                        .where(_storeHasVisibleProducts)
                        .toList();

                    // Sorting: Open restaurants first
                    stores.sort((a, b) {
                      final aOpen = (a['profile'] as Map)['is_open'] as bool? ?? true;
                      final bOpen = (b['profile'] as Map)['is_open'] as bool? ?? true;
                      if (aOpen && !bOpen) return -1;
                      if (!aOpen && bOpen) return 1;
                      return 0;
                    });

                    // Search and Category Filter
                    final filtered = stores.where((s) {
                      final p = s['profile'] as Map;
                      final name = p['store_name']?.toString().toLowerCase() ?? '';
                      final desc = p['description']?.toString().toLowerCase() ?? '';
                      final resCat = p['restaurantCategory']?.toString() ?? '';
                      
                      final matchesQuery = name.contains(query) || desc.contains(query);
                      final matchesFilter = !widget.showCuisineFilters ||
                          _selectedFilter == 'الكل' ||
                          resCat == _selectedFilter;

                      return matchesQuery && matchesFilter;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const SliverFillRemaining(child: _NoResultsState());
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _PremiumRestaurantCard(
                            data: filtered[index],
                            onTap: () {
                              final profile = Map<String, dynamic>.from(
                                filtered[index]['profile'] as Map,
                              );
                              final products =
                                  (filtered[index]['products'] as List)
                                      .cast<Map<String, dynamic>>();
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) =>
                                      widget.storeKind ==
                                              MerchantStoreKind.restaurant
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
                          ),
                          childCount: filtered.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 4. Guest Mode Banner
          if (appProvider.isGuestMode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _GuestModeBanner(onLogin: () => appProvider.resetAll()),
            ),
        ],
      ),
    );
  }
}

class _PremiumRestaurantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _PremiumRestaurantCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(data['profile'] as Map);
    final products = (data['products'] as List).cast<Map<String, dynamic>>();
    final isOpen = profile['is_open'] as bool? ?? true;
    
    // التقييم الحقيقي من قاعدة البيانات
    final dbRating = profile['rating']?.toDouble();
    final hasRating = dbRating != null && dbRating > 0;
    final ratingLabel = hasRating ? dbRating.toStringAsFixed(1) : 'جديد';

    final primaryRed = const Color(0xFFF5A01D);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover & Status
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: AppImage(
                  imageData: ImageStorageService.merchantUploadedImageRef(
                        profile['cover_image_url'] ??
                            profile['coverImageBase64'],
                      ) ??
                      '',
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOpen ? 'مفتوح الآن' : 'مغلق',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOpen ? Colors.green : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Logo, Name & Rating
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(0, -25),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 65,
                        height: 65,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
                        ),
                        child: ClipOval(
                          child: AppImage(
                            imageData: ImageStorageService.merchantUploadedImageRef(
                                  profile['profile_image_base64'] ??
                                      profile['logoImageBase64'],
                                ) ??
                                '',
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.star_fill, 
                                 color: hasRating ? Colors.amber : Colors.grey, 
                                 size: 12),
                            const SizedBox(width: 4),
                            Text(
                              ratingLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile['store_name']?.toString() ?? 'اسم المطعم',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        profile['description']?.toString() ?? 'ألذ المأكولات العصرية',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 5),
                
                // Info Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _PremiumInfoChip(
                      icon: CupertinoIcons.location_solid,
                      label: MerchantProfileFields.addressFromMap(profile).isNotEmpty
                          ? MerchantProfileFields.addressFromMap(profile)
                          : 'بدون عنوان',
                    ),
                    _PremiumInfoChip(
                      icon: CupertinoIcons.time,
                      label: MerchantProfileFields.workingHoursLabel(profile),
                    ),
                    _PremiumInfoChip(icon: CupertinoIcons.square_grid_2x2_fill, label: '${products.length} صنف'),
                  ],
                ),

                const SizedBox(height: 12),

                // Food Preview Gallery
                if (products.isNotEmpty)
                  SizedBox(
                    height: 55,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: products.length > 5 ? 5 : products.length,
                      itemBuilder: (context, idx) {
                        final isLast = idx == 4 && products.length > 5;
                        return Container(
                          width: 55,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: AppImage(
                                  imageData: products[idx]['image_base64'] ?? products[idx]['image'],
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (isLast)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '+${products.length - 4}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 15),

                // Main Action Button
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primaryRed, const Color(0xFFFF3D00)]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: primaryRed.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: onTap,
                    icon: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      'عرض المنيو',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
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
                hintStyle: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 14),
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
          const Icon(CupertinoIcons.slider_horizontal_3, color: Color(0xFFF5A01D)),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Icon(icon, size: 20, color: color),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(CupertinoIcons.lock_shield_fill, color: Color(0xFFF5A01D), size: 32),
            const SizedBox(width: 15),
            const Expanded(
              child: Text(
                'يمكنك التصفح الآن، ولإكمال الطلب يرجى تسجيل الدخول',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, height: 1.4),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5A01D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('دخول', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          const Text('تعذر تحميل المطاعم حالياً', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.search, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('لا توجد نتائج مطابقة لبحثك', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade600)),
        ],
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

class _ShoppingStoreMenuScreenState extends State<ShoppingStoreMenuScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _cartIconKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  late final AnimationController _flyController;
  Offset _flyStart = Offset.zero;
  Offset _flyEnd = Offset.zero;
  bool _showFlyDot = false;
  int _cartPulseTick = 0;
  String? _selectedSectionKey;

  @override
  void initState() {
    super.initState();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addStatusListener((status) {
        if (!mounted) return;
        if (status == AnimationStatus.completed) {
          setState(() {
            _showFlyDot = false;
            _cartPulseTick++;
          });
        }
      });
  }

  @override
  void dispose() {
    _flyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _animateAddToCart(BuildContext sourceContext) {
    final stackContext = _stackKey.currentContext;
    final cartContext = _cartIconKey.currentContext;
    if (stackContext == null || cartContext == null) return;
    
    final stackBox = stackContext.findRenderObject() as RenderBox?;
    final sourceBox = sourceContext.findRenderObject() as RenderBox?;
    final cartBox = cartContext.findRenderObject() as RenderBox?;
    
    if (stackBox == null || sourceBox == null || cartBox == null) return;
    if (!stackBox.attached || !sourceBox.attached || !cartBox.attached) return;

    final sourceGlobal = sourceBox.localToGlobal(
      Offset(sourceBox.size.width / 2, sourceBox.size.height / 2),
    );
    final cartGlobal = cartBox.localToGlobal(
      Offset(cartBox.size.width / 2, cartBox.size.height / 2),
    );

    if (mounted) {
      setState(() {
        _flyStart = stackBox.globalToLocal(sourceGlobal);
        _flyEnd = stackBox.globalToLocal(cartGlobal);
        _showFlyDot = true;
      });
      _flyController.forward(from: 0);
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
    final provider = context.watch<AppProvider>();
    final allProducts = widget.products
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
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

    final whatsappText = widget.profile['whatsapp']?.toString().trim() ?? '';
    final whatsapp = whatsappText.isNotEmpty
        ? whatsappText
        : AppHelpers.supportWhatsAppNumber;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          widget.profile['store_name']?.toString() ?? 'المحل',
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: _StoreCartNavButton(
              key: _cartIconKey,
              count: provider.cartCount,
              pulseTick: _cartPulseTick,
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const CartScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          clipBehavior: Clip.none, // مهم جداً لمنع اختفاء النقطة عند وصولها للأعلى
          children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StoreHeader(
                profile: widget.profile,
                whatsapp: whatsapp,
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
                            color: selected
                                ? const Color(0xFFF5A01D)
                                : Colors.white,
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
                const Center(child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Text('لا توجد وجبات متاحة حالياً', style: TextStyle(fontFamily: 'Cairo')),
                ))
              else
                ...products.map((item) {
                  return _ProductCard(
                    item: item,
                    profile: widget.profile,
                    onWhatsApp: () => AppHelpers.launchWhatsApp(
                      whatsapp,
                      'مرحبًا، أريد الاستفسار عن ${item['name_ar']?.toString() ?? ''}',
                    ),
                    onAdd: (buttonContext) {
                      final added = provider.addStoreProductToCart(
                        item,
                        profile,
                      );
                      if (!added) {
                        if (!context.mounted) return;
                        showCupertinoDialog(
                          context: context,
                          builder: (dialogContext) => CupertinoAlertDialog(
                            title: const Text('تنبيه'),
                            content: const Text(
                              'السلة تحتوي منتجات من متجر آخر. أكمل طلبك الحالي أو افرغ السلة أولاً.',
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
                      _animateAddToCart(buttonContext);
                    },
                  );
                }),
            ],
          ),
          if (_showFlyDot)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flyController,
                builder: (_, __) {
                  final t =
                      Curves.easeOutCubic.transform(_flyController.value); // مسار أنعم
                  final x = _flyStart.dx + ((_flyEnd.dx - _flyStart.dx) * t);
                  final yBase = _flyStart.dy + ((_flyEnd.dy - _flyStart.dy) * t);
                  
                  // معادلة القوس الحقيقي (Parabola)
                  final arc = -180 * t * (1 - t); 
                  
                  final scale = 1.0 - (t * 0.3);
                  return Positioned(
                    left: x - 12,
                    top: yBase + arc - 12,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5A01D),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF5A01D).withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _StoreHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String whatsapp;

  const _StoreHeader({
    required this.profile,
    required this.whatsapp,
  });

  @override
  Widget build(BuildContext context) {
    final address = MerchantProfileFields.addressFromMap(profile);
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
                label: address.isNotEmpty ? address : 'بدون عنوان',
              ),
              _InfoChip(
                icon: CupertinoIcons.time,
                label: MerchantProfileFields.workingHoursLabel(profile),
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
                    'مرحبًا، أريد الاستفسار عن المحل.',
                  ),
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
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => AppHelpers.makePhoneCall(
                    phone.isNotEmpty ? phone : whatsapp,
                  ),
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
  final Future<void> Function(BuildContext buttonContext) onAdd;

  const _ProductCard({
    required this.item,
    required this.profile,
    required this.onWhatsApp,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final productId = item['id']?.toString() ?? '';
    final isFavorite = provider.isFavoriteId(productId);
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
            child: SizedBox(
              width: 110,
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () => provider.toggleFavoriteStoreProduct(
                        item,
                        profile,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          size: 18,
                          color: isFavorite ? Colors.red : Colors.grey,
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
                  const Spacer(),
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
                            horizontal: 14,
                            vertical: 7,
                          ),
                          minSize: 0,
                          color: const Color(0xFFF5A01D),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () => onAdd(buttonContext),
                          child: const Text(
                            'أضف للسلة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 1.0, end: pulseTick > 0 ? 1.2 : 1.0),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale > 1.2 ? 1.2 : scale,
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
                    color: Color(0xFFF5A01D),
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
