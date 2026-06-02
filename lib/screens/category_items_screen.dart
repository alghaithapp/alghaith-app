import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../core/catalog/marketplace_catalog.dart';
import '../core/catalog/marketplace_router.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';

class CategoryItemsScreen extends StatelessWidget {
  final ServiceCategory category;

  const CategoryItemsScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final def = MarketplaceCatalog.find(category.id);

    if (def == null) {
      return const _UnsupportedCategoryScreen();
    }

    if (def.id == 'real_estate' && appProvider.isMerchant) {
      return MarketplaceRouter.realEstateMerchantScreen();
    }

    return MarketplaceRouter.screenForCategory(def);
  }
}

class _UnsupportedCategoryScreen extends StatelessWidget {
  const _UnsupportedCategoryScreen();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'غير متاح',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
      ),
      child: Center(
        child: Text(
          'هذا القسم غير مدعوم حاليًا',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
  }
}
