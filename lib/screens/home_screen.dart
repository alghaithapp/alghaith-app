import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/catalog/marketplace_catalog.dart';
import '../providers/app_provider.dart';
import 'category_items_screen.dart';
import 'catalog_search_screen.dart';
import '../core/theme/app_colors.dart';
import '../widgets/app_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      provider.refreshHomeCategoriesConfig();
      if (provider.isCustomer || provider.isGuestMode) {
        provider.refreshCustomerCatalog();
        provider.refreshMarketplaceStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final categories = appProvider.visibleHomeCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: GestureDetector(
                onTap: () {
                  final cat = MarketplaceCatalog.find('bazar_ghaith');
                  if (cat != null) {
                    appProvider.setCategory(cat.id);
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) =>
                            CategoryItemsScreen(
                          category: cat.asServiceCategory,
                          hideBack: false,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 200, // تم تقليل الارتفاع بطلب من المستخدم
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(
                      'assets/images/bazar_ghaith_banner.png',
                      fit: BoxFit.fill, // تم التغيير من cover إلى fill لمنع قص الجوانب
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.primary,
                        alignment: Alignment.center,
                        child: const Text(
                          'بازار ومطاعم الغيث',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                // مربّع ليتوافق مع صور الأقسام (768×768) دون قصّ
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cat = categories[index];
                  final isActive = appProvider.selectedCategory == cat.id;
                  return GestureDetector(
                    onTap: () {
                      appProvider.setCategory(cat.id);
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) =>
                              CategoryItemsScreen(
                            category: cat,
                            hideBack: false,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isActive
                              ? AppColors.accent
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: AppImage(
                          imageData: cat.image,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
                childCount: categories.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
