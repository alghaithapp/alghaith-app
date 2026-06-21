import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/taxi_provider.dart';
import '../../models/taxi_request.dart';

/// شاشة رحلات السائق — تعرض الرحلة النشطة أو تاريخ الرحلات
/// إذا تم تمرير [trip] تظهر تفاصيل رحلة محددة، وإلا تعرض الرحلة الحالية من TaxiProvider.
class DriverTripScreen extends StatefulWidget {
  final TaxiRequest? trip;

  const DriverTripScreen({super.key, this.trip});

  @override
  State<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends State<DriverTripScreen> {
  /// 0 = وصلت, 1 = بدأت الرحلة, 2 = اكتملت الرحلة
  int _statusIndex = 0;

  @override
  void initState() {
    super.initState();
    _initStatusIndex();
  }

  void _initStatusIndex() {
    if (widget.trip == null) return;
    final key = widget.trip!.statusKey;
    if (key == 'arrived') {
      _statusIndex = 1;
    } else if (key == 'picked_up' || key == 'completed') {
      _statusIndex = 2;
    } else {
      _statusIndex = 0;
    }
  }

  void _advanceStatus(TaxiProvider provider) {
    // استخدم الرحلة المتاحة (من widget أو من provider)
    final tripId = widget.trip?.id ?? provider.currentRequest?.id;
    if (tripId == null) return;

    final nextIndex = (_statusIndex + 1) % 3;
    String statusKey;
    String statusAr;

    switch (nextIndex) {
      case 1:
        statusKey = 'arrived';
        statusAr = 'وصلت';
        break;
      case 2:
        statusKey = 'picked_up';
        statusAr = 'بدأت الرحلة';
        break;
      default:
        // العودة للبداية (مكتمل)
        statusKey = 'completed';
        statusAr = 'اكتملت الرحلة';
        provider.updateStatus(tripId, statusKey);
        setState(() => _statusIndex = 2);
        return;
    }

    provider.updateStatus(tripId, statusKey);
    setState(() => _statusIndex = nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaxiProvider>();
    // في وضع التاب: استخدم الرحلة النشطة من TaxiProvider
    final activeTrip = widget.trip ?? provider.currentRequest;

    // إذا لا توجد رحلة نشطة → اعرض حالة فارغة أو تاريخ الرحلات
    if (activeTrip == null) {
      return _buildNoActiveTrip(context, provider);
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: Stack(
        children: [
          // خلفية الخريطة
          _buildMapBackground(),

          // الشريط العلوي
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(activeTrip),
          ),

          // زر تحديد الموقع
          Positioned(
            bottom: 340,
            right: 20,
            child: _buildRecenterFab(),
          ),

          // Bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomSheet(context, provider, activeTrip),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveTrip(BuildContext context, TaxiProvider provider) {
    final completed = provider.completedTrips;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text(
          'الرحلات',
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
      body: completed.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد رحلة نشطة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'سيتم عرض رحلاتك هنا',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: completed.length,
              itemBuilder: (context, index) {
                final trip = completed[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.pickupAddress,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '→ ${trip.dropoffAddress}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${trip.fare} د.ع',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMapBackground() {
    return Container(
      color: const Color(0xFFE5E3DF),
      child: CustomPaint(
        size: Size.infinite,
        painter: _TripMapPainter(),
      ),
    );
  }

  Widget _buildTopBar(TaxiRequest trip) {
    final statusLabels = {
      'accepted': 'في الطريق للراكب',
      'arrived': 'وصلت إلى موقع الانطلاق',
      'picked_up': 'في الطريق للوجهة',
      'completed': 'اكتملت الرحلة',
    };

    final statusLabel = statusLabels[trip.statusKey] ?? 'في الطريق للراكب';

    return Container(
      padding: const EdgeInsets.only(top: 48, left: 16, right: 16, bottom: 12),
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
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'رحلة نشطة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
                color: Colors.black,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildBottomSheet(
    BuildContext context,
    TaxiProvider provider,
    TaxiRequest trip,
  ) {
    final statusTexts = ['وصلت', 'بدأت الرحلة', 'اكتملت الرحلة'];
    final statusIcons = [
      Icons.location_on_rounded,
      Icons.play_arrow_rounded,
      Icons.check_circle_rounded,
    ];
    final statusColors = [
      AppColors.accent,
      Colors.black,
      AppColors.success,
    ];
    final currentText = statusTexts[_statusIndex];
    final currentIcon = statusIcons[_statusIndex];
    final currentColor = statusColors[_statusIndex];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // مقبض السحب
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // معلومات الزبون
                Row(
                  children: [
                    // الصورة الرمزية
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          trip.customerName.isNotEmpty
                              ? trip.customerName.substring(0, 1)
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo',
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.customerName.isNotEmpty
                                ? trip.customerName
                                : 'الزبون',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppColors.accent, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${trip.driverRating}.0',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Cairo',
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // أزرار الاتصال والرسالة
                    Row(
                      children: [
                        _buildIconButton(Icons.chat_bubble_rounded, Colors.grey),
                        const SizedBox(width: 8),
                        _buildIconButton(Icons.phone_rounded, AppColors.success),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // العنوانين
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.scaffold,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            height: 24,
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
                            const SizedBox(height: 2),
                            Text(
                              trip.pickupAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Cairo',
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'الوجهة',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Cairo',
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              trip.dropoffAddress,
                              style: const TextStyle(
                                fontSize: 14,
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
                ),
                const SizedBox(height: 12),

                // الأجرة المتوقعة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.scaffold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'الأجرة المتوقعة (للتحصيل)',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Cairo',
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${trip.fare} د.ع',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'كاش',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo',
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // زر الحالة التفاعلي
                GestureDetector(
                  onTap: () => _advanceStatus(provider),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(currentIcon, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          currentText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo',
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// رسام بسيط للخريطة
class _TripMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // مسار الرحلة
    final routePaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.5)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.7)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.5,
        size.width * 0.55,
        size.height * 0.55,
        size.width * 0.8,
        size.height * 0.3,
      );
    canvas.drawPath(path, routePaint);

    // سيارة السائق
    final carPaint = Paint()..color = Colors.black;
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.55),
      8,
      carPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
