import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/app_bottom_nav_style.dart';
import '../../core/ui/account_ui.dart';
import '../../providers/app_provider.dart';
import '../../utils/courier_profile_fields.dart';
import 'delivery_earnings_screen.dart';
import 'delivery_setup_screen.dart';
import '../../utils/account_role_switch.dart';
import '../../utils/extensions.dart';
import '../../utils/helpers.dart';
import '../../utils/role_notification_poller.dart';
import '../../widgets/app_image.dart';
import '../../widgets/account/account_page_header.dart';
import '../../utils/role_switch_notifications.dart';
import '../../screens/notifications_screen.dart';
import '../../widgets/safe_bottom_bar.dart';

class DeliveryShell extends StatefulWidget {
  const DeliveryShell({super.key});

  @override
  State<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends State<DeliveryShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DeliveryDashboardScreen(),
    DeliveryRequestsScreen(),
    DeliveryActiveScreen(),
    DeliveryCompletedScreen(),
    DeliveryAccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      RoleSwitchNotificationPresenter.showIfNeeded(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RoleNotificationPoller(
      role: 'delivery',
      onRefresh: (provider) => provider.refreshCourierOrders(),
      pollBanners: (provider) => provider.pollCourierBanners(),
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
        body: SafeArea(
          bottom: false,
          child: _screens[_currentIndex],
        ),
        bottomNavigationBar: SafeBottomBar(
          color: isDark
              ? const Color(0xFF1A1A1A)
              : Colors.white.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          child: SizedBox(
            height: 108,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, CupertinoIcons.graph_square_fill, 'الرئيسية'),
                _navItem(1, CupertinoIcons.bell_fill, 'الطلبات'),
                _navItem(2, Icons.motorcycle, 'نشطة'),
                _navItem(3, CupertinoIcons.checkmark_seal_fill, 'مكتملة'),
                _navItem(4, CupertinoIcons.person_fill, 'الحساب'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive
                    ? AppBottomNavStyle.activeColor
                    : CupertinoColors.systemGrey,
                size: 44,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? AppBottomNavStyle.activeColor
                      : CupertinoColors.systemGrey,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapInfoLine extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _MapInfoLine({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class DeliveryDashboardScreen extends StatelessWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final waiting = appProvider.deliveryIncomingOrders.length;
    final active = appProvider.deliveryActiveOrders.length;
    final done = appProvider.deliveryCompletedOrders.length;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'لوحة المندوب',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TopCard(
              title: 'مرحبًا ${appProvider.deliveryCourierName}',
              subtitle:
                  'توصيل طلبات المطاعم والتسوق — استلام نقداً عند التسليم',
              icon: Icons.motorcycle,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _StatBox(
                        label: 'جديدة',
                        value: '$waiting',
                        color: AppColors.accent)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatBox(
                        label: 'نشطة', value: '$active', color: Colors.blue)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatBox(
                        label: 'مكتملة', value: '$done', color: Colors.green)),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const DeliveryEarningsScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF007A7A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'عرض الأرباح — ${appProvider.courierTotalEarnings.toPrice()} د.ع',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_left,
                        color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: 'طلبات مطاعم وتسوق جديدة'),
            const SizedBox(height: 10),
            if (appProvider.deliveryIncomingOrders.isEmpty)
              _EmptyCard(
                text: 'لا توجد طلبات جديدة من المطاعم أو التسوق الآن',
              )
            else
              ...appProvider.deliveryIncomingOrders
                  .take(3)
                  .map((order) => _DeliveryOrderCard(order: order)),
          ],
        ),
      ),
    );
  }
}

class DeliveryRequestsScreen extends StatelessWidget {
  const DeliveryRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final orders = appProvider.deliveryIncomingOrders;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'الطلبات الواردة',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => appProvider.refreshCourierOrders(),
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
        border: null,
      ),
      child: SafeArea(
        child: orders.isEmpty
            ? _EmptyCard(
                text: 'لا توجد طلبات جاهزة للتوصيل حالياً',
              )
            : RefreshIndicator(
                onRefresh: appProvider.refreshCourierOrders,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return _DeliveryOrderCard(order: orders[index]);
                  },
                ),
              ),
      ),
    );
  }
}

