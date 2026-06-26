import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../utils/helpers.dart';
import '../models/taxi_request.dart';

enum TaxiNavigationTarget { pickup, dropoff }

Future<TaxiNavigationTarget?> showTaxiNavigationTargetSheet(
  BuildContext context, {
  required TaxiRequest request,
}) {
  final hasPickup = request.pickupLat.abs() > 0.001 && request.pickupLng.abs() > 0.001;
  final hasDropoff = request.dropoffLat.abs() > 0.001 && request.dropoffLng.abs() > 0.001;

  if (!hasPickup && !hasDropoff) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'إحداثيات المسار غير متوفرة',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
    return Future.value(null);
  }

  if (hasPickup && !hasDropoff) {
    return Future.value(TaxiNavigationTarget.pickup);
  }
  if (hasDropoff && !hasPickup) {
    return Future.value(TaxiNavigationTarget.dropoff);
  }

  return showModalBottomSheet<TaxiNavigationTarget>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'اختر وجهة المسار',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _NavTargetTile(
            icon: Icons.person_pin_circle_rounded,
            title: 'إلى نقطة انطلاق الزبون',
            subtitle: request.pickupAddress,
            onTap: () => Navigator.pop(ctx, TaxiNavigationTarget.pickup),
          ),
          const SizedBox(height: 10),
          _NavTargetTile(
            icon: Icons.flag_rounded,
            title: 'إلى وجهة الزبون',
            subtitle: request.dropoffAddress,
            onTap: () => Navigator.pop(ctx, TaxiNavigationTarget.dropoff),
          ),
        ],
      ),
    ),
  );
}

Future<void> openTaxiNavigation(
  BuildContext context, {
  required TaxiRequest request,
}) async {
  final target = await showTaxiNavigationTargetSheet(context, request: request);
  if (target == null || !context.mounted) return;

  final LatLng? coords = switch (target) {
    TaxiNavigationTarget.pickup =>
      request.pickupLat.abs() > 0.001 ? LatLng(request.pickupLat, request.pickupLng) : null,
    TaxiNavigationTarget.dropoff =>
      request.dropoffLat.abs() > 0.001 ? LatLng(request.dropoffLat, request.dropoffLng) : null,
  };

  if (coords == null) return;
  await AppHelpers.openExternalMapNavigation(
    context: context,
    latitude: coords.latitude,
    longitude: coords.longitude,
  );
}

class _NavTargetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTargetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
