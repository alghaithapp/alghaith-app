import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../models/app_models.dart';
import '../../models/app_notification.dart';
import '../../services/image_storage_service.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_image.dart';
import 'merchant_notifications_screen.dart';
import 'merchant_orders_screen.dart';
import 'merchant_profile_screen.dart';
import 'order_details_screen.dart';

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
    final uniqueCustomersCount = _uniqueCustomersCount(recentOrders);

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
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _ProfilePillButton(
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
              child: _SectionHeader(
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
                        child: _StatCard(
                          label: 'إجمالي ${labels.itemPluralAr}',
                          value: '${provider.merchantProductCount}',
                          icon: Icons.inventory_2_rounded,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
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
                        child: _StatCard(
                          label: 'طلبات مكتملة',
                          value: '${provider.merchantCompletedOrdersCount}',
                          icon: Icons.check_circle_rounded,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
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
                  ? const _OrdersEmptyCard()
                  : _OrdersListCard(
                      orders: recentOrders,
                      displayOrderNumber: provider.displayOrderNumber,
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
              child: _SectionHeader(
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
              child: _AlertsCard(alerts: alerts),
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
  });

  DecorationImage? _coverDecoration() {
    final cover = ImageStorageService.normalizeImageRef(coverImage)?.trim();
    if (cover == null || cover.isEmpty) return null;
    if (ImageStorageService.isRemoteUrl(cover)) {
      return DecorationImage(
        image: NetworkImage(cover),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: 0.55),
          BlendMode.darken,
        ),
      );
    }
    final base64 = _extractBase64Payload(cover);
    if (base64 != null) {
      try {
        return DecorationImage(
          image: MemoryImage(base64Decode(base64)),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.darken,
          ),
        );
      } catch (error) {
        debugPrint('MERCHANT_COVER_DECODE_ERROR: $error');
        return null;
      }
    }
    return null;
  }

  String? _extractBase64Payload(String value) {
    var payload = value.trim();
    if (payload.isEmpty) return null;
    if (payload.contains('base64,')) {
      payload = payload.split('base64,').last.trim();
    }
    if (payload.startsWith('data:image/')) {
      final commaIndex = payload.indexOf(',');
      if (commaIndex != -1) {
        payload = payload.substring(commaIndex + 1).trim();
      }
    }
    if (!ImageStorageService.isBase64Image(payload)) return null;
    return payload;
  }

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
            if (_coverDecoration() != null)
              Positioned.fill(
                child: _buildCoverImage(),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StoreAvatar(imageData: profileImage),
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
                            _StoreStatusSwitch(isOpen: isOpen, onToggle: onToggleOpen),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroMiniStat(
                          label: itemLabel,
                          value: '$productsCount',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _HeroMiniStat(
                          label: 'الطلبات',
                          value: '$ordersCount',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _HeroMiniStat(
                          label: 'عميل',
                          value: '$customersCount',
                        ),
                      ),
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

  Widget _buildCoverImage() {
    final cover = ImageStorageService.normalizeImageRef(coverImage)?.trim();
    if (cover == null || cover.isEmpty) return const SizedBox.shrink();
    if (ImageStorageService.isRemoteUrl(cover)) {
      return Image.network(
        cover,
        fit: BoxFit.cover,
        color: Colors.black.withValues(alpha: 0.55),
        colorBlendMode: BlendMode.darken,
      );
    }
    final base64 = _extractBase64Payload(cover);
    if (base64 != null) {
      try {
        return Image.memory(
          base64Decode(base64),
          fit: BoxFit.cover,
          color: Colors.black.withValues(alpha: 0.55),
          colorBlendMode: BlendMode.darken,
        );
      } catch (error) {
        debugPrint('MERCHANT_COVER_DECODE_ERROR: $error');
        return const SizedBox.shrink();
      }
    }
    return const SizedBox.shrink();
  }
}

class _StoreAvatar extends StatelessWidget {
  final String? imageData;

  const _StoreAvatar({required this.imageData});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _brand.withValues(alpha: 0.65), width: 2),
        boxShadow: [
          BoxShadow(
            color: _brand.withValues(alpha: 0.35),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipOval(
        child: AppImage(
          imageData: imageData,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _StoreStatusSwitch extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const _StoreStatusSwitch({
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (isOpen ? Colors.green : Colors.red).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: (isOpen ? Colors.greenAccent : Colors.redAccent)
                  .withValues(alpha: 0.5),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.greenAccent : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOpen ? 'مفتوح الآن' : 'مغلق',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfilePillButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfilePillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.badge_rounded, color: _brand, size: 20),
              SizedBox(width: 8),
              Text(
                'عرض الملف الكامل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _brand, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: _brand,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: Color(0xFF6B7280),
              height: 1.3,
            ),
          ),
        ],
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

class _OrdersListCard extends StatelessWidget {
  final List<ActiveOrder> orders;
  final String Function(ActiveOrder) displayOrderNumber;

  const _OrdersListCard({
    required this.orders,
    required this.displayOrderNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < orders.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: Colors.grey.shade100,
                indent: 16,
                endIndent: 16,
              ),
            _OrderRow(
              order: orders[i],
              orderNumber: displayOrderNumber(orders[i]),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderDetailsScreen(order: orders[i]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final ActiveOrder order;
  final String orderNumber;
  final VoidCallback onTap;

  const _OrderRow({
    required this.order,
    required this.orderNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _orderStatusBadge(order);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
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
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.customerNameAr,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${order.itemsCount} منتج · ${order.dateAr}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${order.price.toPrice()} د.ع',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      color: _brand,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badge.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge.label,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: badge.color,
                      ),
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

class _StatusBadgeData {
  final String label;
  final Color color;

  const _StatusBadgeData(this.label, this.color);
}

_StatusBadgeData _orderStatusBadge(ActiveOrder order) {
  if (order.statusAr.trim().isNotEmpty &&
      order.statusKey != 'pending' &&
      order.statusKey != 'accepted') {
    final color = switch (order.statusKey) {
      'completed' => Colors.green,
      'cancelled' || 'rejected' => Colors.red,
      _ => AppColors.accent,
    };
    return _StatusBadgeData(order.statusAr, color);
  }
  return switch (order.statusKey) {
    'pending' => const _StatusBadgeData('جديد', Colors.blue),
    'accepted' => const _StatusBadgeData('قيد التحضير', AppColors.accent),
    'preparing' => const _StatusBadgeData('قيد التحضير', AppColors.accent),
    'completed' => const _StatusBadgeData('مكتمل', Colors.green),
    'cancelled' || 'rejected' => const _StatusBadgeData('ملغي', Colors.red),
    _ => _StatusBadgeData(order.statusAr, Colors.grey),
  };
}

class _OrdersEmptyCard extends StatelessWidget {
  const _OrdersEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 56,
            color: _brand.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 12),
          const Text(
            'لا توجد طلبات حالياً',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final List<AppNotificationItem> alerts;

  const _AlertsCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Text(
          'لا توجد تنبيهات جديدة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < alerts.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: Colors.grey.shade100,
                indent: 16,
                endIndent: 16,
              ),
            _AlertRow(
              title: alerts[i].title,
              body: alerts[i].body,
              index: i,
              unread: !alerts[i].read,
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final String title;
  final String body;
  final int index;
  final bool unread;

  const _AlertRow({
    required this.title,
    required this.body,
    required this.index,
    this.unread = false,
  });

  static const _iconColors = [
    AppColors.accent,
    Colors.green,
    Colors.purple,
  ];

  static const _icons = [
    Icons.shopping_bag_rounded,
    Icons.store_rounded,
    Icons.local_offer_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _iconColors[index % _iconColors.length];
    final icon = _icons[index % _icons.length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
