import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../../../core/catalog/marketplace_catalog.dart';
import '../../../utils/platform_key.dart';

class HomeCategoriesTab extends StatelessWidget {
  const HomeCategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final categories = MarketplaceCatalog.toggleableHomeCategories;

    return RefreshIndicator(
      onRefresh: () async => provider.refreshHomeCategoriesConfig(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(child: Text('تحكم في ظهور الأقسام الرئيسية للزبائن على أندرويد وآيفون.', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...categories.map((c) => CategoryPlatformToggle(categoryId: c.id, title: c.titleAr)),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class CategoryPlatformToggle extends StatelessWidget {
  final String categoryId;
  final String title;
  const CategoryPlatformToggle({super.key, required this.categoryId, required this.title});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900)),
          Row(
            children: [
              const Text('أندرويد', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Switch.adaptive(
                value: provider.homeCategoryEnabledOnPlatform(categoryId, PlatformKey.android),
                onChanged: (v) => provider.setHomeCategoryPlatformEnabled(categoryId, PlatformKey.android, v),
              ),
              const SizedBox(width: 20),
              const Text('آيفون', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Switch.adaptive(
                value: provider.homeCategoryEnabledOnPlatform(categoryId, PlatformKey.ios),
                onChanged: (v) => provider.setHomeCategoryPlatformEnabled(categoryId, PlatformKey.ios, v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
