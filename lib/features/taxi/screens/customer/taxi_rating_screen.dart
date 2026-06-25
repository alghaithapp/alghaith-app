import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/taxi_request.dart';
import '../../providers/taxi_provider.dart';
import '../../widgets/taxi_plate_badge.dart';

/// شاشة تقييم السائق بعد اكتمال الرحلة.
class TaxiRatingScreen extends StatefulWidget {
  final TaxiRequest request;

  const TaxiRatingScreen({super.key, required this.request});

  @override
  State<TaxiRatingScreen> createState() => _TaxiRatingScreenState();
}

class _TaxiRatingScreenState extends State<TaxiRatingScreen> {
  int _selectedStars = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    switch (_selectedStars) {
      case 1:
        return 'سيئة جداً';
      case 2:
        return 'سيئة';
      case 3:
        return 'مقبولة';
      case 4:
        return 'جيدة';
      case 5:
        return 'ممتازة';
      default:
        return '';
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final provider = context.read<TaxiProvider>();
    final ok = await provider.rateTrip(
      requestId: widget.request.id,
      rating: _selectedStars,
      comment: _commentController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      await provider.loadHistory();
      if (!mounted) return;
      Navigator.of(context).pop();
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'شكراً لتقييمك!',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'تعذر إرسال التقييم',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _skip() {
    context
        .read<TaxiProvider>()
        .clearTripAwaitingRating(requestId: widget.request.id);
    Navigator.of(context).pop();
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final driverName = request.driverName?.trim().isNotEmpty == true
        ? request.driverName!.trim()
        : 'السائق';

    return PopScope(
      canPop: !_isSubmitting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_isSubmitting) {
          context
              .read<TaxiProvider>()
              .clearTripAwaitingRating(requestId: widget.request.id);
        }
      },
      child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'تقييم الرحلة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSubmitting ? null : _skip,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تمت الرحلة بنجاح',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'كيف كانت تجربتك مع السائق؟',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              _DriverCard(
                driverName: driverName,
                vehicleModel: request.vehicleModelDisplay,
                plateNumber: request.plateNumberDisplay,
                taxiTypeLabel: request.taxiTypeLabelAr,
              ),
              const SizedBox(height: 16),
              _TripSummaryCard(request: request),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final filled = index < _selectedStars;
                  return GestureDetector(
                    onTap: _isSubmitting
                        ? null
                        : () => setState(() => _selectedStars = index + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_border_rounded,
                        color: filled
                            ? const Color(0xFFFCD400)
                            : Colors.grey.shade400,
                        size: 42,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _ratingLabel,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _commentController,
                enabled: !_isSubmitting,
                maxLines: 3,
                maxLength: 500,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'اكتب ملاحظتك (اختياري)',
                  hintStyle: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.accent.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'إرسال التقييم',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _isSubmitting ? null : _skip,
                child: Text(
                  'تخطي الآن',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final String driverName;
  final String vehicleModel;
  final String? plateNumber;
  final String taxiTypeLabel;

  const _DriverCard({
    required this.driverName,
    required this.vehicleModel,
    required this.plateNumber,
    required this.taxiTypeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFEEEEEE),
            child: Text(
              driverName.isNotEmpty ? driverName[0] : 'س',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  taxiTypeLabel,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (vehicleModel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    vehicleModel,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (plateNumber != null && plateNumber!.trim().isNotEmpty)
            TaxiPlateBadge(plateNumber: plateNumber!),
        ],
      ),
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  final TaxiRequest request;

  const _TripSummaryCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص الرحلة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _RouteRow(
            icon: Icons.my_location,
            iconColor: AppColors.primary,
            label: request.pickupAddress,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: Container(
              width: 2,
              height: 16,
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: Colors.grey.shade300,
            ),
          ),
          _RouteRow(
            icon: Icons.place,
            iconColor: AppColors.accent,
            label: request.dropoffAddress,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.straighten, size: 18, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                '${request.distanceKm.toStringAsFixed(1)} كم',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              const Icon(Icons.payments, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '${request.fare} د.ع',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          ),
        ),
      ],
    );
  }
}
