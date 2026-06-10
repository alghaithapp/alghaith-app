import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../utils/dummy_data.dart';
import '../widgets/app_image.dart';
import '../widgets/service_navigation_buttons.dart';
import 'real_estate_form_screen.dart';
import 'real_estate_listings_screen.dart';

/// المستوى الثاني: أنواع العقار (دار، أرض، …) حسب شراء/بيع/إيجار.
class RealEstateTypeHubScreen extends StatelessWidget {
  final String dealId;
  final String dealTitleAr;

  const RealEstateTypeHubScreen({
    super.key,
    required this.dealId,
    required this.dealTitleAr,
  });

  String get _subtitle {
    switch (dealId) {
      case 'buy':
        return 'اختر نوع العقار الذي تبحث عن شرائه';
      case 'sell':
        return 'اختر نوع العقار الذي تريد بيعه';
      case 'rent':
        return 'اختر نوع العقار الذي تريد استئجاره';
      default:
        return 'اختر نوع العقار';
    }
  }

  void _openType(BuildContext context, ServiceCategory type) {
    if (dealId == 'sell') {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => RealEstateFormScreen(
            mode: 'sell',
            initialSubCategoryId: type.id,
          ),
        ),
      );
      return;
    }

    final listingMode = dealId == 'buy' ? 'sell' : 'rent';
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => RealEstateListingsScreen(
          subCategoryId: type.id,
          listingMode: listingMode,
          titleAr: '${dealTitleAr.trim()} — ${type.titleAr}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = DummyData.realEstateSubCategories;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: ServiceNavigationBar(title: dealTitleAr),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _subtitle,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.88,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final type = types[index];
                    return _TypeCard(
                      type: type,
                      onTap: () => _openType(context, type),
                    );
                  },
                  childCount: types.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final ServiceCategory type;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AppImage(
            imageData: type.image,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
