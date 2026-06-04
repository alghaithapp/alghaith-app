import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../utils/dummy_data.dart';
import '../widgets/app_image.dart';
import 'taxi_request_screen.dart';

/// أنواع المركبات داخل «طلب سيارة» — الصورة تحمل الاسم في التصميم.
class CarRequestHubScreen extends StatelessWidget {
  const CarRequestHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = DummyData.carRequestVehicleTypes;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'طلب سيارة',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ),
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
                    'اختر نوع السيارة المناسب لرحلتك',
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
                    final option = options[index];
                    return _CarRequestTypeCard(
                      option: option,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => TaxiRequestScreen(
                            initialVehicleTypeId: option.id,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: options.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarRequestTypeCard extends StatelessWidget {
  final ServiceCategory option;
  final VoidCallback onTap;

  const _CarRequestTypeCard({
    required this.option,
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
            imageData: option.image,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
