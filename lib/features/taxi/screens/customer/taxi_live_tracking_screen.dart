import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/app_provider.dart';
import '../../../../utils/chat_navigation.dart';
import '../../providers/taxi_provider.dart';
import '../../services/taxi_places_service.dart';
import '../../utils/taxi_rating_navigation.dart';
import '../../widgets/taxi_cancel_dialog.dart';
import '../../widgets/taxi_driver_contact_buttons.dart';
import '../../widgets/taxi_map_widget.dart';
import '../../widgets/taxi_plate_badge.dart';

/// شاشة التتبع المباشر — خريطة حقيقية + موقع السائق + ETA حي.
class TaxiLiveTrackingScreen extends StatefulWidget {
  const TaxiLiveTrackingScreen({super.key});

  @override
  State<TaxiLiveTrackingScreen> createState() =>
      _TaxiLiveTrackingScreenState();
}

class _TaxiLiveTrackingScreenState extends State<TaxiLiveTrackingScreen> {
  List<LatLng>? _routePoints;
  bool _routeIsApproximate = false;
  bool _routeLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final phone = context.read<AppProvider>().authPhone;
      context.read<TaxiProvider>().startPolling(isDriver: false, phone: phone);
      _loadRoute();
    });
  }

  Future<void> _loadRoute() async {
    final request = context.read<TaxiProvider>().currentRequest;
    if (request == null) {
      if (mounted) setState(() => _routeLoading = false);
      return;
    }

    final from = LatLng(request.pickupLat, request.pickupLng);
    final to = LatLng(request.dropoffLat, request.dropoffLng);
    if (from.latitude == 0 || to.latitude == 0) {
      if (mounted) setState(() => _routeLoading = false);
      return;
    }

    final route = await TaxiPlacesService.fetchDrivingRoute(from, to);
    if (!mounted) return;
    setState(() {
      _routePoints = route.points.isNotEmpty ? route.points : null;
      _routeIsApproximate = route.isApproximate;
      _routeLoading = false;
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
      case 'cancel_requested':
        return 'بانتظار موافقة السائق على الإلغاء';
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

  Future<void> _onCancelTrip() async {
    final provider = context.read<TaxiProvider>();
    final request = provider.currentRequest;
    if (request == null || !request.canCustomerCancel) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            request?.isCancelRequested == true
                ? 'طلب الإلغاء قيد المراجعة من السائق'
                : 'لا يمكن إلغاء الطلب حالياً',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      return;
    }

    final confirmed = await showTaxiCancelDialog(context);
    if (confirmed != true || !mounted) return;

    final ok = await provider.cancelRequest(request.id);
    if (!mounted) return;

    if (ok) {
      final updated = provider.currentRequest;
      final message = updated?.isCancelRequested == true
          ? 'تم إرسال طلب الإلغاء — بانتظار موافقة السائق'
          : 'تم إلغاء الرحلة';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        ),
      );
      if (updated == null || updated.isCancelled) {
        Navigator.of(context).pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'تعذر إلغاء الطلب',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Consumer<TaxiProvider>(
          builder: (context, provider, _) {
            final request = provider.currentRequest;
            final pendingRating = provider.tripAwaitingRating;

            if (pendingRating != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                TaxiRatingNavigation.openIfNeeded(context, pendingRating);
              });
            }

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
                    routePoints: _routePoints,
                    driverLocation: driverLoc,
                    zoom: 14,
                  ),
                ),

                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
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
                            mainAxisAlignment: MainAxisAlignment.center,
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
                              Flexible(
                                child: Text(
                                  _statusLabel(request?.statusKey ?? ''),
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (request != null && request.hasLiveEta)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 64,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schedule, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'وصول السائق خلال ${request.liveEtaLabelAr}',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (request != null && !request.hasDriverLocation)
                  Positioned(
                    top: MediaQuery.of(context).padding.top +
                        (request.hasLiveEta ? 112 : 64),
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

                if (_routeIsApproximate && !_routeLoading)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 108,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: const Text(
                        'المسار تقريبي — تعذّر جلب مسار القيادة الدقيق',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.black87,
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
                            if (request?.driverPhone?.trim().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 12),
                              TaxiDriverContactButtons(
                                driverPhone: request?.driverPhone,
                                driverName: request?.driverName ?? 'السائق',
                              ),
                            ],
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
                            if (request?.canCustomerCancel == true) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _onCancelTrip,
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text(
                                    'إلغاء الرحلة',
                                    style: TextStyle(fontFamily: 'Cairo'),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
