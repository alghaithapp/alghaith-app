import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../utils/dummy_data.dart';
import '../widgets/app_image.dart';
import '../widgets/service_navigation_buttons.dart';
import 'real_estate_type_hub_screen.dart';

/// المستوى الأول: شراء — بيع — إيجار.
class RealEstateDealHubScreen extends StatelessWidget {
  const RealEstateDealHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deals = DummyData.realEstateDealOptions;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const ServiceNavigationBar(title: 'العقارات'),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'اختر نوع العملية',
                    style: TextStyle(
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
                    final deal = deals[index];
                    return _DealCard(
                      deal: deal,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => RealEstateTypeHubScreen(
                            dealId: deal.id,
                            dealTitleAr: deal.titleAr,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: deals.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  final ServiceCategory deal;
  final VoidCallback onTap;

  const _DealCard({
    required this.deal,
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
            imageData: deal.image,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
