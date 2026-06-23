import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/taxi_request.dart';
import 'taxi_map_widget.dart';
import '../../../core/theme/app_colors.dart';

/// خريطة تتبع السائق داخل بطاقة الطلب الحالي.
class TaxiOrderTrackingMap extends StatelessWidget {
  final TaxiRequest request;
  final double height;
  final VoidCallback? onExpand;

  const TaxiOrderTrackingMap({
    super.key,
    required this.request,
    this.height = 220,
    this.onExpand,
  });

  String get _trackingLabel {
    switch (request.statusKey) {
      case 'accepted':
      case 'on_way':
        return 'السائق في الطريق إليك';
      case 'arrived':
        return 'السائق وصل إلى موقعك';
      case 'picked_up':
        return 'أنت في الرحلة الآن';
      default:
        return 'تتبع السائق مباشرة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = request.pickupLat != 0 && request.pickupLng != 0
        ? LatLng(request.pickupLat, request.pickupLng)
        : null;
    final dropoff = request.dropoffLat != 0 && request.dropoffLng != 0
        ? LatLng(request.dropoffLat, request.dropoffLng)
        : null;
    final driverLoc = request.hasDriverLocation
        ? LatLng(request.driverLat!, request.driverLng!)
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.map_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _trackingLabel,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onExpand != null)
                  TextButton(
                    onPressed: onExpand,
                    child: const Text(
                      'تكبير',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  TaxiMapWidget(
                    pickupLocation: pickup,
                    dropoffLocation: dropoff,
                    driverLocation: driverLoc,
                    zoom: 14,
                    height: height,
                  ),
                  if (!request.hasDriverLocation)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'جاري تحديث موقع السائق على الخريطة...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: const [
                _MapLegendDot(color: Colors.green, label: 'السائق'),
                SizedBox(width: 14),
                _MapLegendDot(color: Colors.blue, label: 'الانطلاق'),
                SizedBox(width: 14),
                _MapLegendDot(color: Colors.orange, label: 'الوجهة'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _MapLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
