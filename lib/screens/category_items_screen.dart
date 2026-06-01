import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../utils/dummy_data.dart';
import '../utils/extensions.dart';
import '../utils/helpers.dart';
import '../widgets/app_image.dart';
import 'professionals_directory_screen.dart';
import 'real_estate_form_screen.dart';
import 'real_estate_listings_screen.dart';
import 'restaurant_menu_screen.dart';
import 'shopping_stores_screen.dart';
import 'sub_category_items_screen.dart';

class CategoryItemsScreen extends StatelessWidget {
  final ServiceCategory category;

  const CategoryItemsScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isAr = appProvider.lang == 'ar';

    switch (category.id) {
      case 'product':
        return _buildSubCategoryGallery(
          context,
          isAr: isAr,
          titleAr: 'أقسام التسوق',
          titleEn: 'Shopping Categories',
          categories: DummyData.shoppingSubCategories,
          onTap: (sub) => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => SubCategoryItemsScreen(subCategory: sub),
            ),
          ),
          fallbackColor: Colors.orange,
          fallbackIcon: CupertinoIcons.bag_fill,
        );
      case 'cars':
        return _buildCarsSubCategories(context, isAr);
      case 'tourism':
        return _buildSubCategoryGallery(
          context,
          isAr: isAr,
          titleAr: 'السياحة والسفر',
          titleEn: 'Tourism & Travel',
          categories: DummyData.tourismSubCategories,
          onTap: (sub) => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => SubCategoryItemsScreen(subCategory: sub),
            ),
          ),
          fallbackColor: Colors.teal,
          fallbackIconBuilder: (sub) {
            if (sub.id == 'groups') return CupertinoIcons.group_solid;
            if (sub.id == 'hotels') return CupertinoIcons.house_alt_fill;
            return CupertinoIcons.airplane;
          },
        );
      case 'beauty':
        return _buildSubCategoryGallery(
          context,
          isAr: isAr,
          titleAr: 'الصحة والجمال',
          titleEn: 'Health & Beauty',
          categories: DummyData.healthSubCategories,
          onTap: (sub) => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => SubCategoryItemsScreen(subCategory: sub),
            ),
          ),
          fallbackColor: Colors.redAccent,
          fallbackIconBuilder: (sub) {
            if (sub.id == 'doctors') {
              return CupertinoIcons.person_badge_plus_fill;
            }
            if (sub.id == 'pharmacies') {
              return CupertinoIcons.capsule_fill;
            }
            return CupertinoIcons.house_fill;
          },
        );
      case 'real_estate':
        return appProvider.isMerchant
            ? _buildRealEstateInitial(context, isAr)
            : const RealEstateListingsScreen();
      case 'global_shopping':
        return _buildSubCategoryGallery(
          context,
          isAr: isAr,
          titleAr: 'التسوق العالمي',
          titleEn: 'Global Shopping',
          categories: DummyData.globalShoppingSubCategories,
          onTap: (sub) => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => ShoppingStoresScreen(subCategory: sub),
            ),
          ),
          fallbackColor: Colors.purple,
          fallbackIcon: CupertinoIcons.globe,
        );
      case 'professionals':
        return _buildSubCategoryGallery(
          context,
          isAr: isAr,
          titleAr: 'المهنيين',
          titleEn: 'Professionals',
          categories: DummyData.professionalsSubCategories,
          onTap: (sub) => Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) =>
                  ProfessionalsDirectoryScreen(profession: sub),
            ),
          ),
          fallbackColor: Colors.brown,
          fallbackIcon: CupertinoIcons.person_2_fill,
        );
      default:
        return _buildCategoryItems(context, appProvider, isAr);
    }
  }

  Widget _buildCategoryItems(
    BuildContext context,
    AppProvider appProvider,
    bool isAr,
  ) {
    final filteredItems = appProvider.items
        .where((item) => item.category == category.id)
        .toList();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? category.titleAr : category.titleEn,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        previousPageTitle: isAr ? 'الرئيسية' : 'Home',
      ),
      child: SafeArea(
        child: filteredItems.isEmpty
            ? _buildEmptyState(
                isAr ? 'لا توجد نتائج حاليًا' : 'No items found',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return GestureDetector(
                    onTap: category.id == 'restaurant'
                        ? () => Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) =>
                                    RestaurantMenuScreen(restaurant: item),
                              ),
                            )
                        : null,
                    child: Container(
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
                                        isAr ? item.nameAr : item.nameEn,
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
                                    const SizedBox(width: 8),
                                    if (item.rating != null)
                                      Row(
                                        children: [
                                          const Icon(
                                            CupertinoIcons.star_fill,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${item.rating}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isAr
                                      ? item.descriptionAr
                                      : item.descriptionEn,
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
                                          isAr
                                              ? item.avgPriceLabelAr
                                              : item.avgPriceLabelEn,
                                          style: const TextStyle(
                                            color:
                                                CupertinoColors.systemGrey,
                                            fontSize: 11,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                        Text(
                                          "${item.price.toLocaleString()} د.ع",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 17,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    CupertinoButton(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                      onPressed: category.id == 'restaurant'
                                          ? () => Navigator.of(context).push(
                                                CupertinoPageRoute(
                                                  builder: (context) =>
                                                      RestaurantMenuScreen(
                                                    restaurant: item,
                                                  ),
                                                ),
                                              )
                                          : (category.id == 'real_estate' ||
                                                  category.id == 'cars' ||
                                                  category.id ==
                                                      'professionals'
                                              ? () => AppHelpers.launchWhatsApp(
                                                    AppHelpers
                                                        .supportWhatsAppNumber,
                                                    "مرحبًا، أستفسر عن: ${item.nameAr}",
                                                  )
                                              : () {
                                                  appProvider.addToCart(item);
                                                  showCupertinoDialog(
                                                    context: context,
                                                    builder: (context) =>
                                                        CupertinoAlertDialog(
                                                      title: Text(isAr
                                                          ? 'تمت الإضافة'
                                                          : 'Added'),
                                                      content: Text(isAr
                                                          ? 'تمت إضافة المنتج إلى السلة بنجاح'
                                                          : 'Item added to cart successfully'),
                                                      actions: [
                                                        CupertinoDialogAction(
                                                          child: Text(
                                                            isAr
                                                                ? 'حسنًا'
                                                                : 'OK',
                                                          ),
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                      child: Text(
                                        category.id == 'restaurant'
                                            ? (isAr
                                                ? 'عرض المنيو'
                                                : 'View Menu')
                                            : (isAr
                                                ? item.actionLabelAr
                                                : item.actionLabelEn),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'Cairo',
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
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSubCategoryGallery(
    BuildContext context, {
    required bool isAr,
    required String titleAr,
    required String titleEn,
    required List<ServiceCategory> categories,
    required ValueChanged<ServiceCategory> onTap,
    required Color fallbackColor,
    IconData? fallbackIcon,
    IconData Function(ServiceCategory sub)? fallbackIconBuilder,
  }) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? titleAr : titleEn,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      child: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final sub = categories[index];
            return GestureDetector(
              onTap: () => onTap(sub),
              child: Container(
                height: 160,
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
                child: AppImage(
                  imageData: sub.image,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRealEstateInitial(BuildContext context, bool isAr) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? 'العقارات' : 'Real Estate',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRealEstateMainCard(
              context,
              isAr: isAr,
              title: isAr ? 'شراء عقار' : 'Buy Property',
              subtitle: isAr
                  ? 'استعرض عروض العقارات المعروضة للشراء'
                  : 'Browse properties available for purchase',
              imagePath: 'assets/images/re_buy.png',
              icon: CupertinoIcons.house_fill,
              color: Colors.green,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => const RealEstateListingsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildRealEstateMainCard(
              context,
              isAr: isAr,
              title: isAr ? 'بيع عقار' : 'Sell Property',
              subtitle: isAr
                  ? 'اعرض عقارك للبيع الآن'
                  : 'List your property for sale',
              imagePath: 'assets/images/re_sell.png',
              icon: CupertinoIcons.square_pencil,
              color: Colors.blueAccent,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) =>
                      const RealEstateFormScreen(mode: 'sell'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildRealEstateMainCard(
              context,
              isAr: isAr,
              title: isAr ? 'استئجار عقار' : 'Rent Property',
              subtitle: isAr
                  ? 'ابحث عن عقار مناسب للإيجار'
                  : 'Find a property to rent',
              imagePath: 'assets/images/re_rent.png',
              icon: CupertinoIcons.calendar,
              color: Colors.orangeAccent,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) =>
                      const RealEstateFormScreen(mode: 'rent'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealEstateMainCard(
    BuildContext context, {
    required bool isAr,
    required String title,
    required String subtitle,
    required String imagePath,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: AppImage(
                imageData: imagePath,
                height: 170,
                width: double.infinity,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_left, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarsSubCategories(BuildContext context, bool isAr) {
    return _buildSubCategoryGallery(
      context,
      isAr: isAr,
      titleAr: 'قسم السيارات',
      titleEn: 'Cars Section',
      categories: DummyData.carsSubCategories,
      onTap: (sub) {
        if (sub.id == 'taxi_request') {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => const _ComingSoonFeatureScreen(
                titleAr: 'طلب تكسي',
                titleEn: 'Taxi Request',
                subtitleAr: 'قريبًا',
                subtitleEn: 'Coming soon',
              ),
            ),
          );
          return;
        }

        if (sub.id == 'car_request') {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => const _ComingSoonFeatureScreen(
                titleAr: 'طلب سيارة',
                titleEn: 'Request Car',
                subtitleAr: 'قريبًا',
                subtitleEn: 'Coming soon',
              ),
            ),
          );
          return;
        }

        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => SubCategoryItemsScreen(subCategory: sub),
          ),
        );
      },
      fallbackColor: Colors.blue,
      fallbackIcon: CupertinoIcons.car_detailed,
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
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
            message,
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonFeatureScreen extends StatelessWidget {
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;

  const _ComingSoonFeatureScreen({
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Directionality.of(context) == TextDirection.rtl;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isAr ? titleAr : titleEn,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.construction_rounded,
                  size: 64,
                  color: Colors.deepOrange,
                ),
                const SizedBox(height: 14),
                Text(
                  isAr ? titleAr : titleEn,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isAr ? subtitleAr : subtitleEn,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontFamily: 'Cairo',
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
