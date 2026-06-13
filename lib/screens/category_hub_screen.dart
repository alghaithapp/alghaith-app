import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/catalog/marketplace_catalog.dart';
import '../core/catalog/marketplace_router.dart';
import '../widgets/app_image.dart';
import '../widgets/service_navigation_buttons.dart';

class CategoryHubScreen extends StatelessWidget {
  final MarketplaceCategoryDefinition category;

  const CategoryHubScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final subs = category.id == 'product'
        ? MarketplaceCatalog.shoppingSubCategories
        : category.subCategories;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: ServiceNavigationBar(
        title: category.hubTitleAr,
      ),
      child: SafeArea(
        child: subs.isEmpty
            ? _EmptyHubState(
                title: category.hubTitleAr,
                subtitle: category.hubSubtitleAr,
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Text(
                        category.hubSubtitleAr,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final sub = subs[index];
                          return _SubCategoryCard(
                            sub: sub,
                            onTap: () => MarketplaceRouter.openSubCategory(
                              context,
                              category,
                              sub,
                            ),
                          );
                        },
                        childCount: subs.length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SubCategoryCard extends StatelessWidget {
  final MarketplaceSubCategory sub;
  final VoidCallback onTap;

  const _SubCategoryCard({
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
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
            imageData: sub.image,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _EmptyHubState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyHubState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.square_grid_2x2,
              size: 56,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
