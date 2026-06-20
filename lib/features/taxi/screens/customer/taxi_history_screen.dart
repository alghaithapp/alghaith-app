import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/taxi_request.dart';
import '../../providers/taxi_provider.dart';

/// شاشة تاريخ الرحلات — قائمة بالرحلات السابقة
class TaxiHistoryScreen extends StatefulWidget {
  const TaxiHistoryScreen({super.key});

  @override
  State<TaxiHistoryScreen> createState() => _TaxiHistoryScreenState();
}

class _TaxiHistoryScreenState extends State<TaxiHistoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final provider = context.read<TaxiProvider>();
    await provider.loadHistory();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String statusKey) {
    switch (statusKey) {
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'accepted':
        return 'مقبول';
      case 'pending':
        return 'قيد الانتظار';
      default:
        return statusKey;
    }
  }

  Color _statusColor(String statusKey) {
    switch (statusKey) {
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'cancelled':
        return const Color(0xFFC62828);
      case 'accepted':
        return const Color(0xFF145B66);
      default:
        return const Color(0xFF666666);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تاريخ الرحلات'),
          centerTitle: true,
        ),
        body: Consumer<TaxiProvider>(
          builder: (context, provider, _) {
            final history = provider.completedRequests;

            if (history.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد رحلات سابقة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
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
              onRefresh: _loadHistory,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final request = history[index];
                  return _TripCard(
                    request: request,
                    formatDate: _formatDate,
                    statusLabel: _statusLabel,
                    statusColor: _statusColor,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── بطاقة الرحلة ──
class _TripCard extends StatelessWidget {
  final TaxiRequest request;
  final String Function(DateTime?) formatDate;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;

  const _TripCard({
    required this.request,
    required this.formatDate,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusKey = request.statusKey;
    final statusText = statusLabel(statusKey);
    final color = statusColor(statusKey);
    final isCompleted = statusKey == 'completed';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // السطر الأول: رقم الطلب + التاريخ
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  formatDate(request.completedAt),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // المسافة + السعر + الحالة
            Row(
              children: [
                // المسافة
                Row(
                  children: [
                    const Icon(Icons.straighten,
                        size: 16, color: Color(0xFF666666)),
                    const SizedBox(width: 4),
                    Text(
                      '${request.distanceKm.toStringAsFixed(1)} كم',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // السعر
                Row(
                  children: [
                    const Icon(Icons.payments,
                        size: 16, color: Color(0xFF145B66)),
                    const SizedBox(width: 4),
                    Text(
                      '${request.fare} د.ع',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF145B66),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // الحالة
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // تقييم السائق
            if (isCompleted && request.driverRating > 0)
              Row(
                children: [
                  const Icon(Icons.star,
                      size: 16, color: Color(0xFFFCD400)),
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
                    'تقييم السائق',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              )
            else if (isCompleted)
              Row(
                children: [
                  const Icon(Icons.star_border,
                      size: 16, color: Color(0xFF666666)),
                  const SizedBox(width: 4),
                  Text(
                    'لم يتم التقييم',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),

            // معلومات السائق إن وجدت
            if (request.driverName != null &&
                request.driverName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.person,
                        size: 14, color: Colors.grey[400]),
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
                      Icon(Icons.directions_car,
                          size: 14, color: Colors.grey[400]),
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
              ),
          ],
        ),
      ),
    );
  }
}
