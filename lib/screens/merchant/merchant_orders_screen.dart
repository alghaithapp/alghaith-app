import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';
import 'merchant_notifications_screen.dart';
import 'order_details_screen.dart';

const _bg = Color(0xFFF2F2F7);
const _brand = Color(0xFFF5A01D);

const _shadowSoft = [
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 24,
    offset: Offset(0, 10),
  ),
];

const _shadowPill = [
  BoxShadow(
    color: Color(0x1AE60012),
    blurRadius: 12,
    offset: Offset(0, 4),
  ),
];

class MerchantOrdersScreen extends StatefulWidget {
  /// When embedded in [MerchantShell], use this to return to the dashboard tab.
  final VoidCallback? onNavigateHome;

  const MerchantOrdersScreen({super.key, this.onNavigateHome});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  int _selectedTab = 0;
  String _searchQuery = '';
  _OrdersSort _sort = _OrdersSort.newest;

  List<ActiveOrder> _ordersForTab(AppProvider provider) {
    final all = provider.merchantIncomingOrders;
    List<ActiveOrder> list;
    switch (_selectedTab) {
      case 0:
        list = all.where((o) => o.statusKey == 'pending').toList();
        break;
      case 1:
        list = all
            .where((o) =>
                o.statusKey == 'accepted' ||
                o.statusKey == 'cancel_requested' ||
                o.statusKey == 'adjustment_pending')
            .toList();
        break;
      case 2:
        list = all.where((o) => o.statusKey == 'completed').toList();
        break;
      default:
        list = all.where((o) => o.statusKey == 'cancelled').toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((o) {
        final num = provider.displayOrderNumber(o).toLowerCase();
        final name = o.customerNameAr.toLowerCase();
        final items = o.itemsNameAr.toLowerCase();
        return num.contains(q) || name.contains(q) || items.contains(q);
      }).toList();
    }
    list.sort((a, b) {
      final ta = provider.parseOrderCreatedAtForSort(a);
      final tb = provider.parseOrderCreatedAtForSort(b);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return _sort == _OrdersSort.newest
          ? tb.compareTo(ta)
          : ta.compareTo(tb);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final orders = _ordersForTab(provider);
    final pendingCount = provider.merchantPendingOrdersCount;
    final approvalCount = provider.merchantIncomingOrders
        .where((o) =>
            o.statusKey == 'accepted' ||
            o.statusKey == 'cancel_requested' ||
            o.statusKey == 'adjustment_pending')
        .length;
    final completedCount = provider.merchantIncomingOrders
        .where((o) => o.statusKey == 'completed')
        .length;
    final cancelledCount = provider.merchantIncomingOrders
        .where((o) => o.statusKey == 'cancelled')
        .length;
    final canPop = Navigator.canPop(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: _bg,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _PremiumHeader(
                pendingCount: pendingCount,
                showBack: canPop,
                showHome: false,
                onBack: canPop ? () => Navigator.pop(context) : null,
                onHome: widget.onNavigateHome,
                onSearch: () => _openSearchSheet(context),
                onFilter: () => _openFilterSheet(context),
                onNotifications: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MerchantNotificationsScreen(),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _StatsOverviewCard(
                  pending: pendingCount,
                  approval: approvalCount,
                  completed: completedCount,
                  cancelled: cancelledCount,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _FilterTabs(
                  selectedIndex: _selectedTab,
                  onSelected: (i) => setState(() => _selectedTab = i),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'نتائج البحث: "$_searchQuery"',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: Color(0xFF636366),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _searchQuery = ''),
                        child: const Text(
                          'مسح',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: _brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (orders.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _OrdersEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList.separated(
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _PremiumOrderCard(
                      order: order,
                      onDetails: () => _openDetails(context, provider, order),
                      onAccept: () => provider.updateOrderStatus(
                        order.id,
                        'accepted',
                        'تمت الموافقة',
                        'Approved',
                      ),
                      onReject: () => _rejectOrder(context, provider, order),
                      onComplete: () {
                        if (order.statusKey != 'accepted') return;
                        provider.updateOrderStatus(
                          order.id,
                          'completed',
                          'مكتمل',
                          'Completed',
                        );
                      },
                      onApproveCancelRequest: () {
                        provider.resolveCustomerCancellationRequestByMerchant(
                          order.id,
                          approve: true,
                        );
                      },
                      onRejectCancelRequest: () {
                        provider.resolveCustomerCancellationRequestByMerchant(
                          order.id,
                          approve: false,
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetails(
    BuildContext context,
    AppProvider provider,
    ActiveOrder order,
  ) async {
    await provider.markMerchantOrderAsRead(order.id);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
    );
  }

  Future<void> _rejectOrder(
    BuildContext context,
    AppProvider provider,
    ActiveOrder order,
  ) async {
    final reason = await _showRejectReasonDialog(context);
    if (reason == null || reason.trim().isEmpty) return;
    provider.updateOrderStatus(
      order.id,
      'cancelled',
      'تم رفض الطلب',
      'Rejected',
      noteAr: 'سبب الرفض: ${reason.trim()}',
      noteEn: 'Rejected reason: ${reason.trim()}',
    );
  }

  Future<void> _openSearchSheet(BuildContext context) async {
    final controller = TextEditingController(text: _searchQuery);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GlassSheet(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'بحث في الطلبات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'رقم الطلب، اسم الزبون، أو المنتجات',
                  hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: _brand),
                ),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                style: AppButtonStyles.accentFilled(
                  borderRadius: BorderRadius.circular(16),
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text(
                  'بحث',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (result != null) setState(() => _searchQuery = result);
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<_OrdersSort>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GlassSheet(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'ترتيب الطلبات',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _SortTile(
                label: 'الأحدث أولاً',
                selected: _sort == _OrdersSort.newest,
                onTap: () => Navigator.pop(ctx, _OrdersSort.newest),
              ),
              _SortTile(
                label: 'الأقدم أولاً',
                selected: _sort == _OrdersSort.oldest,
                onTap: () => Navigator.pop(ctx, _OrdersSort.oldest),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _sort = picked);
  }

  Future<String?> _showRejectReasonDialog(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'سبب رفض الطلب',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'اكتب سبب الرفض للزبون',
            hintStyle: const TextStyle(fontFamily: 'Cairo'),
            filled: true,
            fillColor: _bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: AppButtonStyles.accentFilled(),
            child: const Text(
              'تأكيد الرفض',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }
}

enum _OrdersSort { newest, oldest }

// ─────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────

class _PremiumHeader extends StatelessWidget {
  final int pendingCount;
  final bool showBack;
  final bool showHome;
  final VoidCallback? onBack;
  final VoidCallback? onHome;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onNotifications;

  const _PremiumHeader({
    required this.pendingCount,
    required this.showBack,
    required this.showHome,
    required this.onBack,
    required this.onHome,
    required this.onSearch,
    required this.onFilter,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.white.withValues(alpha: 0.92),
                _bg.withValues(alpha: 0.4),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (showBack || showHome) ...[
                    _HeaderIconButton(
                      icon: showBack
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.home_rounded,
                      onTap: showBack ? onBack! : onHome!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _HeaderIconButton(
                    icon: Icons.search_rounded,
                    onTap: onSearch,
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    icon: Icons.tune_rounded,
                    onTap: onFilter,
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    icon: Icons.notifications_rounded,
                    onTap: onNotifications,
                    badge: pendingCount > 0 ? pendingCount : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الطلبات',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1C1C1E),
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'إدارة طلبات المتجر واتخاذ الإجراءات بسرعة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Color(0xFF636366),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 0,
          shadowColor: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: _shadowSoft,
                color: Colors.white,
              ),
              child: Icon(icon, color: const Color(0xFF1C1C1E), size: 22),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -4,
            left: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _brand,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _shadowPill,
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                badge! > 99 ? '99+' : '$badge',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Statistics
// ─────────────────────────────────────────────────────────────

class _StatsOverviewCard extends StatelessWidget {
  final int pending;
  final int approval;
  final int completed;
  final int cancelled;

  const _StatsOverviewCard({
    required this.pending,
    required this.approval,
    required this.completed,
    required this.cancelled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: _shadowSoft,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatMetric(
              title: 'جديد',
              description: 'بانتظار الموافقة',
              value: '$pending',
              color: const Color(0xFFFF9500),
              icon: Icons.fiber_new_rounded,
            ),
          ),
          Expanded(
            child: _StatMetric(
              title: 'موافقة / إلغاء',
              description: 'مقبول أو طلب إلغاء',
              value: '$approval',
              color: const Color(0xFFAF52DE),
              icon: Icons.sync_alt_rounded,
            ),
          ),
          Expanded(
            child: _StatMetric(
              title: 'مكتمل',
              description: 'تم بنجاح',
              value: '$completed',
              color: const Color(0xFF34C759),
              icon: Icons.check_circle_rounded,
            ),
          ),
          Expanded(
            child: _StatMetric(
              title: 'ملغي',
              description: 'ملغي أو مرفوض',
              value: '$cancelled',
              color: const Color(0xFFFF3B30),
              icon: Icons.cancel_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMetric extends StatelessWidget {
  final String title;
  final String description;
  final String value;
  final Color color;
  final IconData icon;

  const _StatMetric({
    required this.title,
    required this.description,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 8,
            color: Color(0xFF8E8E93),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Filter tabs
// ─────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _FilterTabs({
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _labels = [
    'جديد',
    'موافقة / إلغاء',
    'مكتمل',
    'ملغي',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final active = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: active ? _brand : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active
                      ? _brand
                      : const Color(0xFFE5E5EA),
                ),
                boxShadow: active ? _shadowPill : null,
              ),
              child: Text(
                _labels[index],
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : const Color(0xFF1C1C1E),
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
// Order card
// ─────────────────────────────────────────────────────────────

class _PremiumOrderCard extends StatelessWidget {
  final ActiveOrder order;
  final VoidCallback onDetails;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onComplete;
  final VoidCallback onApproveCancelRequest;
  final VoidCallback onRejectCancelRequest;

  const _PremiumOrderCard({
    required this.order,
    required this.onDetails,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
    required this.onApproveCancelRequest,
    required this.onRejectCancelRequest,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final orderNumber = provider.displayOrderNumber(order);
    final chips = _buildItemChips(order);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: _shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderNumber,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.customerNameAr,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3A3A3C),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(order: order),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            order.dateAr,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            provider.orderElapsedLabelAr(order),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: Color(0xFF8E8E93),
            ),
          ),
          if (order.statusKey == 'pending') ...[
            const SizedBox(height: 12),
            _PendingCountdownCard(order: order),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'طريقة الدفع',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _paymentLabel(order.paymentMethodAr),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'الإجمالي',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.price.toPrice()} د.ع',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _OrderActions(
            order: order,
            onDetails: onDetails,
            onAccept: onAccept,
            onReject: onReject,
            onComplete: onComplete,
            onApproveCancelRequest: onApproveCancelRequest,
            onRejectCancelRequest: onRejectCancelRequest,
          ),
        ],
      ),
    );
  }

  static String _paymentLabel(String raw) {
    final t = raw.trim();
    if (t.contains('نقد') || t.contains('كاش') || t.toLowerCase().contains('cash')) {
      return 'كاش عند الاستلام';
    }
    return 'دفع إلكتروني';
  }

  static List<Widget> _buildItemChips(ActiveOrder order) {
    final labels = <String>[];
    if (order.lineItems.isNotEmpty) {
      for (final item in order.lineItems) {
        labels.add('${item.nameAr} ×${item.quantity}');
      }
    } else if (order.itemsNameAr.trim().isNotEmpty) {
      final parts = order.itemsNameAr.split(RegExp(r'[،,]'));
      for (final part in parts) {
        final t = part.trim();
        if (t.isNotEmpty) labels.add(t);
      }
    }
    if (labels.isEmpty) {
      return [
        _ItemChip(label: '${order.itemsCount} عناصر'),
      ];
    }
    const maxVisible = 3;
    final widgets = <Widget>[];
    for (var i = 0; i < labels.length && i < maxVisible; i++) {
      widgets.add(_ItemChip(label: labels[i]));
    }
    final extra = labels.length - maxVisible;
    if (extra > 0) {
      widgets.add(_ItemChip(label: '+$extra عناصر أخرى', muted: true));
    }
    return widgets;
  }
}

class _ItemChip extends StatelessWidget {
  final String label;
  final bool muted;

  const _ItemChip({required this.label, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: muted ? _bg : const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: muted ? const Color(0xFF8E8E93) : const Color(0xFF1C1C1E),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ActiveOrder order;

  const _StatusBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    final style = _badgeStyle(order);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: style.fg,
        ),
      ),
    );
  }

  static _BadgeStyle _badgeStyle(ActiveOrder order) {
    switch (order.statusKey) {
      case 'accepted':
        return _BadgeStyle('مقبول', const Color(0xFFEDE7F6), const Color(0xFF7B1FA2));
      case 'adjustment_pending':
        return _BadgeStyle(
          'بانتظار الزبون',
          const Color(0xFFFFF3E0),
          const Color(0xFFEF6C00),
        );
      case 'cancel_requested':
        return _BadgeStyle('طلب إلغاء', const Color(0xFFF3E5F5), const Color(0xFF8E24AA));
      case 'completed':
        return _BadgeStyle('مكتمل', const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case 'cancelled':
        final rejected = order.statusAr.contains('رفض') ||
            order.noteAr.contains('رفض');
        if (rejected) {
          return _BadgeStyle('مرفوض', const Color(0xFFFFEBEE), const Color(0xFFC62828));
        }
        return _BadgeStyle('ملغي', const Color(0xFFFFEBEE), const Color(0xFFD32F2F));
      default:
        return _BadgeStyle('جديد', const Color(0xFFFFF3E0), const Color(0xFFE65100));
    }
  }
}

class _BadgeStyle {
  final String label;
  final Color bg;
  final Color fg;

  const _BadgeStyle(this.label, this.bg, this.fg);
}

class _PendingCountdownCard extends StatefulWidget {
  final ActiveOrder order;

  const _PendingCountdownCard({required this.order});

  @override
  State<_PendingCountdownCard> createState() => _PendingCountdownCardState();
}

class _PendingCountdownCardState extends State<_PendingCountdownCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final remaining = provider.pendingApprovalRemainingSeconds(widget.order);
    if (remaining == null) return const SizedBox.shrink();

    final urgent = remaining <= 120;
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final bg = urgent ? const Color(0xFFFF3B30) : const Color(0xFFFF9500);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'متبقي للقبول',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            '$minutes:$seconds',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderActions extends StatelessWidget {
  final ActiveOrder order;
  final VoidCallback onDetails;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onComplete;
  final VoidCallback onApproveCancelRequest;
  final VoidCallback onRejectCancelRequest;

  const _OrderActions({
    required this.order,
    required this.onDetails,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
    required this.onApproveCancelRequest,
    required this.onRejectCancelRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PillButton(
          label: 'تفاصيل',
          outlined: true,
          onTap: onDetails,
        ),
        if (order.statusKey == 'pending') ...[
          _PillButton(label: 'قبول', primary: true, onTap: onAccept),
          _PillButton(
            label: 'رفض',
            destructive: true,
            outlined: true,
            onTap: onReject,
          ),
        ],
        if (order.statusKey == 'accepted')
          _PillButton(label: 'إكمال الطلب', primary: true, onTap: onComplete),
        if (order.statusKey == 'cancel_requested') ...[
          _PillButton(
            label: 'الموافقة على الإلغاء',
            primary: true,
            onTap: onApproveCancelRequest,
          ),
          _PillButton(
            label: 'رفض طلب الإلغاء',
            outlined: true,
            onTap: onRejectCancelRequest,
          ),
        ],
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool outlined;
  final bool destructive;

  const _PillButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.outlined = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = _bg;
    Color fg = const Color(0xFF1C1C1E);
    Border? border = Border.all(color: const Color(0xFFE5E5EA));

    if (primary) {
      bg = _brand;
      fg = Colors.white;
      border = null;
    } else if (destructive && !outlined) {
      bg = const Color(0xFFFF3B30);
      fg = Colors.white;
      border = null;
    } else if (destructive && outlined) {
      bg = Colors.white;
      fg = const Color(0xFFFF3B30);
      border = Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.4));
    } else if (!outlined) {
      bg = const Color(0xFF1C1C1E);
      fg = Colors.white;
      border = null;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: border,
            boxShadow: primary ? _shadowPill : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty state & helpers
// ─────────────────────────────────────────────────────────────

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: _shadowSoft,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 56,
                color: const Color(0xFF8E8E93).withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا توجد طلبات هنا',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ستظهر الطلبات حسب الحالة المحددة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Color(0xFF8E8E93),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final Widget child;

  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SortTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: selected ? _brand.withValues(alpha: 0.08) : _bg,
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? _brand : const Color(0xFF1C1C1E),
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: _brand)
          : null,
    );
  }
}
