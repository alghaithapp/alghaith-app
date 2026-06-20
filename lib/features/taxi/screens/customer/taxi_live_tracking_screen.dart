import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/taxi_provider.dart';
import '../../../../core/theme/app_colors.dart';

/// شاشة التتبع المباشر — مستوحاة من _3/code.html
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
    _startPolling();
  }

  void _startPolling() {
    final provider = context.read<TaxiProvider>();
    provider.startPolling(isDriver: false);
  }

  void _onCallDriver() {
    // فتح تطبيق الهاتف — يمكن تنفيذه لاحقاً باستخدام url_launcher
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري الاتصال بالسائق...',
            style: TextStyle(fontFamily: 'Cairo')),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onMessageDriver() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('فتح المحادثة...',
            style: TextStyle(fontFamily: 'Cairo')),
        duration: Duration(seconds: 2),
      ),
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

            return Stack(
              children: [
                // ── خلفية الخريطة ──
                Container(
                  color: const Color(0xFFF3F3F3),
                  width: double.infinity,
                  height: double.infinity,
                  child: CustomPaint(
                    painter: _MapGridPainter(),
                  ),
                ),

                // ── شريط الحالة العلوي العائم ──
                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
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
                            child: Center(
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'السائق في الطريق إليك',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '3 دقائق',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── أيقونة السيارة على الخريطة ──
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_car,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),

                // ── أزرار التحكم بالخريطة (FABs) ──
                Positioned(
                  bottom: 300,
                  right: 20,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        onPressed: () {},
                        child: const Icon(Icons.my_location),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        onPressed: () {},
                        child: const Icon(Icons.security),
                      ),
                    ],
                  ),
                ),

                // ── Bottom Sheet: معلومات السائق والرحلة ──
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
                            // مقبض السحب
                            Container(
                              width: 48,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCFC4C5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── صورة السائق + الاسم + التقييم ──
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: const Color(0xFFEEEEEE),
                                  child: Text(
                                    request?.driverName?.isNotEmpty == true
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
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.star,
                                                    size: 12,
                                                    color:
                                                        AppColors.accent),
                                                const SizedBox(width: 2),
                                                Text(
                                                  (request?.driverRating ?? 0) > 0
                                                      ? '${request!.driverRating}'
                                                      : '4.9',
                                                  style: const TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.accent,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.workspace_premium,
                                              size: 14,
                                              color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'سائق مميز',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // زر المشاركة
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F3F3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.share,
                                        size: 20,
                                        color: AppColors.textSecondary),
                                    onPressed: () {},
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ── معلومات السيارة ──
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F3F3),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFFE2E2E2)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          request?.driverVehicleInfo ??
                                              'تويوتا كورولا 2022',
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                                border: Border.all(
                                                    color:
                                                        AppColors.textSecondary),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'أبيض',
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 14,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // لوحة السيارة
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFCFC4C5)),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text(
                                          'ب ب 1234',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Container(
                                          height: 1,
                                          width: 40,
                                          color: const Color(0xFFCFC4C5),
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 2),
                                        ),
                                        const Text(
                                          'السعودية',
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── أزرار اتصال ورسالة ──
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 56,
                                    child: ElevatedButton.icon(
                                      onPressed: _onCallDriver,
                                      icon: const Icon(Icons.call),
                                      label: const Text(
                                        'اتصال',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.accent,
                                        foregroundColor:
                                            AppColors.accent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 56,
                                    child: OutlinedButton.icon(
                                      onPressed: _onMessageDriver,
                                      icon: const Icon(Icons.chat_bubble),
                                      label: const Text(
                                        'رسالة',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            AppColors.primary,
                                        side: const BorderSide(
                                            color: Color(0xFFE2E2E2)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ── تفاصيل الرحلة ──
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F3F3),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  // عمود النقاط والخط
                                  Column(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      Container(
                                        width: 2,
                                        height: 24,
                                        color: const Color(0xFFCFC4C5),
                                      ),
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.rectangle,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'نقطة الانطلاق',
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${request?.distanceKm.toStringAsFixed(1) ?? '0'} كم',
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        const Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'موقعي الحالي',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'الوجهة',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'شارع فلسطين، مجمع السلام',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ── الأجرة ──
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F3F3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
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
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'كاش',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

// ── Painter لخلفية الخريطة (شبكة) ──
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 1;

    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
