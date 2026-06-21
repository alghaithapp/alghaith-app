import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/taxi_provider.dart';
import '../../models/taxi_request.dart';

/// شاشة طلبات السائق — تعرض الطلبات الواردة كقائمة
/// إذا تم تمرير [request] تظهر تفاصيل طلب محدد، وإلا تعرض قائمة بجميع الطلبات المعلقة.
class DriverRequestScreen extends StatelessWidget {
  final TaxiRequest? request;

  const DriverRequestScreen({super.key, this.request});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaxiProvider>();

    // إذا كان هناك طلب محدد (مثلاً من ضغطة على عنصر) → اعرض التفاصيل
    if (request != null) {
      return _RequestDetailView(
        request: request!,
        provider: provider,
      );
    }

    // وضع التاب — اعرض قائمة الطلبات المعلقة من TaxiProvider
    final pending = provider.pendingRequests;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text(
          'الطلبات',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: pending.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              itemBuilder: (context, index) => _buildRequestCard(
                context, provider, pending[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'لا توجد طلبات حالياً',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'سيتم إعلامك عند وصول طلب جديد',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    TaxiProvider provider,
    TaxiRequest req,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DriverRequestScreen(request: req),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: const Border(
            top: BorderSide(color: AppColors.accent, width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'طلب جديد — ${req.taxiTypeLabelAr}',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${req.distanceKm.toStringAsFixed(1)} كم',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.trip_origin_rounded, size: 16, color: Colors.black),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.pickupAddress,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.dropoffAddress,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${req.fare} د.ع',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                _buildMiniButton(
                  'رفض', Colors.red, () => provider.rejectRequest(req.id)),
                const SizedBox(width: 8),
                _buildMiniButton(
                  'قبول', AppColors.success, () => provider.acceptRequest(req.id)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// عرض تفاصيل طلب محدد (بقبول/رفض)
class _RequestDetailView extends StatelessWidget {
  final TaxiRequest request;
  final TaxiProvider provider;

  const _RequestDetailView({
    required this.request,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text(
          'تفاصيل الطلب',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildMapPreview(request),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildServiceTypeChip(request),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    Icons.straighten_rounded,
                    'المسافة',
                    '${request.distanceKm.toStringAsFixed(1)} كم',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.trip_origin_rounded,
                    'عنوان الانطلاق',
                    request.pickupAddress,
                    iconColor: Colors.black,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.flag_rounded,
                    'عنوان الوصول',
                    request.dropoffAddress,
                    iconColor: AppColors.accent,
                  ),
                  const SizedBox(height: 12),
                  _buildFareCard(request),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            provider.rejectRequest(request.id);
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close_rounded,
                                    color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'رفض',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Cairo',
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            provider.acceptRequest(request.id);
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2E7D32),
                                  Color(0xFF4CAF50),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'قبول',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Cairo',
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview(TaxiRequest request) {
    return Container(
      height: 220,
      width: double.infinity,
      color: const Color(0xFFE5E3DF),
      child: Stack(
        children: [
          // خلفية الخريطة
          CustomPaint(
            size: const Size(double.infinity, 220),
            painter: _RequestMapPainter(request),
          ),
          // نقطة الانطلاق
          Positioned(
            top: 60,
            right: 60,
            child: _buildMapMarker(Icons.trip_origin_rounded, Colors.black),
          ),
          // نقطة الوصول
          Positioned(
            bottom: 60,
            left: 60,
            child: _buildMapMarker(Icons.flag_rounded, AppColors.accent),
          ),
          // زر العودة للخريطة
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: Colors.black87,
                size: 20,
              ),
            ),
          ),
          // معلومات الخريطة
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${request!.distanceKm.toStringAsFixed(1)} كم',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapMarker(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildServiceTypeChip(TaxiRequest request) {
    final isSuper = request!.taxiType == TaxiType.superTaxiType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSuper
            ? Colors.blue.withValues(alpha: 0.08)
            : AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isSuper
              ? Colors.blue.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuper ? Icons.star_rounded : Icons.electric_car_rounded,
            color: isSuper ? Colors.blue : AppColors.success,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            request!.taxiTypeLabelAr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Cairo',
              color: isSuper ? Colors.blue : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? Colors.grey, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'Cairo',
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard(TaxiRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الأجرة المقدرة',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Cairo',
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 2),
            ],
          ),
          const Spacer(),
          Text(
            '${request!.fare} د.ع',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// رسام بسيط للخريطة يوضح المسار بين نقطتين
class _RequestMapPainter extends CustomPainter {
  final TaxiRequest request;

  _RequestMapPainter(this.request);

  @override
  void paint(Canvas canvas, Size size) {
    // خط المسار
    final routePaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.4)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.7, size.height * 0.3)
      ..cubicTo(
        size.width * 0.6,
        size.height * 0.5,
        size.width * 0.4,
        size.height * 0.4,
        size.width * 0.3,
        size.height * 0.7,
      );
    canvas.drawPath(path, routePaint);

    // خطوط شبكة الخريطة
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RequestMapPainter oldDelegate) =>
      oldDelegate.request!.id != request!.id;
}
