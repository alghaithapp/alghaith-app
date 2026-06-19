import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';
import '../../utils/role_notification_poller.dart';
import '../../utils/role_switch_notifications.dart';
import '../../widgets/safe_bottom_bar.dart';
import 'driver_shared_widgets.dart';
import 'driver_account_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DriverDashboardScreen(),
    DriverRequestsScreen(),
    DriverTripsScreen(),
    DriverAccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      RoleSwitchNotificationPresenter.showIfNeeded(context);
      // فتح تفاصيل الطلب إذا كان هناك orderId معلّق من الإشعار
      final provider = context.read<AppProvider>();
      final orderId = provider.takePendingOrderId('driver');
      if (orderId != null && orderId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DriverTripDetailsScreen(orderId: orderId),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = AppColors.accent;

    return RoleNotificationPoller(
      role: 'driver',
      onRefresh: (provider) => provider.refreshDriverTaxiRequests(),
      pollBanners: (provider) => provider.pollTaxiBanners(),
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
              color: accentColor.withValues(alpha: isDark ? 0.18 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, CupertinoIcons.graph_square_fill, accentColor,
                    'الرئيسية'),
                _navItem(1, CupertinoIcons.bell_fill, accentColor, 'الطلبات'),
                _navItem(2, Icons.local_taxi_rounded, accentColor, 'الرحلات'),
                _navItem(3, CupertinoIcons.person_fill, accentColor, 'الحساب'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, Color accentColor, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive ? accentColor : CupertinoColors.systemGrey,
              size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? accentColor : CupertinoColors.systemGrey,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class DriverTripDetailsScreen extends StatelessWidget {
  final String orderId;

  const DriverTripDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final incomingTaxi =
        _findTaxi(provider.visibleTaxiIncomingRequests, orderId);
    final activeTaxi = _findTaxi(provider.visibleTaxiActiveRequests, orderId);
    final completedTaxi =
        _findTaxi(provider.visibleTaxiCompletedRequests, orderId);
    final incomingDelivery =
        _findOrder(provider.visibleDeliveryIncomingOrders, orderId);
    final activeDelivery =
        _findOrder(provider.visibleDeliveryActiveOrders, orderId);
    final completedDelivery =
        _findOrder(provider.visibleDeliveryCompletedOrders, orderId);

    Widget body;
    if (incomingTaxi != null) {
      body = DrvTaxiCard(request: incomingTaxi);
    } else if (activeTaxi != null) {
      body = DrvTaxiCard(request: activeTaxi);
    } else if (completedTaxi != null) {
      body = DrvTaxiCard(request: completedTaxi);
    } else if (incomingDelivery != null) {
      body = DrvDeliveryCard(order: incomingDelivery);
    } else if (activeDelivery != null) {
      body = DrvActiveDeliveryCard(order: activeDelivery);
    } else if (completedDelivery != null) {
      body = DrvActiveDeliveryCard(order: completedDelivery);
    } else {
      body = const DrvEmptyState(
        title: 'Order not found',
        subtitle: 'Pull to refresh and try again.',
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Trip details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.refreshDriverTaxiRequests();
          await provider.refreshCourierOrders();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [body],
        ),
      ),
    );
  }

  TaxiRequest? _findTaxi(List<TaxiRequest> requests, String id) {
    for (final request in requests) {
      if (request.id == id) return request;
    }
    return null;
  }

  ActiveOrder? _findOrder(List<ActiveOrder> orders, String id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }
}

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final profile = provider.driverProfile ?? const {};
    final typeLabel = provider.driverServiceModeLabelAr;
    final taxiNew = provider.visibleTaxiIncomingRequests.length;
    final taxiActive = provider.visibleTaxiActiveRequests.length;
    final taxiDone = provider.visibleTaxiCompletedRequests.length;
    final deliveryNew = provider.visibleDeliveryIncomingOrders.length;
    final deliveryActive = provider.visibleDeliveryActiveOrders.length;
    final deliveryDone = provider.visibleDeliveryCompletedOrders.length;
    final newCount = taxiNew + deliveryNew;
    final activeCount = taxiActive + deliveryActive;
    final doneCount = taxiDone + deliveryDone;

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'لوحة سائق التكسي',
          style:
              const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DrvTopCard(
              title: 'أهلاً ${profile['name'] ?? 'بك'}',
              subtitle: 'نوع الحساب: $typeLabel',
              icon: CupertinoIcons.car_fill,
              accentColor: provider.driverAcceptsBoth
                  ? Colors.green
                  : provider.driverAcceptsDelivery
                      ? Colors.blue
                      : AppColors.accent,
            ),
            const SizedBox(height: 10),
            DrvServiceChip(
              label: typeLabel,
              color: provider.driverAcceptsBoth
                  ? Colors.green
                  : provider.driverAcceptsDelivery
                      ? Colors.blue
                      : AppColors.accent,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: DrvStatBox(
                        label: 'جديد',
                        value: '$newCount',
                        color: provider.driverAcceptsBoth
                            ? Colors.green
                            : provider.driverAcceptsDelivery
                                ? Colors.blue
                                : AppColors.accent)),
                const SizedBox(width: 10),
                Expanded(
                    child: DrvStatBox(
                        label: 'نشط',
                        value: '$activeCount',
                        color: provider.driverAcceptsTaxi &&
                                provider.driverAcceptsDelivery
                            ? Colors.deepPurple
                            : provider.driverAcceptsDelivery
                                ? Colors.blue
                                : AppColors.accent)),
                const SizedBox(width: 10),
                Expanded(
                    child: DrvStatBox(
                        label: 'مكتمل',
                        value: '$doneCount',
                        color: provider.driverAcceptsBoth
                            ? Colors.green
                            : Colors.teal)),
              ],
            ),
            const SizedBox(height: 16),
            DrvSectionTitle(
              title: 'آخر الطلبات',
              subtitle: 'تابع الطلبات الجديدة وقم بقبولها بسرعة',
            ),
            const SizedBox(height: 8),
            DrvServiceChip(
              label: typeLabel,
              color: provider.driverAcceptsBoth
                  ? Colors.green
                  : provider.driverAcceptsDelivery
                      ? Colors.blue
                      : AppColors.accent,
            ),
            const SizedBox(height: 12),
            if (!provider.driverAcceptsTaxi && !provider.driverAcceptsDelivery)
              DrvEmptyState(
                title: 'لا توجد خدمات مفعلة',
                subtitle: 'فعّل التكسي أو التوصيل من إعدادات الحساب',
              )
            else if (provider.visibleTaxiRequests.isEmpty &&
                provider.visibleDeliveryIncomingOrders.isEmpty)
              DrvEmptyState(
                title: 'لا توجد طلبات حتى الآن',
                subtitle: 'ستظهر هنا الطلبات الجديدة فور إرسالها من الزبائن.',
              )
            else ...[
              if (provider.driverAcceptsTaxi) ...[
                DrvSectionTitle(
                  title: 'طلبات التكسي',
                  subtitle: '🚕 طلبات نقل الركاب — تظهر في هذه القائمة',
                  color: AppColors.accent,
                ),
                const SizedBox(height: 10),
                if (provider.visibleTaxiRequests.isEmpty)
                  DrvEmptyState(
                    title: 'لا توجد طلبات تكسي',
                    subtitle: 'عندما يطلب الزبون تكسي ستظهر هنا',
                  )
                else
                  ...provider.visibleTaxiRequests.take(3).map(
                        (request) => DrvTaxiPreview(
                          request: request,
                        ),
                      ),
              ],
              if (provider.driverAcceptsDelivery) ...[
                const SizedBox(height: 12),
                DrvSectionTitle(
                  title: 'طلبات المطاعم',
                  subtitle: '🛵 طلبات المطاعم والتسوق — تظهر في هذه القائمة',
                  color: Colors.blue,
                ),
                const SizedBox(height: 10),
                if (provider.visibleDeliveryIncomingOrders.isEmpty)
                  DrvEmptyState(
                    title: 'لا توجد طلبات مطاعم',
                    subtitle: 'ستظهر طلبات المطاعم هنا',
                  )
                else
                  ...provider.visibleDeliveryIncomingOrders.take(3).map(
                        (order) => DrvDeliveryCard(order: order),
                      ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class DriverRequestsScreen extends StatelessWidget {
  const DriverRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final taxiRequests = provider.visibleTaxiIncomingRequests;
    final deliveryRequests = provider.visibleDeliveryIncomingOrders;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DrvSectionTitle(
          title: 'الطلبات الواردة',
          subtitle: 'كل الخدمات المفعلة على حسابك',
        ),
        const SizedBox(height: 12),
        if (!provider.driverAcceptsTaxi && !provider.driverAcceptsDelivery)
          DrvEmptyState(
            title: 'لا توجد خدمات مفعلة',
            subtitle: 'فعّل التكسي أو التوصيل من إعدادات الحساب',
          )
        else if (taxiRequests.isEmpty && deliveryRequests.isEmpty)
          DrvEmptyState(
            title: 'لا توجد طلبات',
            subtitle: 'ستظهر الطلبات هنا عندما تصل من الزبائن.',
          )
        else ...[
          if (provider.driverAcceptsTaxi) ...[
            DrvSectionTitle(
              title: 'طلبات التكسي',
              subtitle: '🚕 طلبات نقل الركاب — تظهر في هذه القائمة',
              color: AppColors.accent,
            ),
            const SizedBox(height: 10),
            if (taxiRequests.isEmpty)
              DrvEmptyState(
                title: 'لا توجد طلبات تكسي',
                subtitle: 'عندما يطلب الزبون تكسي ستظهر هنا',
              )
            else
              ...taxiRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DrvTaxiCard(request: request),
                ),
              ),
          ],
          if (provider.driverAcceptsDelivery) ...[
            const SizedBox(height: 14),
            DrvSectionTitle(
              title: 'طلبات المطاعم',
              subtitle: '🛵 طلبات المطاعم والتسوق — تظهر في هذه القائمة',
              color: Colors.blue,
            ),
            const SizedBox(height: 10),
            if (deliveryRequests.isEmpty)
              DrvEmptyState(
                title: 'لا توجد طلبات مطاعم',
                subtitle: 'عندما يصلك طلب مطعم سيظهر هنا',
              )
            else
              ...deliveryRequests.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DrvDeliveryCard(order: order),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class DriverTripsScreen extends StatelessWidget {
  const DriverTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final taxiActive = provider.visibleTaxiActiveRequests;
    final deliveryActive = provider.visibleDeliveryActiveOrders;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DrvSectionTitle(
          title: 'الخدمات النشطة',
          subtitle: 'الطلبات المقبولة أو الجاري تنفيذها',
        ),
        const SizedBox(height: 12),
        if (!provider.driverAcceptsTaxi && !provider.driverAcceptsDelivery)
          DrvEmptyState(
            title: 'لا توجد خدمات مفعلة',
            subtitle: 'فعّل التكسي أو التوصيل من إعدادات الحساب',
          )
        else if (taxiActive.isEmpty && deliveryActive.isEmpty)
          DrvEmptyState(
            title: 'لا توجد رحلات أو طلبات نشطة',
            subtitle: 'عند قبول أي طلب سيظهر هنا.',
          )
        else ...[
          if (provider.driverAcceptsTaxi) ...[
            DrvSectionTitle(
              title: 'رحلات التكسي',
              subtitle: '🚕 رحلات التكسي النشطة — قيد التنفيذ',
              color: AppColors.accent,
            ),
            const SizedBox(height: 10),
            if (taxiActive.isEmpty)
              DrvEmptyState(
                title: 'لا توجد رحلات تكسي',
                subtitle: 'ستظهر هنا طلبات التكسي النشطة',
              )
            else
              ...taxiActive.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DrvTaxiCard(request: request),
                ),
              ),
          ],
          if (provider.driverAcceptsDelivery) ...[
            const SizedBox(height: 14),
            DrvSectionTitle(
              title: 'طلبات المطاعم النشطة',
              subtitle: '🛵 طلبات التوصيل النشطة — قيد التنفيذ',
              color: Colors.blue,
            ),
            const SizedBox(height: 10),
            if (deliveryActive.isEmpty)
              DrvEmptyState(
                title: 'لا توجد طلبات مطاعم نشطة',
                subtitle: 'ستظهر هنا طلبات المطاعم النشطة',
              )
            else
              ...deliveryActive.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DrvActiveDeliveryCard(order: order),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

