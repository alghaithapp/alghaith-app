import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/taxi_provider.dart';
import '../../models/taxi_request.dart';
import '../../utils/taxi_fare_calculator.dart';
import '../../utils/taxi_distance_calculator.dart';
import '../../utils/taxi_labels.dart';
import '../../utils/taxi_rating_navigation.dart';
import 'taxi_live_tracking_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/app_config_service.dart';
import '../../widgets/taxi_cancel_dialog.dart';
import '../../../../providers/app_provider.dart';
import '../../../../utils/extensions.dart';

class TaxiTripCreateParams {
  const TaxiTripCreateParams({
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.distanceKm,
    required this.taxiType,
    this.waypoints = const [],
    this.isRoundTrip = false,
    this.waitingMinutes,
  });

  final String pickupAddress;
  final String dropoffAddress;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final double distanceKm;
  final String taxiType;
  final List<TaxiWaypoint> waypoints;
  final bool isRoundTrip;
  final int? waitingMinutes;
}

class TaxiWaitingScreen extends StatefulWidget {
  final TaxiTripCreateParams? createParams;

  const TaxiWaitingScreen({super.key, this.createParams});

  @override
  State<TaxiWaitingScreen> createState() => _TaxiWaitingScreenState();
}

class _TaxiWaitingScreenState extends State<TaxiWaitingScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  int get _searchTimeoutSeconds => AppConfigService.instance.searchTimeoutSeconds;
  int _secondsLeft = 300;
  bool _submitted = false;
  bool _submitError = false;
  String _errorMessage = '';
  String _status = 'جار البحث عن كابتن...';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  late AnimationController _orbitController;
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.createParams != null && !_submitted) {
        _submitRequest();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _orbitController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (_submitted) return;
    setState(() => _submitted = true);

    final params = widget.createParams!;
    final provider = context.read<TaxiProvider>();

    final request = await provider.createTaxiRequest(
      pickupAddress: params.pickupAddress,
      dropoffAddress: params.dropoffAddress,
      pickupLat: params.pickupLat,
      pickupLng: params.pickupLng,
      dropoffLat: params.dropoffLat,
      dropoffLng: params.dropoffLng,
      distanceKm: params.distanceKm,
      taxiType: params.taxiType,
      waypoints: params.waypoints,
      isRoundTrip: params.isRoundTrip,
      waitingMinutes: params.waitingMinutes,
    );

    if (!mounted) return;
    if (request != null) {
      _startCountdown();
    } else {
      setState(() {
        _submitError = true;
        _errorMessage = 'تعذّر إنشاء الطلب. حاول مجدداً.';
        _status = 'فشل إنشاء الطلب';
      });
    }
  }

  void _startCountdown() {
    final total = _searchTimeoutSeconds;
    _secondsLeft = total;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft = total - timer.tick;
        if (_secondsLeft <= 0) {
          timer.cancel();
          _status = 'انتهت مهلة البحث';
        }
      });
    });
  }

  String get _etaLabel {
    if (_secondsLeft <= 0) return 'انتهى';
    final min = _secondsLeft ~/ 60;
    final sec = _secondsLeft % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  double get _progress => _secondsLeft > 0 ? _secondsLeft / _searchTimeoutSeconds : 0.0;

  Color get _progressColor {
    if (_secondsLeft > 120) return const Color(0xFF0EA5E9);
    if (_secondsLeft > 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _buildAnimatedCar(Size size) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Transform.scale(
        scale: _pulseAnim.value,
        child: child,
      ),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
            center: Alignment.center,
            radius: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.local_taxi_rounded, size: 52, color: Colors.white),
      ),
    );
  }

  Widget _buildOrbitDots(Size size) {
    const dotCount = 3;
    return AnimatedBuilder(
      animation: _orbitController,
      builder: (context, child) {
        return CustomPaint(
          size: size,
          painter: _OrbitPainter(
            progress: _orbitController.value,
            dotProgress: _dotController.value,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<TaxiProvider>(
      builder: (context, provider, _) {
        final activeRequest = provider.currentRequest;

        if (activeRequest != null && activeRequest.hasAssignedDriver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const TaxiLiveTrackingScreen(),
              ),
            );
          });
        }

        if (_submitError) {
          return PopScope(
            canPop: true,
            child: Scaffold(
              backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF8FAFC),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withValues(alpha: 0.1),
                        ),
                        child: const Icon(Icons.error_outline, size: 40, color: Colors.red),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _errorMessage,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: isDark ? Colors.white70 : Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _submitRequest,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Stack(
              children: [
                // ── Premium blurred gradient background ──
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [const Color(0xFF0F0F0F), const Color(0xFF0A1628)]
                            : [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)],
                      ),
                    ),
                  ),
                ),

                // ── Decorative blur bubbles ──
                Positioned(top: -60, right: -40,
                  child: Container(width: 180, height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.07),
                    ),
                  ),
                ),
                Positioned(bottom: 80, left: -50,
                  child: Container(width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.05),
                    ),
                  ),
                ),

                // ── Back button ──
                Positioned(
                  top: 8, left: 8,
                  child: GestureDetector(
                    onTap: () => _onBack(provider),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ),

                // ── Main content ──
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 40),

                      // ── Animated car icon with orbit ──
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildOrbitDots(const Size(200, 200)),
                            _buildAnimatedCar(size),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Status text ──
                      AnimatedBuilder(
                        animation: _dotController,
                        builder: (context, _) {
                          final dots = (_dotController.value * 3).floor() + 1;
                          return Text(
                            '$_status${'.' * dots}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                            textAlign: TextAlign.center,
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'نبحث عن كابتن قريب منك',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── Trip info card ──
                      if (widget.createParams != null) ...[
                        _buildTripInfoCard(isDark),
                        const SizedBox(height: 32),
                      ],

                      // ── Timer ──
                      _buildTimer(isDark),

                      const SizedBox(height: 24),

                      // ── Cancel button ──
                      TextButton.icon(
                        onPressed: () => _onBack(provider),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text(
                          'إلغاء الطلب',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTripInfoCard(bool isDark) {
    final p = widget.createParams!;
    final fare = TaxiFareCalculator.fareForTypeWithRoundTrip(
      p.distanceKm,
      TaxiTypeX.fromApiName(p.taxiType),
      p.isRoundTrip,
    );
    final eta = TaxiDistanceCalculator.estimateDrivingDurationSeconds(p.distanceKm);
    final etaLabel = TaxiDistanceCalculator.formatDrivingDurationAr(eta);
    final tripLabel = p.isRoundTrip ? 'ذهاب وعودة' : 'ذهاب فقط';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tripLabel,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0EA5E9)),
                ),
              ),
              const Spacer(),
              if (p.isRoundTrip && p.waitingMinutes != null)
                Text(
                  'انتظار ${p.waitingMinutes} دقيقة',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(Icons.trip_origin, p.pickupAddress, isDark),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: Column(
              children: [
                Container(width: 1, height: 8, color: isDark ? Colors.white24 : Colors.grey.shade300),
                Icon(Icons.arrow_downward, size: 12, color: isDark ? Colors.white24 : Colors.grey.shade400),
                Container(width: 1, height: 8, color: isDark ? Colors.white24 : Colors.grey.shade300),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _infoRow(Icons.location_on, p.dropoffAddress, isDark),
          if (p.isRoundTrip) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 22),
              child: Column(
                children: [
                  Container(width: 1, height: 8, color: isDark ? Colors.white24 : Colors.grey.shade300),
                  const Icon(Icons.replay, size: 12, color: Color(0xFF0EA5E9)),
                  Container(width: 1, height: 8, color: isDark ? Colors.white24 : Colors.grey.shade300),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _infoRow(Icons.flag_rounded, p.pickupAddress, isDark),
            const SizedBox(height: 8),
          ],
          Divider(color: isDark ? Colors.white10 : Colors.grey.shade200, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: isDark ? Colors.white54 : Colors.grey),
                  const SizedBox(width: 4),
                  Text(etaLabel, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                ],
              ),
              Text(
                '${fare.toLocaleString()} د.ع',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0EA5E9)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: icon == Icons.trip_origin
            ? const Color(0xFF0EA5E9)
            : icon == Icons.flag_rounded
                ? const Color(0xFF0EA5E9)
                : const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTimer(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: 64, height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _progress,
                strokeWidth: 4,
                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(_progressColor),
                strokeCap: StrokeCap.round,
              ),
              Text(
                _etaLabel,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'الوقت المتبقي',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade400),
        ),
      ],
    );
  }

  void _onBack(dynamic provider) {
    _timer?.cancel();
    if (provider.currentRequest?.isPending ?? false) {
      provider.cancelRequest(provider.currentRequest!.id);
    }
    Navigator.of(context).pop();
  }
}

class _OrbitPainter extends CustomPainter {
  final double progress;
  final double dotProgress;

  _OrbitPainter({required this.progress, required this.dotProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 28;
    final paint = Paint()
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, paint);

    for (var i = 0; i < 3; i++) {
      final angle = (progress * math.pi * 2) + (i * math.pi * 2 / 3);
      final dotX = center.dx + radius * math.cos(angle);
      final dotY = center.dy + radius * math.sin(angle);
      final alpha = ((dotProgress + i * 0.3) % 1.0);
      final dotPaint = Paint()
        ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.15 + alpha * 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.progress != progress || old.dotProgress != dotProgress;
}