class DeliveryActiveScreen extends StatelessWidget {
  const DeliveryActiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final orders = appProvider.deliveryActiveOrders;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'الطلبات النشطة',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => appProvider.refreshCourierOrders(),
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
        border: null,
      ),
      child: SafeArea(
        child: orders.isEmpty
            ? _EmptyCard(
                text: 'لا توجد طلبات نشطة حالياً',
              )
            : RefreshIndicator(
                onRefresh: appProvider.refreshCourierOrders,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return _ActiveDeliveryCard(order: orders[index]);
                  },
                ),
              ),
      ),
    );
  }
}

class DeliveryCompletedScreen extends StatelessWidget {
  const DeliveryCompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final orders = appProvider.deliveryCompletedOrders;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'الطلبات المكتملة',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => appProvider.refreshCourierOrders(),
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
        border: null,
      ),
      child: SafeArea(
        child: orders.isEmpty
            ? _EmptyCard(
                text: 'لا توجد طلبات مكتملة بعد',
              )
            : RefreshIndicator(
                onRefresh: appProvider.refreshCourierOrders,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const DeliveryEarningsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007A7A),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.payments_rounded,
                                color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'إجمالي الأرباح: ${appProvider.courierTotalEarnings.toPrice()} د.ع',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Icon(CupertinoIcons.chevron_left,
                                color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                    ...orders.map(
                      (order) => _CompletedDeliveryCard(order: order),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CompletedDeliveryCard extends StatelessWidget {
  final ActiveOrder order;

  const _CompletedDeliveryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.checkmark_seal_fill,
                  color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طلب #${order.orderNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              Text(
                '${order.price.toPrice()} د.ع',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          if ((order.merchantStoreName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'المتجر: ${order.merchantStoreName}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            order.itemsNameAr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            order.addressAr,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          if (order.deliveredAt != null && order.deliveredAt!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'تم التسليم: ${order.deliveredAt}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DeliveryAccountScreen extends StatelessWidget {
  const DeliveryAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final profile = appProvider.courierProfile ?? const {};
    final isAvailable = appProvider.isCourierAvailable;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            AccountPageHeader(
              notificationCount: appProvider.unreadNotificationCount,
              title: 'حساب المندوب',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: AccountUi.cardDecoration(radius: 22),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CourierProfileFields.profileImage(profile)
                                    .isNotEmpty
                                ? AppImage(
                                    imageData:
                                        CourierProfileFields.profileImage(
                                            profile),
                                    fit: BoxFit.cover,
                                  )
                                : Icon(Icons.motorcycle,
                                    size: 38, color: Colors.orange.shade700),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appProvider.deliveryCourierName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'توصيل طلبات المطاعم والتسوق',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _EditProfileButton(
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => const DeliverySetupScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: AccountUi.cardDecoration(radius: 22),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: isAvailable,
                          onChanged: appProvider.setCourierAvailability,
                          activeThumbColor: Colors.white,
                          activeTrackColor: Colors.green,
                          inactiveTrackColor: Colors.red.shade100,
                          tileColor: Colors.white,
                          title: Text(
                            'حالة التوفر',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            isAvailable
                                ? 'متاح لاستلام الطلبات الآن'
                                : 'غير متاح لاستلام طلبات جديدة',
                            style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'النشاط والإحصائيات'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'الجديدة',
                          value: '${appProvider.deliveryIncomingOrders.length}',
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'النشطة',
                          value: '${appProvider.deliveryActiveOrders.length}',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'المكتملة',
                          value:
                              '${appProvider.deliveryCompletedOrders.length}',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _NavigationCard(
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFF007A7A),
                    title: 'شاشة الأرباح',
                    subtitle: 'عرض تفاصيل الأرباح اليومية والأسبوعية',
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const DeliveryEarningsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _NavigationCard(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: const Color(0xFFE040FB),
                    title: 'تبديل الحساب (الدور)',
                    subtitle: 'الانتقال إلى واجهة الزبون أو التاجر أو المندوب',
                    onTap: () => showRoleSwitcher(context, appProvider),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(title: 'بيانات السكن والوثائق'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: AccountUi.cardDecoration(radius: 22),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _InfoTile(
                          label: 'عنوان السكن',
                          value: CourierProfileFields.homeAddress(profile)
                                  .isNotEmpty
                              ? CourierProfileFields.homeAddress(profile)
                              : '—',
                        ),
                        _InfoTile(
                          label: 'اسم المختار',
                          value: CourierProfileFields.mukhtarName(profile)
                                  .isNotEmpty
                              ? CourierProfileFields.mukhtarName(profile)
                              : '—',
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'صور الوثائق والدراجة'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 120,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (CourierProfileFields.vehicleImage(profile)
                            .isNotEmpty)
                          _docPreview(
                              CourierProfileFields.vehicleImage(profile),
                              'الدراجة'),
                        if (CourierProfileFields.residenceCardImage(profile)
                            .isNotEmpty)
                          _docPreview(
                              CourierProfileFields.residenceCardImage(profile),
                              'بطاقة السكن'),
                        if (CourierProfileFields.idFrontImage(profile)
                            .isNotEmpty)
                          _docPreview(
                              CourierProfileFields.idFrontImage(profile),
                              'الموحدة (1)'),
                        if (CourierProfileFields.idBackImage(profile)
                            .isNotEmpty)
                          _docPreview(CourierProfileFields.idBackImage(profile),
                              'الموحدة (2)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _LogoutCard(onTap: () => appProvider.resetAll()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docPreview(String ref, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AppImage(
              imageData: ref,
              width: 100,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: AccountUi.cardDecoration(radius: 20),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EditProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: AccountUi.brandGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.pencil, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              const Text(
                'تعديل',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavigationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: AccountUi.cardDecoration(radius: 22),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_left,
                size: 16,
                color: Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.power,
                  color: CupertinoColors.systemRed,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.systemRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const _InfoTile({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: CupertinoColors.systemGrey6.withValues(alpha: 0.9),
                ),
              )
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TopCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, Colors.grey.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.grey, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontFamily: 'Cairo',
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}

class _DeliveryOrderCard extends StatelessWidget {
  final ActiveOrder order;

  const _DeliveryOrderCard({required this.order});

  bool get _hasCustomerLocation =>
      order.customerLatitude != null && order.customerLongitude != null;

  bool get _hasMerchantLocation =>
      order.merchantLatitude != null && order.merchantLongitude != null;

  void _openExternalMap(BuildContext context) {
    final merchantLat = order.merchantLatitude;
    final merchantLng = order.merchantLongitude;
    final customerLat = order.customerLatitude;
    final customerLng = order.customerLongitude;

    // للطلبات الجديدة نفتح الخريطة على موقع المتجر (أو الزبون إذا لم يوجد المتجر)
    if (merchantLat != null && merchantLng != null) {
      AppHelpers.openExternalMapNavigation(
        latitude: merchantLat,
        longitude: merchantLng,
        originLatitude: customerLat,
        originLongitude: customerLng,
        travelMode: 'walking',
        context: context,
      );
    } else if (customerLat != null && customerLng != null) {
      AppHelpers.openExternalMapNavigation(
        latitude: customerLat,
        longitude: customerLng,
        travelMode: 'walking',
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(
            children: [
              const Icon(CupertinoIcons.bag_fill,
                  color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'طلب #${order.orderNumber}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Cairo',
                      fontSize: 18),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'دفع عند الاستلام',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          if ((order.merchantStoreName ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'المتجر: ${order.merchantStoreName}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            order.itemsNameAr,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(CupertinoIcons.location_solid,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.addressAr,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(CupertinoIcons.person_fill,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                order.customerNameAr,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const ui.Size(44, 44),
                onPressed: () => AppHelpers.makePhoneCall(order.customerPhone),
                child: Text(
                  order.customerPhone,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'مجموع الحساب والتوصيل:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),
              Text(
                '${order.price.toPrice()} د.ع',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_hasCustomerLocation || _hasMerchantLocation)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(12),
                    minimumSize: const ui.Size(88, 44),
                    onPressed: () => _openExternalMap(context),
                    child: const Text('الخريطة',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Cairo')),
                  ),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: const ui.Size(88, 44),
                  onPressed: () => appProvider.rejectDeliveryOrder(order.id),
                  child: const Text('رفض',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold)),
                ),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: const ui.Size(96, 44),
                  onPressed: () => appProvider.acceptDeliveryOrder(order.id),
                  child: const Text('موافقة',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  final ActiveOrder order;

  const _ActiveDeliveryCard({required this.order});

  bool get _hasCustomerLocation =>
      order.customerLatitude != null && order.customerLongitude != null;

  bool get _hasMerchantLocation =>
      order.merchantLatitude != null && order.merchantLongitude != null;

  void _openExternalMap(BuildContext context) {
    final merchantLat = order.merchantLatitude;
    final merchantLng = order.merchantLongitude;
    final customerLat = order.customerLatitude;
    final customerLng = order.customerLongitude;
    final statusKey = order.deliveryStatusKey ?? '';

    // إذا قبل الطلب، يذهب إلى المتجر أولاً
    if (statusKey == 'accepted' && merchantLat != null && merchantLng != null) {
      AppHelpers.openExternalMapNavigation(
        latitude: merchantLat,
        longitude: merchantLng,
        travelMode: 'walking',
        context: context,
      );
      return;
    }

    // إذا استلم الطلب، يذهب إلى الزبون
    if (const {'picked_up', 'on_way'}.contains(statusKey) &&
        customerLat != null &&
        customerLng != null) {
      AppHelpers.openExternalMapNavigation(
        latitude: customerLat,
        longitude: customerLng,
        travelMode: 'walking',
        context: context,
      );
      return;
    }

    // للطلبات النشطة بدون حالة محددة
    if (customerLat != null && customerLng != null) {
      AppHelpers.openExternalMapNavigation(
        latitude: customerLat,
        longitude: customerLng,
        travelMode: 'walking',
        context: context,
      );
    } else if (merchantLat != null && merchantLng != null) {
      AppHelpers.openExternalMapNavigation(
        latitude: merchantLat,
        longitude: merchantLng,
        travelMode: 'walking',
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final delivered = order.deliveryStatusKey == 'delivered';
    final statusKey = order.deliveryStatusKey ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'طلب #${order.orderNumber}',
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            order.deliveryStatusAr ?? 'قيد التوصيل',
            style: const TextStyle(
                color: Colors.grey, fontFamily: 'Cairo', fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            order.addressAr,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            '${order.price.toPrice()} د.ع — ${order.paymentMethodAr}',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              if (_hasCustomerLocation || _hasMerchantLocation)
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(14),
                  minimumSize: const ui.Size(104, 46),
                  onPressed: () => _openExternalMap(context),
                  child: Text(_deliveryMapButtonLabel(order),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15)),
                ),
              if (statusKey == 'accepted')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(14),
                  minimumSize: const ui.Size(104, 46),
                  onPressed: () => appProvider.markDeliveryPickedUp(order.id),
                  child: const Text('استلام من المتجر',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              if (statusKey == 'picked_up')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(14),
                  minimumSize: const ui.Size(104, 46),
                  onPressed: () => appProvider.markDeliveryOnTheWay(order.id),
                  child: const Text('في الطريق',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              if (statusKey == 'on_way')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(14),
                  minimumSize: const ui.Size(104, 46),
                  onPressed: () => appProvider.markDeliveryCompleted(order.id),
                  child: const Text('تم التسليم + كاش',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              if (delivered)
                const Icon(CupertinoIcons.checkmark_seal_fill,
                    color: Colors.green, size: 24),
            ],
          ),
        ],
      ),
    );
  }

  static String _deliveryMapButtonLabel(ActiveOrder order) {
    switch (order.deliveryStatusKey) {
      case 'accepted':
        return 'الذهاب إلى المتجر';
      case 'picked_up':
      case 'on_way':
        return 'الذهاب إلى الزبون';
      default:
        return 'الخريطة';
    }
  }
}

class _DeliveryMapPreviewScreen extends StatefulWidget {
  final ActiveOrder order;

  const _DeliveryMapPreviewScreen({required this.order});

  @override
  State<_DeliveryMapPreviewScreen> createState() =>
      _DeliveryMapPreviewScreenState();
}

class _DeliveryMapPreviewScreenState extends State<_DeliveryMapPreviewScreen> {
  MapboxMap? _map;
  CircleAnnotationManager? _circleManager;
  Position? _courierPosition;

  Position? get _customerPosition {
    final lat = widget.order.customerLatitude;
    final lng = widget.order.customerLongitude;
    if (lat == null || lng == null) return null;
    return Position(lng, lat);
  }

  Position? get _merchantPosition {
    final lat = widget.order.merchantLatitude;
    final lng = widget.order.merchantLongitude;
    if (lat == null || lng == null) return null;
    return Position(lng, lat);
  }

  Position get _initialPosition =>
      _merchantPosition ?? _customerPosition ?? Position(44.3661, 33.3152);

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    try {
      _circleManager = await map.annotations.createCircleAnnotationManager();
      await _syncMarkers();
    } catch (_) {}
    unawaited(_loadCourierPosition());
  }

  Future<void> _loadCourierPosition() async {
    final enabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!enabled) return;
    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      return;
    }
    final current = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
      ),
    );
    setState(() {
      _courierPosition = Position(current.longitude, current.latitude);
    });
    await _syncMarkers();
  }

  Future<void> _syncMarkers() async {
    final manager = _circleManager;
    if (manager == null) return;
    try {
      await manager.deleteAll();
      final merchant = _merchantPosition;
      if (merchant != null) {
        await manager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: merchant),
            circleColor: const Color(0xFF1976D2).value,
            circleRadius: 9,
            circleStrokeColor: Colors.white.value,
            circleStrokeWidth: 2,
          ),
        );
      }
      final customer = _customerPosition;
      if (customer != null) {
        await manager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: customer),
            circleColor: const Color(0xFFF5A01D).value,
            circleRadius: 9,
            circleStrokeColor: Colors.white.value,
            circleStrokeWidth: 2,
          ),
        );
      }
      final courier = _courierPosition;
      if (courier != null) {
        await manager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: courier),
            circleColor: const Color(0xFF2E7D32).value,
            circleRadius: 8,
            circleStrokeColor: Colors.white.value,
            circleStrokeWidth: 2,
          ),
        );
      }
    } catch (_) {}
  }

  VoidCallback? _externalNavigationAction() {
    final customerLat = widget.order.customerLatitude;
    final customerLng = widget.order.customerLongitude;
    final merchantLat = widget.order.merchantLatitude;
    final merchantLng = widget.order.merchantLongitude;
    final statusKey = widget.order.deliveryStatusKey ?? '';
    final courierLat = _courierPosition?.lat.toDouble();
    final courierLng = _courierPosition?.lng.toDouble();

    if (statusKey == 'accepted' && merchantLat != null && merchantLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: merchantLat,
            longitude: merchantLng,
            originLatitude: courierLat,
            originLongitude: courierLng,
            travelMode: 'walking',
          );
    }

    if (const {'picked_up', 'on_way'}.contains(statusKey) &&
        customerLat != null &&
        customerLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: customerLat,
            longitude: customerLng,
            originLatitude: courierLat,
            originLongitude: courierLng,
            travelMode: 'walking',
          );
    }

    if (merchantLat != null &&
        merchantLng != null &&
        customerLat != null &&
        customerLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: customerLat,
            longitude: customerLng,
            originLatitude: merchantLat,
            originLongitude: merchantLng,
            travelMode: 'walking',
          );
    }

    if (customerLat != null && customerLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: customerLat,
            longitude: customerLng,
            travelMode: 'walking',
          );
    }

    if (merchantLat != null && merchantLng != null) {
      return () => AppHelpers.openExternalMapNavigation(
            latitude: merchantLat,
            longitude: merchantLng,
            travelMode: 'walking',
          );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final customerLat = widget.order.customerLatitude;
    final customerLng = widget.order.customerLongitude;
    final merchantLat = widget.order.merchantLatitude;
    final merchantLng = widget.order.merchantLongitude;
    final hasCustomer = customerLat != null && customerLng != null;
    final hasMerchant = merchantLat != null && merchantLng != null;
    if (!hasCustomer && !hasMerchant) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('الخريطة'),
        ),
        child: const SafeArea(
          child: Center(
            child: Text(
              'هذا الطلب لا يحتوي إحداثيات موقع.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'خريطة التوصيل',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _externalNavigationAction(),
          child: const Text(
            'فتح الخرائط',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: MapWidget(
                styleUri: 'mapbox://styles/mapbox/streets-v12',
                cameraOptions: CameraOptions(
                  center: Point(coordinates: _initialPosition),
                  zoom: 14.8,
                ),
                onMapCreated: _onMapCreated,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasMerchant)
                    _MapInfoLine(
                      color: const Color(0xFF1976D2),
                      label: 'المتجر',
                      value:
                          '${widget.order.merchantStoreName ?? '-'} · ${merchantLat.toStringAsFixed(5)}, ${merchantLng.toStringAsFixed(5)}',
                    ),
                  if (hasCustomer) ...[
                    const SizedBox(height: 6),
                    _MapInfoLine(
                      color: const Color(0xFFF5A01D),
                      label: 'الزبون',
                      value:
                          '${widget.order.addressAr} · ${customerLat.toStringAsFixed(5)}, ${customerLng.toStringAsFixed(5)}',
                    ),
                  ],
                  if (_courierPosition != null) ...[
                    const SizedBox(height: 6),
                    const _MapInfoLine(
                      color: Color(0xFF2E7D32),
                      label: 'موقعك',
                      value: 'موقع المندوب الحالي',
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
