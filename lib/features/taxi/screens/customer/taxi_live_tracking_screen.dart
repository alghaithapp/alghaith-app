import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../providers/taxi_provider.dart';
import '../../widgets/taxi_map_widget.dart';
import '../../widgets/taxi_plate_badge.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../utils/chat_navigation.dart';

/// شاشة التتبع المباشر — خريطة حقيقية + موقع السائق + بيانات الرحلة.
class TaxiLiveTrackingScreen extends StatefulWidget {
  const TaxiLiveTrackingScreen({super.key});

  @override
  State<TaxiLiveTrackingScreen> createState() =>
      _TaxiLiveTrackingScreenState();
}

class _TaxiLiveTrackingScreenState extends State<TaxiLiveTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TaxiProvider>().startPolling(isDriver: false);
    });
  }

  @override
  void dispose() {
    context.read<TaxiProvider>().stopPolling();
    super.dispose();
  }

  String _statusLabel(String statusKey) {
    switch (statusKey) {
      case 'accepted':
      case 'on_way':
        return 'السائق في الطريق إليك';
      case 'arrived':
        return 'السائق وصل إلى موقعك';
      case 'picked_up':
        return 'أنت في الرحلة الآن';
      default:
        return 'جاري تتبع الرحلة';
    }
  }

  Future<void> _onMessageDriver(
    String? requestId,
    String? driverName,
    String? driverPhone,
  ) async {
    final id = requestId?.trim() ?? '';
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن فتح المحادثة حالياً',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }
    await ChatNavigation.openTaxiChat(
      context,
      requestId: id,
      otherPartyName: driverName?.trim().isNotEmpty == true
          ? driverName!.trim()
          : 'السائق',
      receiverPhone: driverPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Consumer<TaxiProvider>(
          builder: (context, provider, _) {
            final request = provider.currentRequest;
            final pickup = request != null &&
                    request.pickupLat != 0 &&
                    request.pickupLng != 0
                ? LatLng(request.pickupLat, request.pickupLng)
                : null;
            final dropoff = request != null &&
                    request.dropoffLat != 0 &&
                    request.dropoffLng != 0
                ? LatLng(request.dropoffLat, request.dropoffLng)
                : null;
            final driverLoc = request?.hasDriverLocation == true
                ? LatLng(request!.driverLat!, request.driverLng!)
                : null;

            return Stack(
              children: [
                Positioned.fill(
                  child: TaxiMapWidget(
                    pickupLocation: pickup,
                    dropoffLocation: dropoff,
                    driverLocation: driverLoc,
                    zoom: 14,
                  ),
                ),

                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _statusLabel(request?.statusKey ?? ''),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (request != null && !request.hasDriverLocation)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 64,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        'جاري تحديث موقع السائق...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 30,
                          offset: Offset(0, -8),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCFC4C5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: const Color(0xFFEEEEEE),
                                  child: Text(
                                    (request?.driverName?.isNotEmpty == true)
                                        ? request!.driverName![0]
                                        : 'س',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        request?.driverName ?? 'السائق',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        request?.taxiTypeLabelAr ?? '',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Material(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    onTap: () => _onMessageDriver(
                                      request?.id,
                                      request?.driverName,
                                      request?.driverPhone,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    child: const SizedBox(
                                      width: 52,
                                      height: 52,
                                      child: Icon(
                                        Icons.chat_bubble_outline,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F3F3),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE2E2E2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      request?.vehicleModelDisplay ?? 'مركبة',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TaxiPlateBadge(
                                    plateNumber:
                                        request?.plateNumberDisplay ?? '',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  'الأجرة المتوقعة',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${request?.fare ?? 0} د.ع',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
