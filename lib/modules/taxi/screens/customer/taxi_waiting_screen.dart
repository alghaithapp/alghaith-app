import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/taxi_provider.dart';
import '../../models/taxi_request.dart';
import '../../widgets/taxi_type_image.dart';
import '../../utils/taxi_labels.dart';
import '../../utils/taxi_rating_navigation.dart';
import 'taxi_live_tracking_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../widgets/taxi_cancel_dialog.dart';
import '../../../../providers/app_provider.dart';

/// بيانات إنشاء طلب جديد — تُمرَّر لشاشة الانتظار لبدء الإرسال فوراً.
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
}

/// شاشة انتظار السائق
class TaxiWaitingScreen extends StatefulWidget {
  final TaxiTripCreateParams? createParams;

  const TaxiWaitingScreen({super.key, this.createParams});

  @override
  State<TaxiWaitingScreen> createState() => _TaxiWaitingScreenState();
}

class _TaxiWaitingScreenState extends State<TaxiWaitingScreen> {
  Timer? _timer;
  int _secondsLeft = 120;
  bool _isCreating = false;
  String? _createError;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.createParams != null) {
        _submitRequest();
      } else {
        _startPolling();
      }
    });
  }

  Future<void> _submitRequest() async {
    final params = widget.createParams;
    if (params == null || _isCreating) return;
    setState(() {
      _isCreating = true;
      _createError = null;
    });

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
    );

    if (!mounted) return;

    if (request == null) {
      setState(() {
        _isCreating = false;
        _createError = provider.error ?? 'تعذر إرسال الطلب، حاول مجدداً';
      });
      return;
    }

    setState(() => _isCreating = false);
    _startPolling();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_secondsLeft <= 0) {
        timer.cancel();
        if (!mounted) return;
        final provider = context.read<TaxiProvider>();
        await provider.loadActiveRequest();
        if (!mounted) return;
        final request = provider.currentRequest;
        if (request == null || request.isCancelled) {
          _showExpiredAndExit();
        }
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  void _showExpiredAndExit() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'انتهت مهلة البحث — لم يقبل أحد الطلب. يمكنك المحاولة مجدداً.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  void _startPolling() {
    final provider = context.read<TaxiProvider>();
    final phone = context.read<AppProvider>().authPhone;
    provider.startPolling(phone: phone);
    provider.loadActiveRequest();
  }

  Future<void> _onCancelTrip() async {
    final provider = context.read<TaxiProvider>();
    final request = provider.currentRequest;
    if (request == null || !request.canCustomerCancel) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يمكن إلغاء الطلب حالياً',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
      return;
    }

    final confirmed = await showTaxiCancelDialog(context);
    if (confirmed != true || !mounted) return;

    _timer?.cancel();
    final ok = await provider.cancelRequest(request.id);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إلغاء الرحلة',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
      Navigator.of(context).pop();
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

            if (request != null && request.isCancelled) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _showExpiredAndExit();
              });
            }

            if (request != null && request.isAccepted) {
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

            if (provider.tripAwaitingRating != null) {
              final pending = provider.tripAwaitingRating!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _timer?.cancel();
                  TaxiRatingNavigation.openIfNeeded(context, pending);
                }
              });
            }

            final statusText = _createError != null
                ? _createError!
                : _isCreating
                    ? 'جاري إرسال طلبك...'
                    : 'جاري البحث عن كابتن قريب...';
            final waitingType = request?.taxiType ??
                TaxiTypeX.fromApiName(widget.createParams?.taxiType);

            return Stack(
              children: [
                Container(
                  color: const Color(0xFFF3F3F3),
                  width: double.infinity,
                  height: double.infinity,
                  child: CustomPaint(
                    painter: _MapGridPainter(),
                  ),
                ),
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
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _createError != null
                                ? 'تعذر إرسال الطلب'
                                : 'بانتظار كابتن...',
                            style: const TextStyle(
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
                if (_createError == null)
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
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TaxiTypeImage(
                        type: waitingType,
                        width: 88,
                        height: 88,
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          statusText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            color: _createError != null
                                ? Colors.red.shade700
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (_createError != null) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _submitRequest,
                          child: const Text(
                            'إعادة المحاولة',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_isCreating &&
                    _createError == null &&
                    request != null &&
                    request.canCustomerCancel)
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
              ],
            );
          },
        ),
      ),
    );
  }
}

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
