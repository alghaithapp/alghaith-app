import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../screens/catalog_products_screen.dart';
import '../../screens/category_hub_screen.dart';
import '../../screens/offers_catalog_screen.dart';
import '../../screens/eden_printing_screen.dart';
import '../../screens/professionals_directory_screen.dart';
import '../../screens/real_estate_deal_hub_screen.dart';
import '../../screens/shopping_stores_screen.dart';
import '../../screens/car_request_hub_screen.dart';
import '../../screens/taxi_request_screen.dart';
import 'marketplace_catalog.dart';

class MarketplaceRouter {
  const MarketplaceRouter._();

  static Widget screenForCategory(MarketplaceCategoryDefinition def, {bool hideBack = true}) {
    if (def.id == 'eden_printing') {
      return const EdenPrintingScreen();
    }
    switch (def.entryMode) {
      case CategoryEntryMode.directStores:
        return ShoppingStoresScreen(
          storeKind: def.id == 'restaurant'
              ? MerchantStoreKind.restaurant
              : MerchantStoreKind.shopping,
          serviceId: def.apiServiceId,
          productCategory: def.apiProductCategory,
          marketplaceCategory: def.id,
          titleAr: def.storeTitleAr,
          subtitleAr: def.storeSubtitleAr,
          showCuisineFilters: def.showCuisineFilters,
          hideBack: hideBack,
        );
      case CategoryEntryMode.offers:
        return OffersCatalogScreen(hideBack: hideBack);
      case CategoryEntryMode.realEstate:
        return RealEstateDealHubScreen(hideBack: hideBack);
      case CategoryEntryMode.professionals:
        return CategoryHubScreen(category: def, hideBack: hideBack);
      case CategoryEntryMode.cars:
        return CategoryHubScreen(category: def, hideBack: hideBack);
      case CategoryEntryMode.subCategoryHub:
      case CategoryEntryMode.directCatalog:
        if (def.subCategories.isEmpty &&
            def.entryMode == CategoryEntryMode.directCatalog) {
          return CatalogProductsScreen(
            category: def.apiProductCategory,
            titleAr: def.titleAr,
            subtitleAr: def.hubSubtitleAr,
            hideBack: hideBack,
          );
        }
        return CategoryHubScreen(category: def, hideBack: hideBack);
    }
  }

  static Widget realEstateMerchantScreen() {
    return const RealEstateDealHubScreen();
  }

  static void openSubCategory(
    BuildContext context,
    MarketplaceCategoryDefinition category,
    MarketplaceSubCategory sub,
  ) {
    if (category.id == 'cars') {
      if (sub.id == 'taxi_request') {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => const TaxiRequestScreen(),
          ),
        );
        return;
      }
      if (sub.id == 'car_request') {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => const CarRequestHubScreen(),
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
            marketplaceCategory: category.id,
            titleAr: sub.titleAr,
            subtitleAr: category.storeSubtitleAr,
            showCuisineFilters: category.showCuisineFilters,
            hideBack: false,
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
          hideBack: false,
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
