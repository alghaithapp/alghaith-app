import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_models.dart';
import '../../../providers/app_provider.dart';
import '../../../services/image_storage_service.dart';
import '../../../utils/extensions.dart';
import '../../../utils/chat_navigation.dart';
import '../../../utils/guest_gate.dart';
import '../../../utils/merchant_product_sections.dart';
import '../../../utils/merchant_profile_fields.dart';
import '../../../utils/merchant_service_labels.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/internal_contact_buttons.dart';
import '../../../widgets/product_image_preview.dart';
import '../../../widgets/service_navigation_buttons.dart';
import 'cart_screen.dart';
import 'shopping_shared_widgets.dart';

// ── Store Menu Screen ──────────────────────────────────────

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
        MerchantProfileFields.merchantInternalContactPhone(widget.profile);
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
              builder: (context, cartCount, _) => ShopStoreCartNavButton(
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
            ShopStoreHeader(
              profile: widget.profile,
              merchantPhone: customerPhone,
              chatLabel: widget.storeKind == MerchantStoreKind.restaurant
                  ? 'مراسلة المطعم'
                  : merchantChatLabelFromProfile(widget.profile),
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
                return ShopProductCard(
                  item: item,
                  profile: widget.profile,
                  onWhatsApp: () {
                    if (!GuestGate.requireAccount(
                      context,
                      message: 'سجّل دخولك للتواصل مع المتجر.',
                    )) {
                      return;
                    }
                    final phone = customerPhone.trim();
                    if (phone.isEmpty) return;
                    ChatNavigation.openStoreChat(
                      context,
                      merchantPhone: phone,
                      storeName: MerchantProfileFields.name(widget.profile),
                      merchantProfile: widget.profile,
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

// ── Store Header ───────────────────────────────────────────

class ShopStoreHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String merchantPhone;
  final String chatLabel;

  const ShopStoreHeader({
    super.key,
    required this.profile,
    required this.merchantPhone,
    required this.chatLabel,
  });

  @override
  Widget build(BuildContext context) {
    final address = MerchantProfileFields.addressFromMap(profile);
    final contactPhone = merchantPhone.trim();
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
              ShopStoreInfoChip(
                icon: CupertinoIcons.location_solid,
                label: address.isNotEmpty ? address : 'بدون عنوان',
              ),
              ShopStoreInfoChip(
                icon: CupertinoIcons.time,
                label: MerchantProfileFields.workingHoursLabel(profile),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (contactPhone.isEmpty)
            const Text(
              'لا يتوفر تواصل مع هذا المتجر حالياً.',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.grey,
                fontSize: 12,
              ),
            )
          else
            InternalContactButtons.store(
              merchantPhone: contactPhone,
              storeName: MerchantProfileFields.name(profile),
              merchantProfile: profile,
              chatLabel: chatLabel,
              callLabel: 'اتصال',
            ),
        ],
      ),
    );
  }
}

// ── Product Card ───────────────────────────────────────────

class ShopProductCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, dynamic> profile;
  final VoidCallback onWhatsApp;
  final void Function(BuildContext buttonContext) onAdd;

  const ShopProductCard({
    super.key,
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
    final price = parseProductPrice(item);
    final productImage = ImageStorageService.resolveDisplayImage(
      imageBase64: item['image_base64']?.toString(),
      image: item['image']?.toString(),
      imageUrl: item['image_url']?.toString(),
    );
    final image = AppImage(imageData: productImage);
    final imageSource = productImage;

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

// ── Info Chip (used inside StoreHeader) ────────────────────

class ShopStoreInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const ShopStoreInfoChip({
    super.key,
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

// ── Cart Nav Button ────────────────────────────────────────

class ShopStoreCartNavButton extends StatelessWidget {
  final int count;
  final int pulseTick;
  final VoidCallback onTap;

  const ShopStoreCartNavButton({
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
