import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/app_models.dart';
import '../../../models/app_notification.dart';
import '../../../utils/extensions.dart';
import '../../../utils/merchant_service_labels.dart';
import 'merchant_notifications_screen.dart';
import 'merchant_orders_screen.dart';
import 'merchant_profile_screen.dart';
import 'widgets/shared_dashboard_widgets.dart';

const _bg = Color(0xFFF2F2F7);
const _brand = Color(0xFFF5A01D);

class MerchantDashboardScreen extends StatelessWidget {
  const MerchantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.merchantActiveLabels;
    final recentOrders = provider.merchantIncomingOrders.take(3).toList();
    final alerts = provider.notifications.take(3).toList();
    final storeName = provider.merchantStoreName.trim().isNotEmpty
        ? provider.merchantStoreName
        : 'حساب التاجر';
    final description = provider.merchantDescription.trim().isNotEmpty
        ? provider.merchantDescription
        : labels.dashboardIntroAr;
    final address = provider.merchantAddress.trim().isNotEmpty
        ? provider.merchantAddress
        : '—';
    final rating = provider.merchantRating;
    final ratingLabel = rating > 0 ? rating.toStringAsFixed(1) : '—';
    final todaySales = _todayCompletedSales(provider.merchantIncomingOrders);
    final uniqueCustomersCount = _uniqueCustomersCount(provider.merchantIncomingOrders);
    final usesOrderFlow =
        merchantServiceUsesOrderFlow(provider.merchantActiveServiceId);

