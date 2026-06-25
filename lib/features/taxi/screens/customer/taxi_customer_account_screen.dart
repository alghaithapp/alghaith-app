import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/app_provider.dart';
import '../../models/taxi_favorite_place.dart';
import '../../models/taxi_saved_place_use.dart';
import '../../providers/taxi_provider.dart';
import 'taxi_saved_places_screen.dart';

/// حساب الزبون داخل خدمة التكسي — مستقل عن حساب التطبيق العام.
class TaxiCustomerAccountScreen extends StatefulWidget {
  final void Function(TaxiFavoritePlace place, TaxiSavedPlaceField field)?
      onUseSavedPlace;

  const TaxiCustomerAccountScreen({super.key, this.onUseSavedPlace});

  @override
  State<TaxiCustomerAccountScreen> createState() =>
      _TaxiCustomerAccountScreenState();
}

class _TaxiCustomerAccountScreenState extends State<TaxiCustomerAccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaxiProvider>().loadFavoritePlaces();
    });
  }

  void _openSavedPlaces() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => TaxiSavedPlacesScreen(
          onPlaceSelected: (place, field) {
            Navigator.pop(ctx);
            widget.onUseSavedPlace?.call(place, field);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final places = context.watch<TaxiProvider>().favoritePlaces;
    final name = app.customerName.trim().isNotEmpty
        ? app.customerName.trim()
        : 'زبون التكسي';
    final phone = app.customerPhone.trim();
    final savedCount = places.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0] : 'ز',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'حسابك في خدمة طلب التكسي',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _openSavedPlaces,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.bookmark_added_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'عناويني المحفوظة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          savedCount == 0
                              ? 'أضف عنوان المنزل والعمل وأماكن أخرى'
                              : '$savedCount ${savedCount == 1 ? 'عنوان محفوظ' : 'عناوين محفوظة'}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'احفظ عناوينك المعتادة، وعند اختيار أي عنوان حدّد هل تريده كنقطة انطلاق أم وجهة — ثم أكمل الحقل الآخر في شاشة الطلب.',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
