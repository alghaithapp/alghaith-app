import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/app_provider.dart';
import '../../../../utils/chat_navigation.dart';
import '../../../../utils/helpers.dart';
import '../../models/taxi_request.dart';

/// شاشة الرحلات النشطة للسائق — تقرأ من AppProvider مباشرة
class DriverTripScreen extends StatelessWidget {
  const DriverTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final active = provider.visibleTaxiActiveRequests;
    final completed = provider.visibleTaxiCompletedRequests;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.scaffold,
        appBar: AppBar(
          title: const Text(
            'الرحلات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => provider.refreshDriverTaxiRequests(),
            ),
          ],
          bottom: TabBar(
            labelStyle: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontFamily: 'Cairo'),
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'نشطة (${active.length})'),
              Tab(text: 'مكتملة (${completed.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ActiveTripsTab(active: active),
            _CompletedTripsTab(completed: completed),
          ],
        ),
      ),
    );
  }
}

// ── تبويب الرحلات النشطة ──────────────────────────────────────────────────

class _ActiveTripsTab extends StatelessWidget {
  final List<TaxiRequest> active;
  const _ActiveTripsTab({required this.active});

  @override
  Widget build(BuildContext context) {
    if (active.isEmpty) {
      return const Center(
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
                  color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'بعد قبول طلب ستظهر الرحلة هنا',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: active.length,
      itemBuilder: (context, i) => _ActiveTripCard(request: active[i]),
    );
  }
}

class _ActiveTripCard extends StatefulWidget {
  final TaxiRequest request;
  const _ActiveTripCard({required this.request});

  @override
  State<_ActiveTripCard> createState() => _ActiveTripCardState();
}

class _ActiveTripCardState extends State<_ActiveTripCard> {
  bool _isBusy = false;

  String get _nextActionLabel {
    switch (widget.request.statusKey) {
      case 'accepted':
        return 'في الطريق للزبون';
      case 'on_way':
        return 'وصلت للموقع';
      case 'arrived':
        return 'استلام الزبون';
      case 'picked_up':
        return 'تم الوصول — إنهاء الرحلة';
      case 'cancel_requested':
        return 'موافقة الإلغاء';
      default:
        return '';
    }
  }

  Color get _statusColor {
    switch (widget.request.statusKey) {
      case 'accepted':
        return Colors.teal;
      case 'on_way':
        return Colors.lightBlue;
      case 'arrived':
        return Colors.indigo;
      case 'picked_up':
        return AppColors.success;
      case 'cancel_requested':
        return Colors.orange;
      default:
        return AppColors.accent;
    }
  }

  Future<void> _openNavigationFor(TaxiRequest req) async {
    LatLng? target;
    if (req.statusKey == 'accepted' || req.statusKey == 'on_way') {
      if (req.pickupLat != 0 && req.pickupLng != 0) {
        target = LatLng(req.pickupLat, req.pickupLng);
      }
    } else if (req.statusKey == 'picked_up') {
      if (req.dropoffLat != 0 && req.dropoffLng != 0) {
        target = LatLng(req.dropoffLat, req.dropoffLng);
      }
    }
    if (target == null || !mounted) return;
    await AppHelpers.openExternalMapNavigation(
      context: context,
      latitude: target.latitude,
      longitude: target.longitude,
    );
  }

  Future<void> _advance(AppProvider provider) async {
    if (_isBusy) return;
    final req = widget.request;

    if (req.statusKey == 'accepted' || req.statusKey == 'picked_up') {
      await _openNavigationFor(req);
    }

    setState(() => _isBusy = true);
    final id = widget.request.id;
    switch (widget.request.statusKey) {
      case 'accepted':
        await provider.markTaxiOnWay(id);
        break;
      case 'on_way':
        await provider.markTaxiArrived(id);
        break;
      case 'arrived':
        await provider.markTaxiPickedUp(id);
        break;
      case 'picked_up':
        await provider.completeTaxiRequest(id);
        break;
      case 'cancel_requested':
        await provider.approveTaxiCancellationByDriver(id);
        break;
    }
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final req = widget.request;
    final isCancelRequested = req.statusKey == 'cancel_requested';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          right: BorderSide(color: _statusColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  req.requestNumber,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    req.statusAr,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // الزبون
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${req.customerNameAr} • ${req.fare} د.ع',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  ),
                ),
                if (req.customerPhone.trim().isNotEmpty)
                  IconButton(
                    tooltip: 'مراسلة الزبون',
                    onPressed: () => ChatNavigation.openTaxiChat(
                      context,
                      requestId: req.id,
                      otherPartyName: req.customerNameAr,
                      receiverPhone: req.customerPhone,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // العناوين
            Row(
              children: [
                const Icon(Icons.trip_origin_rounded,
                    size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(req.pickupAddressAr,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.flag_rounded,
                    size: 14, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(req.dropoffAddressAr,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),

            if (req.assignedDriverName != null) ...[
              const SizedBox(height: 4),
              Text(
                'السائق: ${req.assignedDriverName}',
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 11, color: Colors.grey),
              ),
            ],

            if (isCancelRequested) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'الزبون طلب إلغاء الرحلة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // أزرار الإجراء
            if (isCancelRequested)
              Row(
                children: [
                  Expanded(
                    child: _ActionBtn(
                      label: 'موافقة الإلغاء',
                      color: Colors.red,
                      isLoading: _isBusy,
                      onTap: () => _advance(provider),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionBtn(
                      label: 'رفض الإلغاء',
                      color: AppColors.success,
                      isLoading: false,
                      onTap: () =>
                          provider.rejectTaxiCancellationByDriver(req.id),
                    ),
                  ),
                ],
              )
            else if (_nextActionLabel.isNotEmpty)
              Column(
                children: [
                  if (req.statusKey == 'accepted' ||
                      req.statusKey == 'on_way' ||
                      req.statusKey == 'picked_up')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _isBusy ? null : () => _openNavigationFor(req),
                          icon: const Icon(Icons.navigation_rounded),
                          label: Text(
                            req.statusKey == 'picked_up'
                                ? 'فتح المسار إلى الوجهة'
                                : 'فتح المسار إلى الزبون',
                            style: const TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      ),
                    ),
                  _ActionBtn(
                    label: _nextActionLabel,
                    color: _statusColor,
                    isLoading: _isBusy,
                    onTap: () => _advance(provider),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── تبويب الرحلات المكتملة ────────────────────────────────────────────────

class _CompletedTripsTab extends StatelessWidget {
  final List<TaxiRequest> completed;
  const _CompletedTripsTab({required this.completed});

  @override
  Widget build(BuildContext context) {
    if (completed.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.checkmark_seal, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد رحلات مكتملة بعد',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completed.length,
      itemBuilder: (context, i) {
        final req = completed[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                      req.customerNameAr,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${req.pickupAddressAr} → ${req.dropoffAddressAr}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '${req.fare} د.ع',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── زر الإجراء ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
