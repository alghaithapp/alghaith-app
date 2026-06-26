import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_models.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/extensions.dart';
import '../../../utils/guest_gate.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/service_navigation_buttons.dart';
import 'cart_screen.dart';

class SubCategoryItemsScreen extends StatefulWidget {
  final ServiceCategory subCategory;

  const SubCategoryItemsScreen({super.key, required this.subCategory});

  @override
  State<SubCategoryItemsScreen> createState() => _SubCategoryItemsScreenState();
}

class _SubCategoryItemsScreenState extends State<SubCategoryItemsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
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

  List<ListItem> _filteredItems(AppProvider appProvider) {
    final base = appProvider.items
        .where((item) => item.subCategory == widget.subCategory.id)
        .toList();
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base.where((item) {
      return item.nameAr.toLowerCase().contains(q) ||
          item.descriptionAr.toLowerCase().contains(q) ||
          (item.merchantStoreName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final filteredItems = _filteredItems(appProvider);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: ServiceNavigationBar(
        title: widget.subCategory.titleAr,
        trailing: _CartNavButton(
          key: _cartIconKey,
          count: appProvider.cartCount,
          pulseTick: _cartPulseTick,
          onTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const CartScreen()),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'بحث في هذا القسم...',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.search,
                                size: 60,
                                color: CupertinoColors.systemGrey4,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _query.trim().isEmpty
                                    ? 'لا توجد نتائج في قسم ${widget.subCategory.titleAr} حاليًا'
                                    : 'لا توجد نتائج للبحث',
                                style: const TextStyle(
                                  color: CupertinoColors.systemGrey,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
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
                                    height: 180,
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.nameAr,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  fontFamily: 'Cairo',
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () =>
                                                  appProvider.toggleFavorite(item.id),
                                              child: Icon(
                                                item.isFavorite
                                                    ? CupertinoIcons.heart_fill
                                                    : CupertinoIcons.heart,
                                                color: item.isFavorite
                                                    ? Colors.red
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if ((item.merchantStoreName ?? '')
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            item.merchantStoreName!,
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          item.descriptionAr,
                                          style: const TextStyle(
                                            color: CupertinoColors.systemGrey,
                                            fontSize: 13,
                                            fontFamily: 'Cairo',
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.avgPriceLabelAr,
                                                  style: const TextStyle(
                                                    color: CupertinoColors.systemGrey,
                                                    fontSize: 11,
                                                    fontFamily: 'Cairo',
                                                  ),
                                                ),
                                                Text(
                                                  '${item.price.toLocaleString()} د.ع',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 17,
                                                    color: const Color(0xFFF5A01D),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Builder(
                                              builder: (buttonContext) {
                                                return CupertinoButton(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                  ),
                                                  color: const Color(0xFFF5A01D),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  onPressed: () async {
                                                    if (!GuestGate
                                                        .requireAccount(
                                                      context,
                                                      message:
                                                          'سجّل دخولك لإضافة المنتجات إلى السلة والتسوق.',
                                                    )) {
                                                      return;
                                                    }
                                                    final added =
                                                        appProvider.addToCart(item);
                                                    if (!added) {
                                                      showCupertinoDialog(
                                                        context: context,
                                                        builder: (dialogContext) =>
                                                            CupertinoAlertDialog(
                                                          content: const Text(
                                                            'السلة تحتوي منتجات من قسم آخر (مثل العقارات أو السيارات) لا يمكن دمجها. أكمل طلبك أو افرغ السلة أولاً.',
                                                          ),
                                                          actions: [
                                                            CupertinoDialogAction(
                                                              child:
                                                                  const Text('حسنًا'),
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      dialogContext),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    await _animateAddToCart(
                                                      buttonContext,
                                                    );
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        duration: const Duration(
                                                          milliseconds: 900,
                                                        ),
                                                        content: Text(
                                                          'تمت إضافة ${item.nameAr} إلى السلة',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Text(
                                                    item.actionLabelAr,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                      fontFamily: 'Cairo',
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.4),
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
    return GestureDetector(
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
          width: 34,
          height: 34,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(CupertinoIcons.cart_fill, size: 24),
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
