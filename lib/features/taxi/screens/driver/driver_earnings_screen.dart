import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/taxi_provider.dart';
import '../../models/taxi_request.dart';

/// شاشة أرباح السائق — تعرض إجمالي الأرباح وقائمة الرحلات المكتملة
class DriverEarningsScreen extends StatelessWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaxiProvider>();
    final completedTrips = provider.completedTrips;
    final todayEarnings = provider.todayEarnings;
    final weeklyEarnings = provider.weeklyEarnings;
    final monthlyEarnings = provider.monthlyEarnings;
    final totalEarnings = provider.totalEarnings;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text(
          'الأرباح',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بطاقات الإحصائيات
          _buildStatsGrid(
            todayEarnings,
            weeklyEarnings,
            monthlyEarnings,
            totalEarnings,
          ),
          const SizedBox(height: 16),

          // ملخص الرحلات
          _buildTripsSummary(completedTrips),
          const SizedBox(height: 20),

          // عنوان قائمة الرحلات
          const Text(
            'آخر الرحلات المكتملة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),

          // قائمة الرحلات المكتملة
          if (completedTrips.isEmpty)
            _buildEmptyState()
          else
            ...completedTrips.take(20).map(
                  (trip) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompletedTripTile(trip: trip),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    int today,
    int week,
    int month,
    int total,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _StatCard(
          label: 'أرباح اليوم',
          value: '$today د.ع',
          color: AppColors.accent,
          icon: Icons.today_rounded,
        ),
        _StatCard(
          label: 'أرباح الأسبوع',
          value: '$week د.ع',
          color: AppColors.success,
          icon: Icons.calendar_view_week_rounded,
        ),
        _StatCard(
          label: 'أرباح الشهر',
          value: '$month د.ع',
          color: Colors.blue,
          icon: Icons.calendar_month_rounded,
        ),
        _StatCard(
          label: 'الإجمالي',
          value: '$total د.ع',
          color: Colors.black87,
          icon: Icons.account_balance_wallet_rounded,
        ),
      ],
    );
  }

  Widget _buildTripsSummary(List<TaxiRequest> completedTrips) {
    final totalFare = completedTrips.fold<int>(
      0,
      (sum, trip) => sum + trip.fare,
    );
    final avgFare =
        completedTrips.isEmpty ? 0 : (totalFare / completedTrips.length).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'عدد الرحلات المكتملة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${completedTrips.length}',
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
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'متوسط الأجرة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$avgFare د.ع',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.local_taxi_rounded,
            size: 48,
            color: AppColors.accent,
          ),
          const SizedBox(height: 12),
          const Text(
            'لا توجد رحلات مكتملة بعد',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'عند إتمام رحلاتك ستظهر هنا مع تفاصيل الأرباح',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة إحصاء فردية
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              Icon(icon, color: color.withValues(alpha: 0.5), size: 18),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// عنصر رحلة مكتملة في القائمة
class _CompletedTripTile extends StatelessWidget {
  final TaxiRequest trip;

  const _CompletedTripTile({required this.trip});

  @override
  Widget build(BuildContext context) {
    final isSuper = trip.taxiType == TaxiType.superTaxiType;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // أيقونة نوع الخدمة
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSuper
                  ? Colors.blue.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isSuper ? Icons.star_rounded : Icons.electric_car_rounded,
              color: isSuper ? Colors.blue : AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // معلومات الرحلة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      trip.taxiTypeLabelAr,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: isSuper ? Colors.blue : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trip.requestNumber,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${trip.pickupAddress} → ${trip.dropoffAddress}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                if (trip.completedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${trip.distanceKm.toStringAsFixed(1)} كم',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10,
                        color: Color(0xFFBDBDBD),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // السعر
          Text(
            '${trip.fare} د.ع',
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
  }
}
