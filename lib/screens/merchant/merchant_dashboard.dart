import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';
import 'manage_products.dart';
import 'merchant_orders.dart';

class MerchantDashboard extends StatelessWidget {
  const MerchantDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isAr = appProvider.lang == 'ar';
    final labels = appProvider.merchantLabels;
    final store = appProvider.merchantStore;
    final storeName =
        store?['name'] as String? ?? appProvider.merchantStoreName;
    final storeDescription =
        store?['description'] as String? ?? appProvider.merchantDescription;
    final recentOrders = appProvider.orders.take(4).toList();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: Color(0x11000000))),
        middle: Text(
          isAr ? labels.accountTitleAr : labels.accountTitleEn,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black, Colors.grey.shade900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.storefront,
                            color: Colors.white, size: 34),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              storeDescription,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                                fontFamily: 'Cairo',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _StatusBanner(
                  isAr: isAr,
                  isOpen: appProvider.isMerchantStoreOpen,
                  onToggle: appProvider.toggleMerchantOpenStatus,
                  openTime: appProvider.merchantOpenTime,
                  closeTime: appProvider.merchantCloseTime,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _StatsGrid(
                  isAr: isAr,
                  provider: appProvider,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _QuickActions(
                  isAr: isAr,
                  menuLabel:
                      isAr ? labels.productsTitleAr : labels.productsTitleEn,
                  storeLabel: isAr ? labels.storeLabelAr : labels.storeLabelEn,
                  onManageMenu: () {
                    Navigator.of(context).push(CupertinoPageRoute(
                        builder: (_) => const ManageProducts()));
                  },
                  onOrders: () {
                    Navigator.of(context).push(CupertinoPageRoute(
                        builder: (_) => const MerchantOrders()));
                  },
                  onToggleOpen: appProvider.toggleMerchantOpenStatus,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _SectionHeader(
                  title: isAr
                      ? 'أحدث طلبات ${labels.storeLabelAr}'
                      : 'Recent ${labels.storeLabelEn} Orders',
                  subtitle: isAr
                      ? 'آخر حركة داخل ${labels.storeLabelAr}'
                      : 'Latest merchant activity',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: recentOrders.isEmpty
                  ? SliverToBoxAdapter(
                      child: _EmptyState(
                        isAr: isAr,
                        title: isAr ? 'لا توجد طلبات بعد' : 'No orders yet',
                        subtitle: isAr
                            ? 'بمجرد وصول الطلبات ستظهر هنا بشكل تفصيلي.'
                            : 'Incoming orders will appear here with full details.',
                      ),
                    )
                  : SliverList.builder(
                      itemCount: recentOrders.length,
                      itemBuilder: (context, index) {
                        final order = recentOrders[index];
                        return _OrderPreviewCard(order: order, isAr: isAr);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool isAr;
  final bool isOpen;
  final VoidCallback onToggle;
  final String openTime;
  final String closeTime;

  const _StatusBanner({
    required this.isAr,
    required this.isOpen,
    required this.onToggle,
    required this.openTime,
    required this.closeTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: isOpen
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isOpen
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.pause_circle_fill,
              color: isOpen ? Colors.green : Colors.red,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen
                      ? (isAr ? 'المتجر مفتوح الآن' : 'Store is open')
                      : (isAr ? 'المتجر مغلق الآن' : 'Store is closed'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 4),
                Text(
                  isAr
                      ? 'ساعات العمل: $openTime - $closeTime'
                      : 'Working hours: $openTime - $closeTime',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12, fontFamily: 'Cairo'),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: isOpen ? Colors.redAccent : Colors.green,
            borderRadius: BorderRadius.circular(14),
            onPressed: onToggle,
            child: Text(
              isOpen ? (isAr ? 'إغلاق' : 'Close') : (isAr ? 'فتح' : 'Open'),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final bool isAr;
  final AppProvider provider;

  const _StatsGrid({
    required this.isAr,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatData(
          isAr ? 'المبيعات' : 'Sales',
          '${provider.totalSales.toPrice()} د.ع',
          CupertinoIcons.money_dollar_circle_fill,
          Colors.green),
      _StatData(isAr ? 'الطلبات' : 'Orders', '${provider.merchantOrdersCount}',
          CupertinoIcons.bag_fill, Colors.orange),
      _StatData(
          isAr ? 'المنتجات' : 'Products',
          '${provider.merchantProductCount}',
          CupertinoIcons.cube_box_fill,
          Colors.blue),
      _StatData(
          isAr ? 'بانتظارك' : 'Pending',
          '${provider.merchantPendingOrdersCount}',
          CupertinoIcons.clock_fill,
          Colors.redAccent),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stat.title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Icon(stat.icon, color: stat.color, size: 18),
                ],
              ),
              Text(
                stat.value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool isAr;
  final String menuLabel;
  final String storeLabel;
  final VoidCallback onManageMenu;
  final VoidCallback onOrders;
  final VoidCallback onToggleOpen;

  const _QuickActions({
    required this.isAr,
    required this.menuLabel,
    required this.storeLabel,
    required this.onManageMenu,
    required this.onOrders,
    required this.onToggleOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  title: isAr ? menuLabel : menuLabel,
                  icon: CupertinoIcons.square_grid_2x2_fill,
                  color: Colors.orange,
                  onTap: onManageMenu,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  title: isAr ? 'الطلبات' : 'Orders',
                  icon: CupertinoIcons.list_bullet_below_rectangle,
                  color: Colors.blue,
                  onTap: onOrders,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ActionButton(
            title: isAr ? 'تبديل فتح/إغلاق $storeLabel' : 'Toggle store status',
            icon: CupertinoIcons.power,
            color: Colors.green,
            onTap: onToggleOpen,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;

  const _ActionButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
              color: Colors.grey, fontSize: 12, fontFamily: 'Cairo'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isAr;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.isAr,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(CupertinoIcons.sparkles, size: 54, color: Colors.orange),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                height: 1.45,
                fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }
}

class _OrderPreviewCard extends StatelessWidget {
  final ActiveOrder order;
  final bool isAr;

  const _OrderPreviewCard({
    required this.order,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = order.statusKey == 'pending';
    final isActive = order.statusKey == 'accepted' ||
        order.statusKey == 'preparing' ||
        order.statusKey == 'delivering';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isPending
                          ? Colors.orange
                          : (isActive ? Colors.blue : Colors.green))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isAr ? order.statusAr : order.statusEn,
                  style: TextStyle(
                    color: isPending
                        ? Colors.orange
                        : (isActive ? Colors.blue : Colors.green),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          if (order.isRestaurantOrder && order.deliveryStatusKey != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isAr
                      ? (order.deliveryStatusAr ?? '')
                      : (order.deliveryStatusEn ?? ''),
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            isAr ? order.itemsNameAr : order.itemsNameEn,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                height: 1.4,
                fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${order.price.toPrice()} د.ع',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange),
              ),
              Text(
                isAr ? order.dateAr : order.dateEn,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 11, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _StatData(this.title, this.value, this.icon, this.color);
}
