import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../screens/catalog_products_screen.dart';
import '../../screens/category_hub_screen.dart';
import '../../screens/offers_catalog_screen.dart';
import '../../screens/professionals_directory_screen.dart';
import '../../screens/real_estate_form_screen.dart';
import '../../screens/real_estate_listings_screen.dart';
import '../../screens/shopping_stores_screen.dart';
import '../../screens/taxi_request_screen.dart';
import 'marketplace_catalog.dart';

class MarketplaceRouter {
  const MarketplaceRouter._();

  static Widget screenForCategory(MarketplaceCategoryDefinition def) {
    switch (def.entryMode) {
      case CategoryEntryMode.directStores:
        return ShoppingStoresScreen(
          storeKind: def.id == 'restaurant'
              ? MerchantStoreKind.restaurant
              : MerchantStoreKind.shopping,
          serviceId: def.apiServiceId,
          productCategory: def.apiProductCategory,
          titleAr: def.storeTitleAr,
          subtitleAr: def.storeSubtitleAr,
          showCuisineFilters: def.showCuisineFilters,
        );
      case CategoryEntryMode.offers:
        return const OffersCatalogScreen();
      case CategoryEntryMode.realEstate:
        return const RealEstateListingsScreen();
      case CategoryEntryMode.professionals:
        return CategoryHubScreen(category: def);
      case CategoryEntryMode.cars:
        return CategoryHubScreen(category: def);
      case CategoryEntryMode.subCategoryHub:
      case CategoryEntryMode.directCatalog:
        if (def.subCategories.isEmpty &&
            def.entryMode == CategoryEntryMode.directCatalog) {
          return CatalogProductsScreen(
            category: def.apiProductCategory,
            titleAr: def.titleAr,
            subtitleAr: def.hubSubtitleAr,
          );
        }
        return CategoryHubScreen(category: def);
    }
  }

  static Widget realEstateMerchantScreen() {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'العقارات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      child: SafeArea(
        child: Builder(
          builder: (context) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _RealEstateActionTile(
                  title: 'شراء عقار',
                  subtitle: 'استعرض عروض العقارات المعروضة للشراء',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => const RealEstateListingsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _RealEstateActionTile(
                  title: 'بيع عقار',
                  subtitle: 'اعرض عقارك للبيع الآن',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) =>
                          const RealEstateFormScreen(mode: 'sell'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _RealEstateActionTile(
                  title: 'استئجار عقار',
                  subtitle: 'ابحث عن عقار مناسب للإيجار',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) =>
                          const RealEstateFormScreen(mode: 'rent'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static void openSubCategory(
    BuildContext context,
    MarketplaceCategoryDefinition category,
    MarketplaceSubCategory sub,
  ) {
    if (category.id == 'cars') {
      if (sub.id == 'taxi_request') {
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => const TaxiRequestScreen()),
        );
        return;
      }
      if (sub.id == 'car_request') {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => const _ComingSoonFeatureScreen(
              title: 'طلب سيارة',
              subtitle: 'قريبًا',
            ),
          ),
        );
        return;
      }
    }

    if (category.id == 'professionals') {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => ProfessionalsDirectoryScreen(profession: sub),
        ),
      );
      return;
    }

    final mode = sub.browseMode;

    if (mode == SubCategoryBrowseMode.stores) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => ShoppingStoresScreen(
            subCategory: sub,
            storeKind: category.id == 'restaurant'
                ? MerchantStoreKind.restaurant
                : MerchantStoreKind.shopping,
            serviceId: category.apiServiceId,
            productCategory: category.apiProductCategory,
            titleAr: sub.titleAr,
            subtitleAr: category.storeSubtitleAr,
            showCuisineFilters: category.showCuisineFilters,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => CatalogProductsScreen(
          category: category.apiProductCategory,
          subCategoryId: sub.id,
          titleAr: sub.titleAr,
          subtitleAr: category.hubSubtitleAr,
        ),
      ),
    );
  }

  static void openRealEstateMerchantHub(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => realEstateMerchantScreen()),
    );
  }
}

class _RealEstateActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RealEstateActionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
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
    );
  }
}

class _ComingSoonFeatureScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ComingSoonFeatureScreen({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.time,
              size: 64,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
