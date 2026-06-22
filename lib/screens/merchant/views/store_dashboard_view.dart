import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/app_models.dart';
import '../../../models/app_notification.dart';
import '../../../utils/extensions.dart';
import '../merchant_notifications_screen.dart';
import '../merchant_orders_screen.dart';
import '../merchant_profile_screen.dart';
import '../order_details_screen.dart';
import '../widgets/shared_dashboard_widgets.dart';

const _brand = Color(0xFFF5A01D);

class StoreDashboardView extends StatelessWidget {
  final AppProvider provider;
  final String storeName;
  final String description;
  final String address;
  final String ratingLabel;
  final List<AppNotificationItem> alerts;
  final List<ActiveOrder> recentOrders;
  final int todaySales;

  const StoreDashboardView({
    super.key,
    required this.provider,
    required this.storeName,
    required this.description,
    required this.address,
    required this.ratingLabel,
    required this.alerts,
    required this.recentOrders,
    required this.todaySales,
  });

  @override
  Widget build(BuildContext context) {
    final labels = provider.merchantActiveLabels;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _StoreHeroCard(
              storeName: storeName,
              description: description,
              address: address,
              isOpen: provider.isMerchantStoreOpen,
              onToggleOpen: provider.toggleMerchantOpenStatus,
              profileImage: provider.merchantProfileImageBase64,
              coverImage: provider.merchantCoverImage,
              productsCount: provider.merchantProductCount,
              ratingLabel: ratingLabel,
              itemLabel: labels.itemPluralAr,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: MerchantProfilePillButton(
              label: 'عرض الملف الكامل للمتجر',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MerchantProfileScreen(),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: const MerchantSectionHeader(
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
            child: MerchantSectionHeader(
              title: 'آخر الطلبات',
              icon: Icons.receipt_long_rounded,
              actionLabel: 'عرض الكل',
              onAction: () => Navigator.of(context).push(
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
    );
  }
}

class _StoreHeroCard extends StatelessWidget {
  final String storeName;
  final String description;
  final String address;
  final bool isOpen;
  final VoidCallback onToggleOpen;
  final String? profileImage;
  final String coverImage;
  final int productsCount;
  final String ratingLabel;
  final String itemLabel;

  const _StoreHeroCard({
    required this.storeName,
    required this.description,
    required this.address,
    required this.isOpen,
    required this.onToggleOpen,
    required this.profileImage,
    required this.coverImage,
    required this.productsCount,
    required this.ratingLabel,
    required this.itemLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F1E36)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        image: merchantCoverDecoration(coverImage),
        boxShadow: [
          BoxShadow(
            color: _brand.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
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
                    MerchantStoreStatusSwitch(
                      isOpen: isOpen,
                      onToggle: onToggleOpen,
                    ),
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
              const SizedBox(width: 8),
              Expanded(
                child: MerchantHeroMiniStat(
                  label: 'التقييم',
                  value: ratingLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


