import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../models/merchant_product_section.dart';
import '../providers/app_provider.dart';
import '../utils/extensions.dart';
import '../utils/guest_gate.dart';
import '../utils/helpers.dart';
import '../utils/merchant_profile_fields.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../widgets/app_image.dart';
import '../widgets/product_image_preview.dart';
import '../widgets/service_navigation_buttons.dart';
import '../utils/merchant_product_sections.dart';
import 'cart_screen.dart';

const _brandRed = AppColors.accent;
const _brandRedDark = AppColors.accentDark;

class RestaurantMenuScreen extends StatefulWidget {
  final Map<String, dynamic> storeProfile;
  final List<Map<String, dynamic>> storeProducts;

  const RestaurantMenuScreen({
    super.key,
    required this.storeProfile,
    required this.storeProducts,
  });

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _cartIconKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  String? _selectedSectionKey;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ListItem get _restaurant => _listItemFromProfile(widget.storeProfile);

  String? get _restaurantImageData {
    final profile = widget.storeProfile;
    return profile['cover_image_url']?.toString() ??
        profile['coverImageBase64']?.toString() ??
        'assets/images/cat_restaurant.png';
  }

  String? get _whatsappNumber {
    final whatsapp =
        MerchantProfileFields.customerVisibleWhatsApp(widget.storeProfile).trim();
    if (whatsapp.isEmpty) return null;
    return whatsapp;
  }

