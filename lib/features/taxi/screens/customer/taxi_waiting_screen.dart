import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/taxi_provider.dart';
import 'taxi_live_tracking_screen.dart';
import '../../../../core/theme/app_colors.dart';

/// شاشة انتظار السائق — مستوحاة من _3/code.html
class TaxiWaitingScreen extends StatefulWidget {
  const TaxiWaitingScreen({super.key});

  @override
  State<TaxiWaitingScreen> createState() => _TaxiWaitingScreenState();
}

class _TaxiWaitingScreenState extends State<TaxiWaitingScreen> {
  Timer? _timer;
  int _secondsLeft = 120;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startPolling();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  void _startPolling() {
    final provider = context.read<TaxiProvider>();
    provider.startPolling();
  }

  void _onCancelTrip() {
    _timer?.cancel();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الرحلة',
            style: TextStyle(fontFamily: 'Cairo')),
        content: const Text('هل أنت متأكد من إلغاء الرحلة؟',
            style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('رجوع',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () {
              context.read<TaxiProvider>().cancelRequest('', ''); // TODO: replace with actual requestId
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('تأكيد الإلغاء',
                style: TextStyle(
                    fontFamily: 'Cairo', color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Consumer<TaxiProvider>(
          builder: (context, provider, _) {
            final request = provider.currentRequest;

            // عند قبول السائق → انتقال إلى شاشة التتبع
            if (request != null && request.isAccepted) {
              // التوجيه بعد إطار البناء
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _timer?.cancel();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const TaxiLiveTrackingScreen(),
                    ),
                  );
                }
              });
            }

            // عند اكتمال الرحلة → انتقال إلى شاشة التقييم
            if (request != null && request.isCompleted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _timer?.cancel();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const _RatingPlaceholderScreen(),
                    ),
                  );
                }
              });
            }

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

                // ── حالة الانتظار العائمة ──
                Positioned(
                  top: 60,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                            child: Center(
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'بانتظار سائق...',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── المؤقت العكسي ──
                Positioned(
                  top: 130,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            _formattedTime,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── مؤشر التحميل ──
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'جاري البحث عن سائق قريب...',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── زر إلغاء الرحلة ──
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _onCancelTrip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'إلغاء الرحلة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── معلومات السائق (عند القبول) ──
                if (request != null && request.isAccepted)
                  Positioned(
                    bottom: 100,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFFEEEEEE),
                                child: Text(
                                  (request.driverName?.isNotEmpty == true)
                                      ? request.driverName![0]
                                      : 'س',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 20,
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
                                      request.driverName ?? 'السائق',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star,
                                            size: 16,
                                            color: AppColors.accent),
                                        const SizedBox(width: 4),
                                        Text(
                                          request.driverRating > 0
                                              ? '${request.driverRating}'
                                              : '5.0',
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.directions_car,
                                            size: 16,
                                            color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          request.driverVehicleInfo ??
                                              'سيارة',
                                          style: const TextStyle(
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
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 18, color: AppColors.success),
                                SizedBox(width: 8),
                                Text(
                                  'السائق في الطريق إليك',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

// ── شاشة تقييم مؤقتة (تحتاج إلى تطوير لاحق) ──
class _RatingPlaceholderScreen extends StatelessWidget {
  const _RatingPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييم الرحلة'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_half,
                size: 64, color: AppColors.accent),
            const SizedBox(height: 16),
            const Text(
              'شكراً لك! تمت الرحلة بنجاح',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accent,
              ),
              child: const Text(
                'العودة إلى الرئيسية',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