    return ColoredBox(
      color: _bg,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _HeroCard(
                storeName: storeName,
                description: description,
                address: address,
                isOpen: provider.isMerchantStoreOpen,
                onToggleOpen: provider.toggleMerchantOpenStatus,
                profileImage: provider.merchantProfileImageBase64,
                coverImage: provider.merchantCoverImage,
                productsCount: provider.merchantProductCount,
                ordersCount: provider.merchantOrdersCount,
                customersCount: uniqueCustomersCount,
                ratingLabel: ratingLabel,
                itemLabel: labels.itemPluralAr,
                showOrderStats: usesOrderFlow,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: MerchantProfilePillButton(
                label: 'عرض الملف الكامل',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MerchantProfileScreen(),
                  ),
                ),
              ),
            ),
          ),
          if (provider.merchantHasMultipleServices)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ActiveServiceChips(
                  serviceIds: provider.merchantServiceIds,
                  activeId: provider.merchantActiveServiceId,
                  onSelected: provider.setMerchantActiveService,
                ),
              ),
            ),
          if (usesOrderFlow) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: MerchantSectionHeader(
                title: 'إحصائيات المتجر',
                icon: Icons.analytics_outlined,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MerchantStatCard(
                          label: 'إجمالي ${labels.itemPluralAr}',
                          value: '${provider.merchantProductCount}',
                          icon: Icons.inventory_2_rounded,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MerchantStatCard(
                          label: 'طلبات جديدة',
                          value: '${provider.merchantPendingOrdersCount}',
                          icon: Icons.notifications_active_rounded,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: MerchantStatCard(
                          label: 'طلبات مكتملة',
                          value: '${provider.merchantCompletedOrdersCount}',
                          icon: Icons.check_circle_rounded,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MerchantStatCard(
                          label: 'مبيعات اليوم',
                          value: '${todaySales.toPrice()} د.ع',
                          icon: Icons.payments_rounded,
                          color: _brand,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ] else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: MerchantSectionHeader(
                  title: 'إحصائيات ${labels.storeLabelAr}',
                  icon: Icons.analytics_outlined,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: MerchantStatCard(
                        label: 'إجمالي ${labels.itemPluralAr}',
                        value: '${provider.merchantProductCount}',
                        icon: Icons.home_work_rounded,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MerchantStatCard(
                        label: 'التقييم',
                        value: ratingLabel,
                        icon: Icons.star_rounded,
                        color: _brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.primary.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'بيع العقار يتم عبر تواصل الزبون معك داخل التطبيق — راجع «المحادثات» من المزيد.',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (usesOrderFlow) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
              child: _OrdersHeaderStat(
                ordersCount: recentOrders.length,
                customersCount: uniqueCustomersCount,
                onViewAll: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MerchantOrdersScreen(),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: recentOrders.isEmpty
                  ? const MerchantOrdersEmptyCard()
                  : MerchantOrdersListCard(
                      orders: recentOrders,
                      displayOrderNumber: provider.displayOrderNumber,
                    ),
            ),
          ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
              child: MerchantSectionHeader(
                title: 'التنبيهات المهمة',
                icon: Icons.notifications_rounded,
                actionLabel: 'عرض الكل',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MerchantNotificationsScreen(),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: MerchantAlertsCard(alerts: alerts),
            ),
          ),
        ],
      ),
    );
  }

  static int _todayCompletedSales(List<ActiveOrder> orders) {
    final now = DateTime.now();
    bool isToday(ActiveOrder o) {
      final raw = o.createdAt?.trim();
      if (raw == null || raw.isEmpty) return false;
      final dt = DateTime.tryParse(raw)?.toLocal();
      if (dt == null) return false;
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }

    return orders
        .where((o) => o.statusKey == 'completed' && isToday(o))
        .fold<int>(0, (sum, o) => sum + o.price);
  }

  static int _uniqueCustomersCount(List<ActiveOrder> orders) {
    return orders.map((o) => o.customerNameAr.trim()).toSet().length;
  }
}

class _HeroCard extends StatelessWidget {
  final String storeName;
  final String description;
  final String address;
  final bool isOpen;
  final VoidCallback onToggleOpen;
  final String? profileImage;
  final String coverImage;
  final int productsCount;
  final int ordersCount;
  final int customersCount;
  final String ratingLabel;
  final String itemLabel;
  final bool showOrderStats;

  const _HeroCard({
    required this.storeName,
    required this.description,
    required this.address,
    required this.isOpen,
    required this.onToggleOpen,
    required this.profileImage,
    required this.coverImage,
    required this.productsCount,
    required this.ordersCount,
    required this.customersCount,
    required this.ratingLabel,
    required this.itemLabel,
    this.showOrderStats = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A0A0A), Color(0xFF1F1F1F), Color(0xFF2A1515)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          boxShadow: [
            BoxShadow(
              color: _brand.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (merchantCoverDecoration(coverImage) != null)
              Positioned.fill(
                child: buildMerchantCoverImage(coverImage),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MerchantStoreAvatar(imageData: profileImage),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Cairo',
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.45,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 11,
                                      height: 1.4,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            MerchantStoreStatusSwitch(isOpen: isOpen, onToggle: onToggleOpen),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: MerchantHeroMiniStat(
                          label: itemLabel,
                          value: '$productsCount',
                        ),
                      ),
                      if (showOrderStats) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: MerchantHeroMiniStat(
                            label: 'الطلبات',
                            value: '$ordersCount',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: MerchantHeroMiniStat(
                            label: 'عميل',
                            value: '$customersCount',
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: MerchantHeroMiniStat(
                            label: 'التقييم',
                            value: ratingLabel,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _OrdersHeaderStat extends StatelessWidget {
  final int ordersCount;
  final int customersCount;
  final VoidCallback onViewAll;

  const _OrdersHeaderStat({
    required this.ordersCount,
    required this.customersCount,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: _brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'آخر الطلبات',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _MiniChip(
                      icon: Icons.receipt_rounded,
                      label: '$ordersCount طلب',
                    ),
                    const SizedBox(width: 12),
                    _MiniChip(
                      icon: Icons.person_rounded,
                      label: '$customersCount عميل',
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onViewAll,
            child: const Text(
              'عرض الكل',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: _brand,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _brand),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveServiceChips extends StatelessWidget {
  final List<String> serviceIds;
  final String activeId;
  final Future<void> Function(String) onSelected;

  const _ActiveServiceChips({
    required this.serviceIds,
    required this.activeId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: serviceIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final serviceId = serviceIds[index];
          final chipLabels = merchantServiceLabels(serviceId);
          final selected = serviceId == activeId;
          return ChoiceChip(
            label: Text(
              chipLabels.storeLabelAr,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            selected: selected,
            onSelected: (_) => onSelected(serviceId),
            selectedColor: _brand,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF1C1C1E),
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          );
        },
      ),
    );
  }
}


