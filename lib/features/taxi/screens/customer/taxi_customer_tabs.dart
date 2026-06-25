import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/taxi_request.dart';
import '../../providers/taxi_provider.dart';
import '../../widgets/taxi_cancel_dialog.dart';
import '../../widgets/taxi_type_image.dart';
import '../../widgets/taxi_plate_badge.dart';
import '../../widgets/taxi_order_tracking_map.dart';
import '../../utils/taxi_rating_navigation.dart';
import '../../utils/taxi_labels.dart';
import 'taxi_live_tracking_screen.dart';
import '../../../../utils/helpers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../widgets/taxi_driver_contact_buttons.dart';
import '../../../../widgets/internal_contact_buttons.dart';

/// تبويب طلبي الحالي.
class TaxiCurrentRequestTab extends StatefulWidget {
  const TaxiCurrentRequestTab({super.key});

  @override
  State<TaxiCurrentRequestTab> createState() => _TaxiCurrentRequestTabState();
}

class _TaxiCurrentRequestTabState extends State<TaxiCurrentRequestTab> {
  bool _isCancelling = false;

  Future<void> _cancelRequest(TaxiRequest request) async {
    final confirmed = await showTaxiCancelDialog(context);
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    final provider = context.read<TaxiProvider>();
    final ok = await provider.cancelRequest(request.id);
    if (!mounted) return;
    setState(() => _isCancelling = false);

    if (ok) {
      await provider.loadActiveRequest();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إلغاء الرحلة',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
      );
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
  Widget build(BuildContext context) {
    return Consumer<TaxiProvider>(
      builder: (context, provider, _) {
        final request = provider.currentRequest;

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (request == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.taxi_alert, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'لا يوجد طلب حالي',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اذهب إلى طلب رحلة لإنشاء طلب جديد',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _statusIconColor(request.statusKey)
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _statusIcon(request.statusKey),
                        color: _statusIconColor(request.statusKey),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusLabel(request.statusKey),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _statusIconColor(request.statusKey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (request.requestNumber.isNotEmpty)
                      Text(
                        'رقم الطلب: ${request.requestNumber}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (request.canShowLiveTracking) ...[
                TaxiOrderTrackingMap(
                  request: request,
                  onExpand: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TaxiLiveTrackingScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تفاصيل الرحلة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Divider(),
                    if (!request.canShowLiveTracking) ...[
                      _detailRow(Icons.my_location, 'من', request.pickupAddress),
                      const SizedBox(height: 8),
                      _detailRow(Icons.place, 'إلى', request.dropoffAddress),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        const Icon(
                          Icons.straighten,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'المسافة: ${request.distanceKm.toStringAsFixed(1)} كم',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.payments,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${request.fare} د.ع',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (request.taxiTypeLabelAr.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TaxiTypeImage(
                            type: request.taxiType,
                            width: 36,
                            height: 36,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'نوع الخدمة: ${request.taxiTypeLabelAr}',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                    if (request.isCancelRequested &&
                        request.cancellationReason != null &&
                        request.cancellationReason!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'سبب الإلغاء: ${request.cancellationReason}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (request.hasAssignedDriver) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'معلومات الكابتن',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Divider(),
                      _detailRow(
                        Icons.person,
                        'الاسم',
                        (request.driverName?.trim().isNotEmpty == true)
                            ? request.driverName!
                            : TaxiLabels.captain,
                      ),
                      if (request.vehicleModelDisplay.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _detailRow(
                          Icons.directions_car,
                          'السيارة',
                          request.vehicleModelDisplay,
                        ),
                      ],
                      if (request.plateNumberDisplay.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.pin,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'اللوحة:',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TaxiPlateBadge(plateNumber: request.plateNumberDisplay),
                          ],
                        ),
                      ] else if (request.driverVehicleInfo != null &&
                          request.driverVehicleInfo!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _detailRow(
                          Icons.directions_car,
                          'السيارة',
                          request.driverVehicleInfo ?? '',
                        ),
                      ],
                      if (request.hasAssignedDriver) ...[
                        const SizedBox(height: 12),
                        InternalContactButtons.taxi(
                          requestId: request.id,
                          otherPartyName: request.driverName ?? TaxiLabels.theCaptain,
                          chatLabel: 'مراسلة داخلية',
                          callLabel: 'اتصال داخلي',
                        ),
                        if (request.driverPhone?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          TaxiDriverContactButtons(
                            driverPhone: request.driverPhone,
                            driverName: request.driverName ?? TaxiLabels.theCaptain,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
              if (request.canCustomerCancel) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isCancelling || provider.isLoading
                        ? null
                        : () => _cancelRequest(request),
                    icon: _isCancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: const Text(
                      'إلغاء الرحلة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '$label:',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  IconData _statusIcon(String key) {
    switch (key) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
      case 'on_way':
        return Icons.directions_car;
      case 'arrived':
        return Icons.location_on;
      case 'picked_up':
        return Icons.trip_origin;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'cancel_requested':
        return Icons.hourglass_top;
      default:
        return Icons.info;
    }
  }

  Color _statusIconColor(String key) {
    switch (key) {
      case 'pending':
        return const Color(0xFFF9A825);
      case 'accepted':
      case 'on_way':
        return AppColors.primary;
      case 'arrived':
        return const Color(0xFF2E7D32);
      case 'picked_up':
        return const Color(0xFF145B66);
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'cancelled':
        return const Color(0xFFC62828);
      case 'cancel_requested':
        return const Color(0xFFE65100);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String key) {
    switch (key) {
      case 'pending':
        return 'بانتظار كابتن';
      case 'accepted':
      case 'on_way':
        return 'الكابتن في الطريق';
      case 'arrived':
        return 'الكابتن في مكان الالتقاء';
      case 'picked_up':
        return 'تم الاستلام';
      case 'completed':
        return 'اكتملت الرحلة';
      case 'cancelled':
        return 'ملغية';
      case 'cancel_requested':
        return 'بانتظار موافقة الكابتن على الإلغاء';
      default:
        return key;
    }
  }
}

/// تبويب سجل الطلبات.
class TaxiHistoryTab extends StatelessWidget {
  const TaxiHistoryTab({super.key, this.onReplayTrip});

  final ValueChanged<TaxiRequest>? onReplayTrip;

  @override
  Widget build(BuildContext context) {
    return Consumer<TaxiProvider>(
      builder: (context, provider, _) {
        final requests = provider.requests
            .where((r) => r.isCompleted || r.isCancelled)
            .toList();

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'لا توجد طلبات سابقة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'قم برحلة جديدة لتظهر هنا',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadHistory(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) => _HistoryTripCard(
              request: requests[index],
              onReplayTrip: onReplayTrip,
            ),
          ),
        );
      },
    );
  }
}

class _HistoryTripCard extends StatelessWidget {
  final TaxiRequest request;
  final ValueChanged<TaxiRequest>? onReplayTrip;

  const _HistoryTripCard({
    required this.request,
    this.onReplayTrip,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = request.isCompleted;
    final statusColor =
        isCompleted ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final statusText = isCompleted ? 'مكتمل' : 'ملغي';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    request.requestNumber.isNotEmpty
                        ? request.requestNumber
                        : '---',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF145B66),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(request.completedAt ?? request.acceptedAt),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.my_location, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.pickupAddress,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place, size: 14, color: AppColors.accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.dropoffAddress,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.straighten, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${request.distanceKm.toStringAsFixed(1)} كم',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.payments, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${request.fare} د.ع',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (request.driverName != null && request.driverName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    request.driverName!,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (request.driverVehicleInfo != null &&
                      request.driverVehicleInfo!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.directions_car, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.driverVehicleInfo!,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (isCompleted) ...[
              const SizedBox(height: 10),
              if (request.driverRating > 0)
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFFFCD400)),
                    const SizedBox(width: 4),
                    Text(
                      '${request.driverRating}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تقييم الكابتن',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        TaxiRatingNavigation.openIfNeeded(context, request),
                    icon: const Icon(Icons.star_border, size: 18),
                    label: const Text(
                      'قيّم الكابتن',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
            ],
            if (request.canReplayTrip && onReplayTrip != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onReplayTrip!(request),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text(
                    'إعادة الطلب',
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// تبويب تواصل معنا.
class TaxiSupportTab extends StatelessWidget {
  const TaxiSupportTab({super.key});

  void _openSupportWhatsApp() {
    AppHelpers.launchWhatsApp(
      AppHelpers.supportWhatsAppNumber,
      'مرحباً، أحتاج مساعدة في خدمة التكسي',
    );
  }

  void _openSupportCall() {
    AppHelpers.makePhoneCall(AppHelpers.supportPhoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent,
                size: 40,
                color: Color(0xFF25D366),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'تواصل مع الدعم الفني',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لديك استفسار أو مشكلة؟ تواصل مع فريق الدعم عبر واتساب أو الاتصال.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _openSupportWhatsApp,
                icon: const Icon(Icons.message, color: Colors.white),
                label: const Text(
                  'راسلنا على واتساب',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _openSupportCall,
                icon: const Icon(Icons.phone, color: AppColors.primary),
                label: const Text(
                  'اتصال بالدعم',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ساعات العمل: من ٩ صباحاً إلى ١٢ ليلاً',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
