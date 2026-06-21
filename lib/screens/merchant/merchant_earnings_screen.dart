import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';
import 'merchant_orders_screen.dart';

const _bg = Color(0xFFF2F2F7);
const _brand = Color(0xFFF5A01D);

const _shadowSoft = [
  BoxShadow(
    color: Color(0x10000000),
    blurRadius: 22,
    offset: Offset(0, 8),
  ),
];

/// الفترات الزمنية المتاحة
class _PeriodOption {
  final int days; // 0 = كل الوقت
  final String label;

  const _PeriodOption(this.days, this.label);
}

const _periods = [
  _PeriodOption(0, 'اليوم'),
  _PeriodOption(7, 'الأسبوع'),
  _PeriodOption(30, 'الشهر'),
  _PeriodOption(90, '3 أشهر'),
  _PeriodOption(180, '6 أشهر'),
  _PeriodOption(-1, 'كل الوقت'),
];

class MerchantEarningsScreen extends StatefulWidget {
  const MerchantEarningsScreen({super.key});

  @override
  State<MerchantEarningsScreen> createState() => _MerchantEarningsScreenState();
}

class _MerchantEarningsScreenState extends State<MerchantEarningsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedPeriodDays = 30; // الشهر افتراضياً
  late final AnimationController _chartAnim;
  late final Animation<double> _chartCurve;

  @override
  void initState() {
    super.initState();
    _chartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _chartCurve = CurvedAnimation(parent: _chartAnim, curve: Curves.easeOutCubic);
    _chartAnim.forward();
  }

  @override
  void dispose() {
    _chartAnim.dispose();
    super.dispose();
  }

  void _onPeriodChanged(int days) {
    setState(() => _selectedPeriodDays = days);
    _chartAnim
      ..reset()
      ..forward();
  }

  DateTime? _orderDate(AppProvider provider, ActiveOrder order) =>
      provider.parseOrderCreatedAtForSort(order);

  /// ترشيح الطلبات حسب الفترة
  List<ActiveOrder> _ordersInPeriod(
    List<ActiveOrder> orders,
    AppProvider provider,
    int days,
  ) {
    if (days <= 0) {
      // اليوم = 0، الأسبوع = 7، إلخ... -1 = كل الوقت
      if (days == 0) {
        // اليوم
        final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final tomorrow = todayStart.add(const Duration(days: 1));
        return orders.where((o) {
          final created = _orderDate(provider, o);
          return created != null && !created.isBefore(todayStart) && created.isBefore(tomorrow);
        }).toList();
      }
      if (days == -1) return orders; // كل الوقت
      return orders;
    }
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return orders.where((o) {
      final created = _orderDate(provider, o);
      return created != null && !created.isBefore(cutoff);
    }).toList();
  }

  int _sumPrices(Iterable<ActiveOrder> orders) =>
      orders.fold<int>(0, (sum, o) => sum + o.price);

  _PeriodStats _periodStats(
    List<ActiveOrder> all,
    AppProvider provider,
    DateTime start,
    DateTime end,
  ) {
    final inRange = all.where((o) {
      final d = _orderDate(provider, o);
      return d != null && !d.isBefore(start) && d.isBefore(end);
    }).toList();
    return _PeriodStats(
      orders: inRange.length,
      sales: _sumPrices(
        inRange.where((o) => o.statusKey == 'completed'),
      ),
      completed: inRange.where((o) => o.statusKey == 'completed').length,
      pending: inRange.where((o) => o.statusKey == 'pending').length,
    );
  }

  double _percentChange(int current, int previous) {
    if (previous <= 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous) * 100;
  }

  /// تجميع الطلبات حسب اليوم لرسم بياني زمني
  List<_DayBucket> _buildDayBuckets(
    List<ActiveOrder> orders,
    AppProvider provider,
    int days,
  ) {
    if (orders.isEmpty) return [];

    final now = DateTime.now();
    final int rangeDays;
    if (days == 0) rangeDays = 1; // اليوم
    else if (days == -1) {
      // كل الوقت -> نأخذ أقدم طلب
      final oldest = orders.fold<DateTime?>(null, (prev, o) {
        final d = _orderDate(provider, o);
        if (d == null) return prev;
        if (prev == null || d.isBefore(prev)) return d;
        return prev;
      });
      if (oldest == null) return [];
      rangeDays = now.difference(oldest).inDays + 1;
    } else {
      rangeDays = days;
    }

    // نأخذ على الأكثر 30 نقطة للرسم
    final step = math.max(1, (rangeDays / 30).ceil());
    final buckets = <_DayBucket>[];
    for (var i = 0; i < rangeDays; i += step) {
      final dayStart = now.subtract(Duration(days: i + step - 1));
      final dayEnd = now.subtract(Duration(days: i - 1));
      final start = DateTime(dayStart.year, dayStart.month, dayStart.day);
      final end = DateTime(dayEnd.year, dayEnd.month, dayEnd.day).add(const Duration(days: 1));

      final inRange = orders.where((o) {
        final d = _orderDate(provider, o);
        return d != null && !d.isBefore(start) && d.isBefore(end);
      }).toList();

      buckets.add(_DayBucket(
        label: _dayLabel(start, step),
        sales: _sumPrices(inRange.where((o) => o.statusKey == 'completed')),
        count: inRange.length,
      ));
    }

    return buckets.reversed.toList();
  }

  String _dayLabel(DateTime day, int step) {
    if (step >= 30) return DateFormat('MMM', 'ar').format(day);
    if (step >= 7) return DateFormat('d MMM', 'ar').format(day);
    return DateFormat('d', 'ar').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allOrders = provider.merchantIncomingOrders;
    final periodOrders = _ordersInPeriod(allOrders, provider, _selectedPeriodDays);

    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    final thisMonth = _periodStats(allOrders, provider, thisMonthStart, now);
    final lastMonth = _periodStats(
      allOrders,
      provider,
      lastMonthStart,
      thisMonthStart,
    );

    // الإحصائيات حسب الفترة المحددة
    final periodSales = _sumPrices(
      periodOrders.where((o) => o.statusKey == 'completed'),
    );
    final periodOrdersCount = periodOrders.length;
    final periodCompleted = periodOrders.where((o) => o.statusKey == 'completed').length;
    final periodPending = periodOrders.where((o) => o.statusKey == 'pending').length;

    final salesTrend = _percentChange(thisMonth.sales, lastMonth.sales);
    final ordersTrend = _percentChange(thisMonth.orders, lastMonth.orders);
    final completedTrend =
        _percentChange(thisMonth.completed, lastMonth.completed);
    final pendingTrend = _percentChange(thisMonth.pending, lastMonth.pending);

    // أعمدة الرسم البياني حسب الحالة
    final completedOrders =
        periodOrders.where((o) => o.statusKey == 'completed').toList();
    final preparingOrders = periodOrders
        .where((o) =>
            o.statusKey == 'accepted' ||
            o.statusKey == 'preparing' ||
            o.statusKey == 'cancel_requested')
        .toList();
    final deliveringOrders =
        periodOrders.where((o) => o.statusKey == 'delivering').toList();
    final pendingOrders =
        periodOrders.where((o) => o.statusKey == 'pending').toList();

    final chartBars = [
      _ChartBarData(
        label: 'مكتمل',
        value: _sumPrices(completedOrders),
        color: const Color(0xFF34C759),
      ),
      _ChartBarData(
        label: 'قيد التجهيز',
        value: _sumPrices(preparingOrders),
        color: const Color(0xFF007AFF),
      ),
      _ChartBarData(
        label: 'قيد التوصيل',
        value: _sumPrices(deliveringOrders),
        color: const Color(0xFFFFCC00),
      ),
      _ChartBarData(
        label: 'بانتظار',
        value: _sumPrices(pendingOrders),
        color: const Color(0xFFFF9500),
      ),
    ];

    // الرسم البياني الزمني (حسب الأيام)
    final dayBuckets = _buildDayBuckets(periodOrders, provider, _selectedPeriodDays);
    final maxDaySales = dayBuckets.fold<int>(0, (max, b) => math.max(max, b.sales));

    final recentOrders = [...allOrders]
      ..sort((a, b) {
        final da = _orderDate(provider, a);
        final db = _orderDate(provider, b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: _bg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const _EarningsHeader(),
            const SizedBox(height: 18),
            // اختيار الفترة
            _PeriodSelector(
              selectedDays: _selectedPeriodDays,
              onChanged: _onPeriodChanged,
            ),
            const SizedBox(height: 16),
            // الإحصائيات حسب الفترة المحددة
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.92,
              children: [
                _StatGridCard(
                  title: 'إجمالي المبيعات',
                  value: '${_formatAmount(periodSales)} د.ع',
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFFFF9500),
                  iconBg: const Color(0xFFFFF3E0),
                  trend: salesTrend,
                  sparkColor: const Color(0xFFFF9500),
                  sparkSeed: periodSales,
                ),
                _StatGridCard(
                  title: 'عدد الطلبات',
                  value: '$periodOrdersCount طلب',
                  icon: Icons.shopping_bag_rounded,
                  iconColor: const Color(0xFF007AFF),
                  iconBg: const Color(0xFFE3F2FD),
                  trend: ordersTrend,
                  sparkColor: const Color(0xFF007AFF),
                  sparkSeed: periodOrdersCount,
                ),
                _StatGridCard(
                  title: 'المكتملة',
                  value: '$periodCompleted طلب',
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF34C759),
                  iconBg: const Color(0xFFE8F5E9),
                  trend: completedTrend,
                  sparkColor: const Color(0xFF34C759),
                  sparkSeed: periodCompleted,
                ),
                _StatGridCard(
                  title: 'بانتظار',
                  value: '$periodPending طلب',
                  icon: Icons.hourglass_top_rounded,
                  iconColor: const Color(0xFFAF52DE),
                  iconBg: const Color(0xFFF3E5F5),
                  trend: pendingTrend,
                  sparkColor: const Color(0xFFAF52DE),
                  sparkSeed: periodPending,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // رسم بياني بالأعمدة (حسب الحالة)
            _SimplifiedChartCard(
              bars: chartBars,
              animation: _chartCurve,
            ),
            const SizedBox(height: 16),
            // رسم بياني زمني (حسب الأيام)
            _TimelineChartCard(
              buckets: dayBuckets,
              maxValue: maxDaySales,
              animation: _chartCurve,
            ),
            const SizedBox(height: 16),
            _RecentTransactionsCard(
              orders: recentOrders.take(5).toList(),
              displayOrderNumber: provider.displayOrderNumber,
              elapsedLabel: provider.orderElapsedLabelAr,
              onViewAll: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MerchantOrdersScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodStats {
  final int orders;
  final int sales;
  final int completed;
  final int pending;

  const _PeriodStats({
    required this.orders,
    required this.sales,
    required this.completed,
    required this.pending,
  });
}

/// بيانات يوم للرسم البياني الزمني
class _DayBucket {
  final String label;
  final int sales;
  final int count;

  const _DayBucket({
    required this.label,
    required this.sales,
    required this.count,
  });
}

String _formatAmount(int value) {
  try {
    return NumberFormat.decimalPattern('ar').format(value);
  } catch (_) {
    return value.toPrice();
  }
}

// ─────────────────────────────────────────────────────────────
// اختيار الفترة الزمنية
// ─────────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onChanged;

  const _PeriodSelector({
    required this.selectedDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _periods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final period = _periods[index];
          final isSelected = period.days == selectedDays;
          return GestureDetector(
            onTap: () => onChanged(period.days),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? _brand : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _brand : const Color(0xFFE5E5EA),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _brand.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                period.label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF636366),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────

class _EarningsHeader extends StatelessWidget {
  const _EarningsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF3B30), _brand],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _brand.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.show_chart_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الأرباح',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1C1C1E),
                  height: 1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'تابع مبيعاتك وأداء الطلبات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: Color(0xFF636366),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stat grid cards
// ─────────────────────────────────────────────────────────────

class _StatGridCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final double trend;
  final Color sparkColor;
  final int sparkSeed;

  const _StatGridCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.trend,
    required this.sparkColor,
    required this.sparkSeed,
  });

  @override
  Widget build(BuildContext context) {
    final positive = trend >= 0;
    final trendText =
        '${positive ? '+' : ''}${trend.toStringAsFixed(1)}% من الشهر الماضي';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const Spacer(),
              Icon(
                positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 16,
                color: positive ? iconColor : const Color(0xFFFF3B30),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C1C1E),
              height: 1.15,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (positive ? iconColor : const Color(0xFFFF3B30))
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trendText,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: positive ? iconColor : const Color(0xFFFF3B30),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                color: sparkColor,
                seed: sparkSeed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  final int seed;

  _SparklinePainter({required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed.clamp(1, 999999));
    final points = List<double>.generate(
      8,
      (_) => 0.25 + rng.nextDouble() * 0.75,
    );
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────
// Chart card (حسب الحالة - أعمدة)
// ─────────────────────────────────────────────────────────────

class _ChartBarData {
  final String label;
  final int value;
  final Color color;

  const _ChartBarData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _SimplifiedChartCard extends StatelessWidget {
  final List<_ChartBarData> bars;
  final Animation<double> animation;

  const _SimplifiedChartCard({
    required this.bars,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final maxBar = bars.map((b) => b.value).fold<int>(0, math.max);
    final chartMax = _niceChartMax(maxBar);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'حسب الحالة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final tick in [
                            chartMax,
                            (chartMax * 0.75).toInt(),
                            (chartMax * 0.5).toInt(),
                            (chartMax * 0.25).toInt(),
                            0
                          ])
                            Text(
                              tick == 0
                                  ? '0'
                                  : '${_formatCompact(tick)} د.ع',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 8,
                                color: Color(0xFFAEAEB2),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: const Size(double.infinity, 200),
                            painter: _ChartGridPainter(),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 4,
                              right: 4,
                              bottom: 28,
                              top: 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: bars.map((bar) {
                                final ratio = chartMax <= 0
                                    ? 0.0
                                    : (bar.value / chartMax) * animation.value;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (bar.value > 0)
                                          Text(
                                            _formatCompact(bar.value),
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF636366),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          height: 140 * ratio.clamp(0.0, 1.0),
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: bar.color,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: bars
                .map(
                  (bar) => Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: bar.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                bar.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF636366),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  int _niceChartMax(int value) {
    if (value <= 0) return 1000000;
    if (value < 10) return 10;
    final mag = math.pow(10, (math.log(value) / math.ln10).floor()).toInt();
    final step = math.max(1, mag ~/ 4);
    return ((value / step).ceil() * step);
  }

  String _formatCompact(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}M';
    if (v >= 1000) return '${(v / 1000).round()}K';
    return '$v';
  }
}

// ─────────────────────────────────────────────────────────────
// رسم بياني زمني (حسب الأيام)
// ─────────────────────────────────────────────────────────────

class _TimelineChartCard extends StatelessWidget {
  final List<_DayBucket> buckets;
  final int maxValue;
  final Animation<double> animation;

  const _TimelineChartCard({
    required this.buckets,
    required this.maxValue,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'المبيعات حسب التاريخ',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final chartMax = maxValue > 0 ? maxValue : 1;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: CustomPaint(
                        size: const Size(double.infinity, 180),
                        painter: _ChartGridPainter(),
                      ),
                    ),
                    Expanded(
                      flex: 10,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24, top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: buckets.map((bucket) {
                            final ratio = (bucket.sales / chartMax) * animation.value;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (bucket.sales > 0)
                                      Text(
                                        _formatCompact(bucket.sales),
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 7,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF636366),
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      height: 120 * ratio.clamp(0.0, 1.0),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: _brand.withValues(alpha: 0.85),
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(6),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      bucket.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 7,
                                        color: Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompact(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}M';
    if (v >= 1000) return '${(v / 1000).round()}K';
    return '$v';
  }
}

class _ChartGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5E5EA)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * (i / 4) * 0.82 + 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// Recent transactions
// ─────────────────────────────────────────────────────────────

class _RecentTransactionsCard extends StatelessWidget {
  final List<ActiveOrder> orders;
  final String Function(ActiveOrder) displayOrderNumber;
  final String Function(ActiveOrder) elapsedLabel;
  final VoidCallback onViewAll;

  const _RecentTransactionsCard({
    required this.orders,
    required this.displayOrderNumber,
    required this.elapsedLabel,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'آخر العمليات',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onViewAll,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: _brand,
                ),
                label: const Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    color: _brand,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'لا توجد عمليات بعد.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF8E8E93),
                ),
              ),
            )
          else
            ...orders.map(
              (order) => _TransactionRow(
                order: order,
                orderNumber: displayOrderNumber(order),
                elapsed: elapsedLabel(order),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final ActiveOrder order;
  final String orderNumber;
  final String elapsed;

  const _TransactionRow({
    required this.order,
    required this.orderNumber,
    required this.elapsed,
  });

  @override
  Widget build(BuildContext context) {
    final status = _transactionStatus(order);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: _brand,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.itemsNameAr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$orderNumber — $elapsed',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(style: status),
          const SizedBox(width: 10),
          Text(
            '${_formatAmount(order.price)} د.ع',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStyle {
  final String label;
  final Color bg;
  final Color fg;

  const _StatusStyle(this.label, this.bg, this.fg);
}

_StatusStyle _transactionStatus(ActiveOrder order) {
  switch (order.statusKey) {
    case 'completed':
      return const _StatusStyle(
        'مكتمل',
        Color(0xFFE8F5E9),
        Color(0xFF2E7D32),
      );
    case 'delivering':
      return const _StatusStyle(
        'قيد التوصيل',
        Color(0xFFFFF3E0),
        Color(0xFFE65100),
      );
    case 'accepted':
    case 'preparing':
    case 'cancel_requested':
      return const _StatusStyle(
        'قيد التجهيز',
        Color(0xFFE3F2FD),
        Color(0xFF1565C0),
      );
    default:
      return const _StatusStyle(
        'بانتظار',
        Color(0xFFF3E5F5),
        Color(0xFF7B1FA2),
      );
  }
}

class _StatusBadge extends StatelessWidget {
  final _StatusStyle style;

  const _StatusBadge({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: style.fg,
        ),
      ),
    );
  }
}
