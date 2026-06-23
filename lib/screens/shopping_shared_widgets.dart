import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_models.dart';
import '../services/image_storage_service.dart';
import '../utils/merchant_profile_fields.dart';
import '../utils/extensions.dart';
import '../utils/chat_navigation.dart';
import '../utils/guest_gate.dart';
import '../widgets/app_image.dart';
import 'shopping_store_menu_screen.dart';

// ── Store Kind Enum ────────────────────────────────────────

enum MerchantStoreKind { shopping, restaurant }

// ── Back Button ────────────────────────────────────────────

class ShopBackButton extends StatelessWidget {
  final bool hide;

  const ShopBackButton({super.key, this.hide = false});

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

// ── Premium Restaurant Card ────────────────────────────────

class ShopRestaurantCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isRestaurant;
  final VoidCallback onTap;

  const ShopRestaurantCard({
    super.key,
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
    final storeName = MerchantProfileFields.name(profile);

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
          // 1. Header
          SizedBox(
            height: 200,
            child: Stack(
              children: [
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

          // 2. Stats Bar
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
                  ShopStatItem(label: 'منتج', value: '$productsCount', icon: Icons.shopping_bag_outlined),
                  _divider(),
                  ShopStatItem(label: 'طلب', value: ordersCount, icon: Icons.shopping_cart_outlined),
                  _divider(),
                  ShopStatItem(label: 'عميل', value: clientsCount, icon: Icons.groups_outlined),
                  _divider(),
                  ShopStatItem(label: 'التقييم', value: ratingLabel, icon: Icons.star_outline_rounded, color: Colors.amber),
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

          // 4. Action Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ShopActionBtn(
                        label: 'مراسلة',
                        icon: Icons.chat_bubble_outline_rounded,
                        color: AppColors.primary,
                        onTap: () {
                          if (!GuestGate.requireAccount(
                            context,
                            message: 'سجّل دخولك للتواصل مع المتجر.',
                          )) {
                            return;
                          }
                          if (customerPhone.isEmpty) return;
                          ChatNavigation.openStoreChat(
                            context,
                            merchantPhone: customerPhone,
                            storeName: storeName,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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

// ── Stat Item ──────────────────────────────────────────────

class ShopStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const ShopStatItem({super.key, required this.label, required this.value, required this.icon, this.color});

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

// ── Action Button ──────────────────────────────────────────

class ShopActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ShopActionBtn({super.key, required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: EdgeInsets.zero,
          ),
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 20),
          label: Text(
            label,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: color, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

// ── Info Chip ──────────────────────────────────────────────

class ShopInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const ShopInfoChip({super.key, required this.icon, required this.label});

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

// ── Search Bar ─────────────────────────────────────────────

class ShopSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const ShopSearchBar({super.key, required this.controller, required this.onChanged});

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

// ── Guest Mode Banner ──────────────────────────────────────

class ShopGuestBanner extends StatelessWidget {
  final VoidCallback onLogin;

  const ShopGuestBanner({super.key, required this.onLogin});

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

// ── Error State ────────────────────────────────────────────

class ShopErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final String label;
  const ShopErrorState({super.key, required this.onRetry, this.label = 'المحتوى'});

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

// ── No Results State ───────────────────────────────────────

class ShopNoResultsState extends StatelessWidget {
  final bool isBazaar;
  final bool hasStores;
  final bool hasSearch;
  final bool hasCuisineFilter;

  const ShopNoResultsState({
    super.key,
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

// ── Bazaar Kind Chip ───────────────────────────────────────

class ShopBazaarKindChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const ShopBazaarKindChip({
    super.key,
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