  String? get _storeCustomerPhone {
    final phone = MerchantProfileFields.customerVisiblePhone(widget.storeProfile).trim();
    if (phone.isEmpty) return null;
    return phone;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  ListItem _listItemFromProfile(Map<String, dynamic> profile) {
    final phone = profile['phone']?.toString() ?? '';
    final id = profile['id']?.toString() ?? 'restaurant_$phone';
    return ListItem(
      id: id,
      nameAr: profile['store_name']?.toString() ?? 'مطعم',
      nameEn: profile['store_name_en']?.toString() ??
          profile['store_name']?.toString() ??
          '',
      descriptionAr: profile['description']?.toString() ?? '',
      descriptionEn: profile['description_en']?.toString() ?? '',
      price: 0,
      rating: (profile['rating'] as num?)?.toDouble() ?? 4.8,
      category: 'restaurant',
      categoryLabelAr: 'مطعم',
      categoryLabelEn: 'Restaurant',
      image: 'assets/images/cat_restaurant.png',
      address: MerchantProfileFields.addressFromMap(profile),
      merchantPhone: phone,
      merchantStoreName: profile['store_name']?.toString(),
      merchantLatitude: _toDouble(
        profile['latitude'] ?? profile['lat'] ?? profile['merchant_latitude'],
      ),
      merchantLongitude: _toDouble(
        profile['longitude'] ?? profile['lng'] ?? profile['merchant_longitude'],
      ),
      merchantOpenTime:
          MerchantProfileFields.timeFromMap(profile, isOpen: true),
      merchantCloseTime:
          MerchantProfileFields.timeFromMap(profile, isOpen: false),
      merchantIsOpen: profile['is_open'] is bool
          ? profile['is_open'] as bool
          : (profile['is_open']?.toString().toLowerCase() == 'true'),
      merchantIsFrozen: profile['is_frozen'] is bool
          ? profile['is_frozen'] as bool
          : (profile['is_frozen']?.toString().toLowerCase() == 'true'),
      avgPriceLabelAr: '',
      avgPriceLabelEn: '',
      actionLabelAr: 'عرض المنيو',
      actionLabelEn: 'View menu',
    );
  }

  String? get _storePhoneDigits {
    final phone =
        _restaurant.merchantPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
    return phone.isEmpty ? null : phone;
  }

  List<ListItem> _allMenuItems(AppProvider provider) {
    return widget.storeProducts
        .where((row) => row['is_available'] != false)
        .map((row) =>
            provider.listItemFromStoreProduct(row, widget.storeProfile))
        .toList();
  }

  List<MerchantProductSection> get _storeSections =>
      MerchantProductSections.parseFromProfile(widget.storeProfile);

  List<Map<String, dynamic>> get _rawProducts =>
      widget.storeProducts.cast<Map<String, dynamic>>();

  List<ListItem> _filterMenuItems(List<ListItem> items, String query) {
    var filtered = items;
    final sections = _storeSections;
    if (sections.isNotEmpty && _selectedSectionKey != null) {
      final allowedIds = MerchantProductSections.filterProducts(
        products: _rawProducts,
        sections: sections,
        selectedKey: _selectedSectionKey,
      ).map((row) => row['id']?.toString()).toSet();
      filtered = filtered.where((item) => allowedIds.contains(item.id)).toList();
    }
    if (query.isEmpty) return filtered;
    return filtered.where((item) {
      final searchable = [
        item.nameAr,
        item.nameEn,
        item.descriptionAr,
        item.descriptionEn,
        item.subCategory ?? '',
        item.categoryLabelAr,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  bool _cartBelongsToRestaurant(AppProvider provider) {
    if (provider.cart.isEmpty) return false;
    final storePhone = _storePhoneDigits;
    final storeName = _restaurant.nameAr.trim();
    return provider.cart.every((item) {
      final itemPhone = item.merchantPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
      if (storePhone != null && storePhone.isNotEmpty && itemPhone.isNotEmpty) {
        return itemPhone == storePhone;
      }
      final itemStore = item.merchantStoreName?.trim() ?? '';
      return itemStore.isNotEmpty && itemStore == storeName;
    });
  }

  int _countInCart(AppProvider provider, String id) {
    final match = provider.cart.where((item) => item.id == id);
    if (match.isEmpty) return 0;
    return match.first.count;
  }

  Future<void> _showCartRestrictionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'تنبيه',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            color: _brandRed,
          ),
        ),
        content: const Text(
          'لا يمكن الطلب من أكثر من مطعم في نفس الوقت.\n'
          'يرجى إكمال الطلب الحالي أو إفراغ السلة أولاً.',
          style: TextStyle(fontFamily: 'Cairo', height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          FilledButton(
            style: AppButtonStyles.accentFilled(),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'إفراغ السلة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      context.read<AppProvider>().clearCart();
    }
  }

  Future<void> _handleAddItem(ListItem item, BuildContext buttonContext) async {
    if (!GuestGate.requireAccount(
      context,
      message: 'سجّل دخولك لإضافة المنتجات إلى السلة والتسوق.',
    )) {
      return;
    }
    final provider = context.read<AppProvider>();
    if (item.merchantIsFrozen == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هذا الحساب مجمّد حالياً ولا يستقبل أي طلبات جديدة.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }
    final current = _countInCart(provider, item.id);
    if (current > 0) {
      provider.incrementCartItem(item.id);
      return;
    }
    final added = provider.addToCart(item);
    if (!added) {
      await _showCartRestrictionDialog();
      return;
    }
  }

  void _handleDecrement(ListItem item) {
    final provider = context.read<AppProvider>();
    if (_countInCart(provider, item.id) <= 0) return;
    provider.decrementCartItem(item.id);
  }

  String get _workingHoursLabel {
    return MerchantProfileFields.workingHoursLabel({
      'openTime': _restaurant.merchantOpenTime,
      'closeTime': _restaurant.merchantCloseTime,
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final restaurant = _restaurant;
    final allItems = _allMenuItems(provider);
    final sectionTabs = MerchantProductSections.tabsForStore(
      sections: _storeSections,
      products: _rawProducts,
    );
    final menuItems = _filterMenuItems(allItems, query);
    final isRestaurantFavorite = provider.isFavoriteId(restaurant.id);

    final sortedItems = [...menuItems]..sort((a, b) {
        final favoriteCompare =
            (b.isFavorite ? 1 : 0).compareTo(a.isFavorite ? 1 : 0);
        if (favoriteCompare != 0) return favoriteCompare;
        return (b.rating ?? 0).compareTo(a.rating ?? 0);
      });

    final mostOrdered = [...allItems]
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    final topOrdered = mostOrdered.take(8).toList();

    final showStickyCart =
        provider.cart.isNotEmpty && _cartBelongsToRestaurant(provider);
    final restaurantImage = _restaurantImageData;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        key: _stackKey,
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _HeroSection(
                  restaurant: restaurant,
                  imageData: restaurantImage,
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -36),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _RestaurantInfoCard(
                      address: restaurant.address?.trim().isNotEmpty == true
                          ? restaurant.address!
                          : 'العنوان غير متوفر',
                      hours: _workingHoursLabel,
                      onCall: _storeCustomerPhone == null
                          ? null
                          : () {
                        if (!GuestGate.requireAccount(
                          context,
                          message: 'سجّل دخولك للتواصل مع المتجر.',
                        )) {
                          return;
                        }
                        final phone = _storeCustomerPhone;
                        if (phone == null || phone.isEmpty) return;
                        AppHelpers.makePhoneCall(phone);
                      },
                      onWhatsApp: _whatsappNumber == null
                          ? null
                          : () {
                        if (!GuestGate.requireAccount(
                          context,
                          message: 'سجّل دخولك للتواصل مع المتجر.',
                        )) {
                          return;
                        }
                        final phone = _whatsappNumber;
                        if (phone == null || phone.isEmpty) return;
                        AppHelpers.launchWhatsApp(
                          phone,
                          'مرحباً، أريد الاستفسار عن ${restaurant.nameAr}',
                        );
                      },
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _SearchBar(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              if (sectionTabs.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 46,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected ? _brandRed : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected
                                    ? _brandRed
                                    : const Color(0xFFE8E8E8),
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color:
                                            _brandRed.withValues(alpha: 0.28),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              tab.label,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color:
                                    selected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (query.isEmpty && topOrdered.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Text(
                      '🔥 الأكثر طلباً',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 210,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: topOrdered.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final item = topOrdered[index];
                        return Builder(
                          builder: (cardContext) => _MostOrderedCard(
                            item: item,
                            onTap: () => _handleAddItem(item, cardContext),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text(
                    'قائمة الطعام',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
              if (sortedItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptySearchState(hasSearch: query.isNotEmpty),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    showStickyCart ? 120 : 32,
                  ),
                  sliver: SliverList.separated(
                    itemCount: sortedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = sortedItems[index];
                      return _MenuItemCard(
                        item: item,
                        quantity: _countInCart(provider, item.id),
                        onAdd: (ctx) => _handleAddItem(item, ctx),
                        onDecrement: () => _handleDecrement(item),
                        onFavorite: () => provider.toggleFavoriteItem(item),
                      );
                    },
                  ),
                ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                ServiceBackButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                _CircleNavButton(
                  icon: isRestaurantFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  iconColor: isRestaurantFavorite ? _brandRed : Colors.black87,
                  onTap: () => provider.toggleFavoriteItem(restaurant),
                ),
                const SizedBox(width: 8),
                _CartNavButton(
                  key: _cartIconKey,
                  count: provider.cartCount,
                  pulseTick: 0,
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const CartScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          if (showStickyCart)
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: _StickyCartBar(
                total: provider.cartTotal,
                itemCount: provider.cartCount,
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final ListItem restaurant;
  final String? imageData;

  const _HeroSection({
    required this.restaurant,
    required this.imageData,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          AppImage(imageData: imageData),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 52,
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: AppImage(imageData: imageData),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    restaurant.nameAr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    restaurant.descriptionAr.trim().isNotEmpty
                        ? restaurant.descriptionAr
                        : 'مشويات عراقية بطعم أصيل',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.4,
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

class _RestaurantInfoCard extends StatelessWidget {
  final String address;
  final String hours;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;

  const _RestaurantInfoCard({
    required this.address,
    required this.hours,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.location_on_rounded,
            label: address,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: hours,
          ),
          const SizedBox(height: 16),
          if (onCall == null && onWhatsApp == null)
            const Text(
              'المتجر أخفى وسائل التواصل حالياً.',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFF777777),
                fontSize: 12,
              ),
            )
          else
            Row(
              children: [
                if (onCall != null)
                  Expanded(
                    child: _ActionChip(
                      label: 'اتصال',
                      icon: Icons.phone_rounded,
                      color: _brandRed,
                      onTap: onCall!,
                    ),
                  ),
                if (onCall != null && onWhatsApp != null) const SizedBox(width: 10),
                if (onWhatsApp != null)
                  Expanded(
                    child: _ActionChip(
                      label: 'واتساب',
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF25D366),
                      onTap: onWhatsApp!,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _brandRed),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF444444),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search_rounded, color: Color(0xFF9E9E9E), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'ابحث داخل المنيو...',
                hintStyle: TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFFAAAAAA),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MostOrderedCard extends StatelessWidget {
  final ListItem item;
  final VoidCallback onTap;

  const _MostOrderedCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image =
        item.imageBase64?.isNotEmpty == true ? item.imageBase64 : item.image;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              child: SizedBox(
                height: 118,
                width: double.infinity,
                child: AppImage(imageData: image),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nameAr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.price.toPrice()} د.ع',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: _brandRed,
                    ),
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

class _MenuItemCard extends StatelessWidget {
  final ListItem item;
  final int quantity;
  final void Function(BuildContext) onAdd;
  final VoidCallback onDecrement;
  final VoidCallback onFavorite;

  const _MenuItemCard({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onDecrement,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isFavorite = provider.isFavoriteId(item.id);
    final image =
        item.imageBase64?.isNotEmpty == true ? item.imageBase64 : item.image;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(24)),
                child: SizedBox(
                  width: 118,
                  height: 132,
                  child: GestureDetector(
                    onTap: () => showProductImagePreview(
                      context,
                      imageData: image,
                      title: item.nameAr,
                    ),
                    child: AppImage(imageData: image),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nameAr,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                  const SizedBox(height: 8),
                  Text(
                    item.descriptionAr.trim().isNotEmpty
                        ? item.descriptionAr
                        : 'طبق شهي من ${item.merchantStoreName ?? 'المطعم'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xFF777777),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.price.toPrice()} د.ع',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: _brandRed,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 116,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: quantity == 0
                              ? Builder(
                                  builder: (buttonContext) => _AddButton(
                                    onTap: item.isAvailable
                                        ? () => onAdd(buttonContext)
                                        : null,
                                  ),
                                )
                              : _QuantityControls(
                                  quantity: quantity,
                                  onAdd: () => onAdd(context),
                                  onRemove: onDecrement,
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
          top: 10,
          left: 10,
          child: ProductFavoriteCornerButton(
            isFavorite: isFavorite,
            onTap: onFavorite,
            activeColor: _brandRed,
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _brandRed,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'إضافة',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityControls extends StatelessWidget {
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QuantityControls({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QtyButton(icon: Icons.remove_rounded, onTap: onRemove),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '$quantity',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
        _QtyButton(icon: Icons.add_rounded, onTap: onAdd),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _brandRed,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _StickyCartBar extends StatelessWidget {
  final int total;
  final int itemCount;
  final VoidCallback onTap;

  const _StickyCartBar({
    required this.total,
    required this.itemCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_brandRed, _brandRedDark],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: _brandRed.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${total.toPrice()} د.ع',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '$itemCount ${itemCount == 1 ? 'صنف' : 'أصناف'}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'عرض السلة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
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

class _CircleNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _CircleNavButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: iconColor ?? Colors.black87),
        ),
      ),
    );
  }
}

class _CartNavButton extends StatelessWidget {
  final int count;
  final int pulseTick;
  final VoidCallback onTap;

  const _CartNavButton({
    super.key,
    required this.count,
    required this.pulseTick,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scale = count > 0 && pulseTick.isOdd ? 1.14 : 1.0;
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(
                  child: Icon(
                    Icons.shopping_cart_rounded,
                    size: 22,
                    color: _brandRed,
                  ),
                ),
                if (count > 0)
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _brandRed,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
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

class _EmptySearchState extends StatelessWidget {
  final bool hasSearch;

  const _EmptySearchState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: _brandRed,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            hasSearch ? 'لم يتم العثور على نتائج' : 'لا توجد وجبات مضافة بعد',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'جرّب كلمة بحث مختلفة أو اختر فئة أخرى'
                : 'سيظهر المنيو هنا عندما يضيف التاجر وجباته',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Color(0xFF777777),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
