import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/taxi_provider.dart';
import '../../models/taxi_request.dart';

/// شاشة تفاصيل الطلب للسائق — تظهر عند الضغط على "عرض التفاصيل"
class DriverRequestScreen extends StatelessWidget {
  final TaxiRequest? request;

  const DriverRequestScreen({super.key, this.request});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaxiProvider>();

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
          // خريطة توضح نقطة الانطلاق والوصول
          _buildMapPreview(request!),

          // معلومات الطلب
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // نوع الخدمة
                  _buildServiceTypeChip(request!),
                  const SizedBox(height: 16),

                  // المسافة
                  _buildDetailRow(
                    Icons.straighten_rounded,
                    'المسافة',
                    '${request!.distanceKm.toStringAsFixed(1)} كم',
                  ),
                  const SizedBox(height: 12),

                  // عنوان الانطلاق
                  _buildDetailRow(
                    Icons.trip_origin_rounded,
                    'عنوان الانطلاق',
                    request!.pickupAddress,
                    iconColor: Colors.black,
                  ),
                  const SizedBox(height: 12),

                  // عنوان الوصول
                  _buildDetailRow(
                    Icons.flag_rounded,
                    'عنوان الوصول',
                    request!.dropoffAddress,
                    iconColor: AppColors.accent,
                  ),
                  const SizedBox(height: 12),

                  // الأجرة
                  _buildFareCard(request!),
                  const SizedBox(height: 24),

                  // أزرار القبول / الرفض
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            provider.rejectRequest(request!.id);
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
                            provider.acceptRequest(request!.id);
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
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
