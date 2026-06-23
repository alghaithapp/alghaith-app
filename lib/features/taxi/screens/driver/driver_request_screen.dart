import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/taxi_request.dart';
import '../../providers/taxi_provider.dart';
import '../../widgets/taxi_type_image.dart';
import '../../utils/taxi_driver_request_actions.dart';

/// شاشة طلبات السائق الواردة — تقرأ من TaxiProvider
class DriverRequestScreen extends StatelessWidget {
  const DriverRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taxiProvider = context.watch<TaxiProvider>();
    final pending = taxiProvider.incomingRequests;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text(
          'الطلبات الواردة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<TaxiProvider>().fetchIncomingRequests(),
          ),
        ],
      ),
      body: pending.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              itemBuilder: (context, i) =>
                  _RequestCard(request: pending[i]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.bell_slash, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'لا توجد طلبات واردة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'ستظهر هنا طلبات التكسي الجديدة تلقائياً',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  final TaxiRequest request;
  const _RequestCard({required this.request});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  @override
  Widget build(BuildContext context) {
    final req = widget.request;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: const Border(
          top: BorderSide(color: AppColors.accent, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
                const Icon(Icons.notifications_active_rounded,
                    color: AppColors.accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'طلب جديد — ${req.requestNumber}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TaxiTypeImage(
                  type: req.taxiType,
                  width: 40,
                  height: 40,
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    req.rideTypeAr,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // اسم الزبون
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  req.customerNameAr,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // نقطة الانطلاق
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.trip_origin_rounded,
                    size: 16, color: Colors.black),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.pickupAddressAr,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // نقطة الوصول
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.flag_rounded,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.dropoffAddressAr,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // الأجرة
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'الأجرة المقدرة',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    '${req.fare} د.ع',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            if ((req.noteAr ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.notes_rounded,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      req.noteAr ?? '',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),

            // أزرار رفض / قبول
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isRejecting || _isAccepting
                        ? null
                        : () async {
                            setState(() => _isRejecting = true);
                            await handleDriverRejectRequest(context, req);
                            if (mounted) {
                              setState(() => _isRejecting = false);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: _isRejecting
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.red),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close_rounded,
                                    color: Colors.red, size: 20),
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
                    onTap: _isAccepting || _isRejecting
                        ? null
                        : () async {
                            setState(() => _isAccepting = true);
                            await handleDriverAcceptRequest(context, req);
                            if (mounted) {
                              setState(() => _isAccepting = false);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
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
                      child: _isAccepting
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 20),
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
}
