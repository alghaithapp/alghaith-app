import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' as latlong2;

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/app_provider.dart';
import '../../models/taxi_request.dart';
import '../../providers/taxi_provider.dart';
import '../../widgets/taxi_type_image.dart';
import '../../utils/taxi_driver_request_actions.dart';
import '../../widgets/taxi_map_widget.dart';

/// الشاشة الرئيسية للسائق — تعرض خريطة Google Maps حقيقية، الإحصائيات، وطلبات التكسي الواردة
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final taxiProvider = context.watch<TaxiProvider>();
    final pendingRequests = taxiProvider.incomingRequests;
    final completedRequests = appProvider.visibleTaxiCompletedRequests;
    final todayTrips = completedRequests.length;
    final todayEarnings = completedRequests.fold<int>(0, (sum, r) => sum + r.fare);
    final driverProfile = appProvider.driverProfile ?? const {};
    final driverName = (driverProfile['name'] as String?)?.trim() ?? 'السائق';

    latlong2.LatLng? pickup;
    if (pendingRequests.isNotEmpty) {
      final r = pendingRequests.first;
      pickup = latlong2.LatLng(r.pickupLat, r.pickupLng);
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                TaxiMapWidget(
                  pickupLocation: pickup,
                  driverLocation: null,
                  zoom: 13.0,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: _buildAppBar(context, appProvider, driverName),
                  ),
                ),
                Positioned(
                  top: 112,
                  left: 20,
                  right: 20,
                  child: _buildStatsWidget(todayTrips, todayEarnings),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: _buildRecenterFab(),
                ),
              ],
            ),
          ),
          if (pendingRequests.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _buildNewRequestCard(
                  context,
                  appProvider,
                  taxiProvider,
                  pendingRequests.first,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppProvider provider, String driverName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // اسم التطبيق والسائق
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تكسي الغيث',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                    color: Colors.black,
                  ),
                ),
                Text(
                  'مرحباً، $driverName',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Cairo',
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // مؤشر الاتصال (دائماً متصل للسائق المعتمد)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'متصل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // صورة الملف الشخصي
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.person, color: AppColors.accent, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsWidget(int todayTrips, int todayEarnings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // رحلات اليوم
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'رحلات اليوم',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Cairo',
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$todayTrips',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 32, width: 1, color: Colors.grey.shade200),
          // أرباح اليوم
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'أرباح اليوم',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Cairo',
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$todayEarnings د.ع',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewRequestCard(
    BuildContext context,
    AppProvider appProvider,
    TaxiProvider taxiProvider,
    TaxiRequest request,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          top: BorderSide(color: AppColors.accent, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس البطاقة: إشعار + مسافة
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.accent,
                  size: 28,
                ),
                const SizedBox(width: 8),
                const Text(
                  'طلب جديد',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                TaxiTypeImage(
                  type: request.taxiType,
                  width: 36,
                  height: 36,
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    request.rideTypeAr,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Cairo',
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // نقاط الانطلاق والوصول
            Row(
              children: [
                // خط المسار
                Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 28,
                      color: Colors.grey.shade300,
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // العناوين
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'نقطة الانطلاق',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Cairo',
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        request.pickupAddressAr,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'نقطة الوصول',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Cairo',
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        request.dropoffAddressAr,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // أجرة + نوع الرحلة
            Row(
              children: [
                Text(
                  'الأجرة المقدرة (${request.rideTypeAr})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Cairo',
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Text(
                    '${request.fare} د.ع',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // أزرار رفض / قبول
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRejecting || _isAccepting
                        ? null
                        : () async {
                            setState(() => _isRejecting = true);
                            await handleDriverRejectRequest(context, request);
                            if (mounted) {
                              setState(() => _isRejecting = false);
                            }
                          },
                    icon: _isRejecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red,
                            ),
                          )
                        : const Icon(Icons.close, color: Colors.red),
                    label: const Text(
                      'رفض',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.08),
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRejecting || _isAccepting
                        ? null
                        : () async {
                            setState(() => _isAccepting = true);
                            await handleDriverAcceptRequest(context, request);
                            if (mounted) {
                              setState(() => _isAccepting = false);
                            }
                          },
                    icon: _isAccepting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'قبول',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecenterFab() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.my_location_rounded,
        color: Colors.black87,
        size: 22,
      ),
    );
  }

}


