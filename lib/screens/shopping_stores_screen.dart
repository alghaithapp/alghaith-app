import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../utils/extensions.dart';
import '../utils/helpers.dart';
import '../../widgets/app_image.dart';
import 'cart_screen.dart';

enum MerchantStoreKind { shopping, restaurant }

class ShoppingStoresScreen extends StatefulWidget {
  final ServiceCategory? subCategory;
  final MerchantStoreKind storeKind;

  const ShoppingStoresScreen({
    super.key,
    this.subCategory,
    this.storeKind = MerchantStoreKind.shopping,
  });

  @override
  State<ShoppingStoresScreen> createState() => _ShoppingStoresScreenState();
}

class _ShoppingStoresScreenState extends State<ShoppingStoresScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _futureStores;

  Future<List<Map<String, dynamic>>> _loadStores() {
    if (widget.storeKind == MerchantStoreKind.restaurant) {
      return SupabaseService.loadRestaurantStores(
        subCategoryId: widget.subCategory?.id,
      );
    }
    return SupabaseService.loadShoppingStores(
      subCategoryId: widget.subCategory!.id,
    );
  }

  void _reloadStores() {
    setState(() {
      _futureStores = _loadStores();
    });
  }

  List<Map<String, dynamic>> _buildRestaurantFallbackStores(AppProvider provider) {
    final targetSubCategory = widget.subCategory?.id;
    final restaurantItems = provider.items.where((item) {
      if (item.category != 'restaurant' || !item.isAvailable) return false;
      if (targetSubCategory == null || targetSubCategory.isEmpty) return true;
      return item.subCategory == targetSubCategory;
    }).toList();

    if (restaurantItems.isEmpty) return const [];

    final profile = Map<String, dynamic>.from(provider.merchantStore ?? const {});
    final storeName = (profile['name']?.toString().trim() ?? '').isNotEmpty
        ? profile['name']?.toString().trim()
        : 'مطعمك';
    final description = profile['description']?.toString().trim() ?? '';
    final phone = profile['phone']?.toString().trim() ?? provider.customerPhone;
    final whatsapp = profile['whatsapp']?.toString().trim() ?? phone;
    final address = profile['address']?.toString().trim() ?? '';
    final openTime = profile['openTime']?.toString().trim() ?? '';
    final closeTime = profile['closeTime']?.toString().trim() ?? '';
    final profileImage = profile['profileImageBase64']?.toString().trim() ?? '';
    final workSamples = provider.merchantWorkSampleImagesBase64;

    return [
      {
        'profile': {
          'store_name': storeName,
          'description': description,
          'phone': phone,
          'whatsapp': whatsapp,
          'address': address,
          'open_time': openTime,
          'close_time': closeTime,
          'latitude': provider.merchantLatitude,
          'longitude': provider.merchantLongitude,
          'profile_image_base64': profileImage,
          'work_sample_images_base64': workSamples,
        },
        'products': restaurantItems
            .map((item) => {
                  'id': item.id,
                  'name_ar': item.nameAr,
                  'description_ar': item.descriptionAr,
                  'price': item.price,
                  'category': item.category,
                  'sub_category': item.subCategory,
                  'image': item.image,
                  'image_base64': item.imageBase64,
                  'is_available': item.isAvailable,
                })
            .toList(),
      },
    ];
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
    final query = _searchController.text.trim().toLowerCase();

    final isRestaurant = widget.storeKind == MerchantStoreKind.restaurant;
    final title = widget.subCategory != null
        ? widget.subCategory!.titleAr
        : (isRestaurant ? 'المطاعم' : 'التسوق');

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        previousPageTitle: 'الرجوع',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _reloadStores,
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: isRestaurant
                    ? 'ابحث عن مطعم'
                    : 'ابحث عن سوق أو محل',
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _futureStores,
                builder: (context, snapshot) {
                  final provider = context.read<AppProvider>();
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }

                  if (snapshot.hasError) {
                    return _EmptyState(
                      message: isRestaurant
                          ? 'تعذر تحميل المطاعم'
                          : 'تعذر تحميل الأسواق',
                      onRetry: _reloadStores,
                    );
                  }

                  final remoteStores = snapshot.data ?? const [];
                  final stores = remoteStores.isEmpty && isRestaurant
                      ? _buildRestaurantFallbackStores(provider)
                      : remoteStores;
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
                      onRetry: _reloadStores,
                      message: query.isEmpty
                          ? (isRestaurant
                              ? 'لا توجد مطاعم في هذا القسم بعد'
                              : 'لا توجد أسواق أو محلات في هذا القسم بعد')
                          : 'لا توجد نتائج مطابقة',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      _reloadStores();
                      await _futureStores;
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _StoreCard(
                          data: filtered[index],
                          subCategory: widget.subCategory,
                          storeKind: widget.storeKind,
                        );
                      },
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

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ServiceCategory? subCategory;
  final MerchantStoreKind storeKind;

  const _StoreCard({
    required this.data,
    required this.subCategory,
    required this.storeKind,
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
                        profile['store_name']?.toString() ?? 'متجر',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile['description']?.toString() ??
                            'منيو حقيقي من نفس المتجر',
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
                      label: address.isNotEmpty ? address : 'بدون عنوان',
                    ),
                    _InfoChip(
                      icon: CupertinoIcons.time,
                      label:
                          '${profile['open_time']?.toString() ?? ''} - ${profile['close_time']?.toString() ?? ''}',
                    ),
                    _InfoChip(
                      icon: CupertinoIcons.cube_box_fill,
                      label: '${products.length} منتج',
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
                            profile: profile,
                            products: products,
                            subCategory: subCategory,
                            storeKind: storeKind,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(
                      storeKind == MerchantStoreKind.restaurant
                          ? 'عرض المنيو'
                          : 'فتح المنيو',
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

  Future<void> _animateAddToCart(BuildContext sourceContext) async {
    final stackContext = _stackKey.currentContext;
    final cartContext = _cartIconKey.currentContext;
    if (stackContext == null || cartContext == null) return;
    final stackBox = stackContext.findRenderObject() as RenderBox?;
    final sourceBox = sourceContext.findRenderObject() as RenderBox?;
    final cartBox = cartContext.findRenderObject() as RenderBox?;
    if (stackBox == null || sourceBox == null || cartBox == null) return;

    final sourceGlobal = sourceBox.localToGlobal(
      Offset(sourceBox.size.width / 2, sourceBox.size.height / 2),
    );
    final cartGlobal = cartBox.localToGlobal(
      Offset(cartBox.size.width / 2, cartBox.size.height / 2),
    );

    setState(() {
      _flyStart = stackBox.globalToLocal(sourceGlobal);
      _flyEnd = stackBox.globalToLocal(cartGlobal);
      _showFlyDot = true;
    });
    await _flyController.forward(from: 0);
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
    final query = _searchController.text.trim().toLowerCase();
    final allProducts = widget.products
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final products = _filterProducts(allProducts);

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
              if (products.isEmpty)
                _StoreMenuEmptyState(
                  hasSearch: query.isNotEmpty,
                  isRestaurant: widget.storeKind == MerchantStoreKind.restaurant,
                )
              else
                ...products.map((item) {
                  return _ProductCard(
                    item: item,
                    profile: widget.profile,
                    onWhatsApp: () => AppHelpers.launchWhatsApp(
                      whatsapp,
                      'مرحبًا، أريد الاستفسار عن ${item['name_ar']?.toString() ?? ''}',
                    ),
                    onAdd: (buttonContext) async {
                      final added = provider.addStoreProductToCart(
                        item,
                        widget.profile,
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
                      await _animateAddToCart(buttonContext);
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
                      Curves.easeInOutCubic.transform(_flyController.value);
                  final x = _flyStart.dx + ((_flyEnd.dx - _flyStart.dx) * t);
                  final yBase = _flyStart.dy + ((_flyEnd.dy - _flyStart.dy) * t);
                  final arc = -70 * (1 - (2 * t - 1).abs());
                  final scale = 1 - (t * 0.4);
                  return Positioned(
                    left: x - 10,
                    top: yBase + arc - 10,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepOrange.withValues(alpha: 0.4),
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
                label: address.isNotEmpty ? address : 'بدون عنوان',
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
                    'مرحبًا، أريد الاستفسار عن المحل.',
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('واتساب'),
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
                  label: const Text('اتصال'),
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
                          color: Colors.deepOrange,
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
                          color: Colors.deepOrange,
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
    final scale = count > 0 && pulseTick.isOdd ? 1.12 : 1.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
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
                    color: Colors.deepOrange,
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

class _StoreMenuEmptyState extends StatelessWidget {
  final bool hasSearch;
  final bool isRestaurant;

  const _StoreMenuEmptyState({
    required this.hasSearch,
    required this.isRestaurant,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.deepOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              hasSearch
                  ? CupertinoIcons.search
                  : (isRestaurant
                      ? Icons.restaurant_menu_rounded
                      : Icons.storefront_rounded),
              color: Colors.deepOrange,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? 'لا توجد نتائج مطابقة'
                : (isRestaurant
                    ? 'لا توجد أصناف في منيو هذا المطعم بعد'
                    : 'لا توجد منتجات في هذا المتجر بعد'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'جرّب كلمة بحث مختلفة'
                : 'سيظهر المنيو هنا عندما يضيف التاجر منتجاته.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.grey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _EmptyState({
    required this.message,
    this.onRetry,
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
              child: Icon(
                message.contains('مطاعم')
                    ? Icons.restaurant_rounded
                    : Icons.storefront_rounded,
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
            const Text(
              'عندما يسجّل تاجر مطعمه ويضيف منتجات، ستظهر هنا للزبائن.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.grey,
                height: 1.45,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              CupertinoButton(
                color: Colors.deepOrange,
                borderRadius: BorderRadius.circular(14),
                onPressed: onRetry,
                child: const Text(
                  'تحديث',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
