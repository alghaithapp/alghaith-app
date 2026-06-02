import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../utils/extensions.dart';
import '../widgets/app_image.dart';
import 'cart_screen.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final ListItem restaurant;

  const RestaurantMenuScreen({super.key, required this.restaurant});

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen>
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
    )
      ..addStatusListener((status) {
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

  String? get _storePhoneDigits {
    final phone = widget.restaurant.merchantPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
    return phone.isEmpty ? null : phone;
  }

  List<ListItem> _menuItemsForRestaurant(AppProvider provider) {
    final storePhone = _storePhoneDigits;
    final storeName = widget.restaurant.nameAr.trim();

    return provider.items.where((item) {
      if (item.category != 'restaurant' || !item.isAvailable) return false;
      if (item.id == widget.restaurant.id) return false;

      final itemPhone = item.merchantPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
      if (storePhone != null && storePhone.isNotEmpty) {
        return itemPhone.isNotEmpty && itemPhone == storePhone;
      }

      final itemStoreName = (item.merchantStoreName ?? '').trim();
      return itemStoreName.isNotEmpty && itemStoreName == storeName;
    }).toList();
  }

  List<ListItem> _filterMenuItems(List<ListItem> items, String query) {
    if (query.isEmpty) return items;
    return items.where((item) {
      final searchable = [
        item.nameAr,
        item.nameEn,
        item.descriptionAr,
        item.descriptionEn,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final query = _searchController.text.trim().toLowerCase();

    final menuItems = _filterMenuItems(_menuItemsForRestaurant(provider), query);

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
          widget.restaurant.nameAr,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Cairo',
          ),
        ),
        previousPageTitle: 'الرجوع',
        trailing: Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: _CartNavButton(
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
      ),
      child: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _HeaderCard(
                    restaurant: widget.restaurant,
                    menuCount: sortedItems.length,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child:                   CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'ابحث داخل المطعم',
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: sortedItems.isEmpty
                      ? _EmptyState(hasSearch: query.isNotEmpty)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: sortedItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = sortedItems[index];
                            return _MenuItemCard(
                              item: item,
                              onAdd: (buttonContext) async {
                                final added = provider.addToCart(item);
                                if (!added) {
                                  if (!mounted) return;
                                  showCupertinoDialog(
                                    context: context,
                                    builder: (dialogContext) => CupertinoAlertDialog(
                                      title: const Text('تنبيه'),
                                      content: const Text(
                                        'السلة تحتوي منتجات من متجر آخر. أكمل طلبك أو افرغ السلة أولاً.',
                                      ),
                                      actions: [
                                        CupertinoDialogAction(
                                          onPressed: () =>
                                              Navigator.of(dialogContext).pop(),
                                          child: const Text('حسنًا'),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                }
                                await _animateAddToCart(buttonContext);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            if (_showFlyDot)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flyController,
                  builder: (_, __) {
                    final t = Curves.easeInOutCubic.transform(_flyController.value);
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

class _HeaderCard extends StatelessWidget {
  final ListItem restaurant;
  final int menuCount;

  const _HeaderCard({
    required this.restaurant,
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
                          child: const Text(
                            'منيو حقيقي من قاعدة البيانات',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          restaurant.nameAr,
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
                  restaurant.descriptionAr,
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
                          ? 'تقييم'
                          : restaurant.rating!.toStringAsFixed(1),
                      color: Colors.amber,
                    ),
                    _InfoChip(
                      icon: CupertinoIcons.clock_fill,
                      label: restaurant.prepMinutes == null
                          ? 'سريع'
                          : '${restaurant.prepMinutes} د',
                      color: Colors.deepOrange,
                    ),
                    _InfoChip(
                      icon: CupertinoIcons.square_grid_2x2_fill,
                      label: '$menuCount صنف',
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
  final void Function(BuildContext buttonContext) onAdd;

  const _MenuItemCard({
    required this.item,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isFavorite = provider.isFavoriteId(item.id);
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
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () => provider.toggleFavoriteItem(item),
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
                    item.nameAr,
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
                    item.descriptionAr,
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
                      Builder(
                        builder: (buttonContext) => CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          minSize: 0,
                          color:
                              item.isAvailable ? Colors.deepOrange : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: item.isAvailable
                              ? () => onAdd(buttonContext)
                              : null,
                          child: Text(
                            item.isAvailable ? 'أضف للسلة' : 'غير متاح',
                            style: const TextStyle(
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
    final scale = count > 0 && pulseTick.isOdd ? 1.12 : 1.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: SizedBox(
          width: 34,
          height: 34,
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
                  top: -4,
                  left: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyState({
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
              hasSearch ? 'لا توجد نتائج مطابقة' : 'لا توجد وجبات مضافة بعد',
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
                  ? 'جرّب البحث بكلمة مختلفة'
                  : 'سيظهر المنيو الحقيقي هنا عندما يضيف التاجر وجباته.',
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
