import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/taxi_provider.dart';
import '../../models/taxi_request.dart';
import 'driver_request_screen.dart';

/// الشاشة الرئيسية للسائق — تعرض الخريطة، الإحصائيات، وطلبات التكسي الواردة
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  @override
  void initState() {
    super.initState();
    // الـ Polling يبدأ من DriverShell مباشرة
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaxiProvider>();
    final isOnline = provider.isOnline;
    final pendingRequests = provider.pendingRequests;
    final todayTrips = provider.todayTrips;
    final todayEarnings = provider.todayEarnings;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: Stack(
        children: [
          // خلفية الخريطة
          _buildMapBackground(),

          // AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildAppBar(context, provider),
          ),

          // Floating stats widget
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: _buildStatsWidget(todayTrips, todayEarnings),
          ),

          // بطاقة الطلب الجديد
          if (pendingRequests.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: _buildNewRequestCard(context, provider, pendingRequests.first),
            ),

          // زر تحديد الموقع
          Positioned(
            bottom: 180,
            right: 20,
            child: _buildRecenterFab(),
          ),

          // Bottom Navigation
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomNav(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return Container(
      color: const Color(0xFFE5E3DF),
      child: CustomPaint(
        size: Size.infinite,
        painter: _MapPatternPainter(),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, TaxiProvider provider) {
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
          // زر القائمة
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 12),

          // اسم التطبيق
          const Expanded(
            child: Text(
              'TaxiLink',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
                color: Colors.black,
              ),
            ),
          ),

          // Toggle متصل / غير متصل
          _buildOnlineToggle(provider),

          const SizedBox(width: 12),

          // صورة الملف الشخصي
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: const Icon(Icons.person, color: Colors.grey, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineToggle(TaxiProvider provider) {
    final isOnline = provider.isOnline;
    return GestureDetector(
      onTap: () => provider.toggleOnline(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isOnline ? AppColors.success : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'متصل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isOnline ? Colors.white : Colors.grey,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: !isOnline ? Colors.red : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'غير متصل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: !isOnline ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ],
        ),
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
    TaxiProvider provider,
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${request.distanceKm.toStringAsFixed(1)} كم',
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
                        request.pickupAddress,
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
                        request.dropoffAddress,
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

            // الأجرة
            Row(
              children: [
                Text(
                  'الأجرة المقدرة (${request.taxiTypeLabelAr})',
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
                  child: GestureDetector(
                    onTap: () => provider.rejectRequest(request.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, color: Colors.red, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'رفض',
                            style: TextStyle(
                              fontSize: 15,
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
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => provider.acceptRequest(request.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'قبول',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                              color: Colors.white,
                            ),
                          ),
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

  Widget _buildBottomNav(BuildContext context, TaxiProvider provider) {
    return Container(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.directions_car_rounded, 'Home', true),
          _navItem(Icons.history_rounded, 'Activity', false),
          _navItem(Icons.payments_rounded, 'Earnings', false),
          _navItem(Icons.person_rounded, 'Profile', false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.accent : Colors.grey,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'Cairo',
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? AppColors.accent : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// رسم نمط الخريطة في الخلفية
class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4D1CC).withValues(alpha: 0.5)
      ..strokeWidth = 1;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }

    // خطوط طرق بسيطة
    final routePaint = Paint()
      ..color = const Color(0xFFFCD400).withValues(alpha: 0.2)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.6,
        size.width * 0.5,
        size.height * 0.7,
        size.width,
        size.height * 0.2,
      );
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
