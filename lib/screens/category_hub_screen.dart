import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/catalog/marketplace_catalog.dart';
import '../core/catalog/marketplace_router.dart';
import '../providers/app_provider.dart';
import '../widgets/app_image.dart';

class CategoryHubScreen extends StatefulWidget {
  final MarketplaceCategoryDefinition category;

  const CategoryHubScreen({super.key, required this.category});

  @override
  State<CategoryHubScreen> createState() => _CategoryHubScreenState();
}

class _CategoryHubScreenState extends State<CategoryHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshMarketplaceStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final stats = provider.marketplaceStats?.category(widget.category.id);
    final subs = widget.category.id == 'product'
        ? MarketplaceCatalog.shoppingSubCategories
        : widget.category.subCategories;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.category.hubTitleAr,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => provider.refreshMarketplaceStats(force: true),
          child: const Icon(CupertinoIcons.refresh_thick, size: 22),
        ),
      ),
      child: SafeArea(
        child: subs.isEmpty
            ? _EmptyHubState(
                title: widget.category.hubTitleAr,
                subtitle: widget.category.hubSubtitleAr,
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category.hubSubtitleAr,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                          if (stats != null && stats.totalCount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${stats.totalCount} ${_countLabel(widget.category)}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF5A01D),
                              ),
                            ),
                          ],
                        ],
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
                          final subStats = stats?.subStats(sub.id);
                          final count = subStats?.totalCount ?? 0;
                          return _SubCategoryCard(
                            sub: sub,
                            count: count,
                            onTap: () => MarketplaceRouter.openSubCategory(
                              context,
                              widget.category,
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

  String _countLabel(MarketplaceCategoryDefinition category) {
    if (category.defaultSubBrowseMode == SubCategoryBrowseMode.stores) {
      return 'متجر';
    }
    return 'عرض';
  }
}

class _SubCategoryCard extends StatelessWidget {
  final MarketplaceSubCategory sub;
  final int count;
  final VoidCallback onTap;

  const _SubCategoryCard({
    required this.sub,
    required this.count,
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: AppImage(
                imageData: sub.image,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain, // تغيير ليتوافق مع أسلوب الصفحة الرئيسية
              ),
            ),
            if (count > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A01D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
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
