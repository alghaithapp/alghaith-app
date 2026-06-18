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
import '../../utils/account_role_switch.dart';
import '../../screens/notifications_screen.dart';
import '../../widgets/app_image.dart';
import '../../widgets/safe_bottom_bar.dart';

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
      body = _TaxiRequestCard(request: incomingTaxi);
    } else if (activeTaxi != null) {
      body = _TaxiRequestCard(request: activeTaxi);
    } else if (completedTaxi != null) {
      body = _TaxiRequestCard(request: completedTaxi);
    } else if (incomingDelivery != null) {
      body = _DriverDeliveryOrderCard(order: incomingDelivery);
    } else if (activeDelivery != null) {
      body = _DriverActiveDeliveryCard(order: activeDelivery);
    } else if (completedDelivery != null) {
      body = _DriverActiveDeliveryCard(order: completedDelivery);
    } else {
      body = const _EmptyState(
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
            _TopCard(
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
            _ServiceModeChip(
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
                    child: _StatBox(
                        label: 'جديد',
                        value: '$newCount',
                        color: provider.driverAcceptsBoth
                            ? Colors.green
                            : provider.driverAcceptsDelivery
                                ? Colors.blue
                                : AppColors.accent)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatBox(
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
                    child: _StatBox(
                        label: 'مكتمل',
                        value: '$doneCount',
                        color: provider.driverAcceptsBoth
                            ? Colors.green
                            : Colors.teal)),
              ],
            ),
            const SizedBox(height: 16),
            _SectionTitle(
              title: 'آخر الطلبات',
              subtitle: 'تابع الطلبات الجديدة وقم بقبولها بسرعة',
            ),
            const SizedBox(height: 8),
            _ServiceModeChip(
              label: typeLabel,
              color: provider.driverAcceptsBoth
                  ? Colors.green
                  : provider.driverAcceptsDelivery
                      ? Colors.blue
                      : AppColors.accent,
            ),
            const SizedBox(height: 12),
            if (!provider.driverAcceptsTaxi && !provider.driverAcceptsDelivery)
              _EmptyState(
                title: 'لا توجد خدمات مفعلة',
                subtitle: 'فعّل التكسي أو التوصيل من إعدادات الحساب',
              )
            else if (provider.visibleTaxiRequests.isEmpty &&
                provider.visibleDeliveryIncomingOrders.isEmpty)
              _EmptyState(
                title: 'لا توجد طلبات حتى الآن',
                subtitle: 'ستظهر هنا الطلبات الجديدة فور إرسالها من الزبائن.',
              )
            else ...[
              if (provider.driverAcceptsTaxi) ...[
                _SectionTitle(
                  title: 'طلبات التكسي',
                  subtitle: 'الطلبات المتاحة لخدمة التكسي',
                ),
                const SizedBox(height: 10),
                if (provider.visibleTaxiRequests.isEmpty)
                  _EmptyState(
                    title: 'لا توجد طلبات تكسي',
                    subtitle: 'عندما يطلب الزبون تكسي ستظهر هنا',
                  )
                else
                  ...provider.visibleTaxiRequests.take(3).map(
                        (request) => _TaxiRequestPreview(
                          request: request,
                        ),
                      ),
              ],
              if (provider.driverAcceptsDelivery) ...[
                const SizedBox(height: 12),
                _SectionTitle(
                  title: 'طلبات المطاعم',
                  subtitle: 'طلبات التوصيل المفعلة على حسابك',
                ),
                const SizedBox(height: 10),
                if (provider.visibleDeliveryIncomingOrders.isEmpty)
                  _EmptyState(
                    title: 'لا توجد طلبات مطاعم',
                    subtitle: 'ستظهر طلبات المطاعم هنا',
                  )
                else
                  ...provider.visibleDeliveryIncomingOrders.take(3).map(
                        (order) => _DriverDeliveryOrderCard(order: order),
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
        _SectionTitle(
          title: 'الطلبات الواردة',
          subtitle: 'كل الخدمات المفعلة على حسابك',
        ),
        const SizedBox(height: 12),
        if (!provider.driverAcceptsTaxi && !provider.driverAcceptsDelivery)
          _EmptyState(
            title: 'لا توجد خدمات مفعلة',
            subtitle: 'فعّل التكسي أو التوصيل من إعدادات الحساب',
          )
        else if (taxiRequests.isEmpty && deliveryRequests.isEmpty)
          _EmptyState(
            title: 'لا توجد طلبات',
            subtitle: 'ستظهر الطلبات هنا عندما تصل من الزبائن.',
          )
        else ...[
          if (provider.driverAcceptsTaxi) ...[
            _SectionTitle(
              title: 'طلبات التكسي',
              subtitle: 'الطلبات الخاصة بنقل الزبائن',
            ),
            const SizedBox(height: 10),
            if (taxiRequests.isEmpty)
              _EmptyState(
                title: 'لا توجد طلبات تكسي',
                subtitle: 'عندما يطلب الزبون تكسي ستظهر هنا',
              )
            else
              ...taxiRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TaxiRequestCard(request: request),
                ),
              ),
          ],
          if (provider.driverAcceptsDelivery) ...[
            const SizedBox(height: 14),
            _SectionTitle(
              title: 'طلبات المطاعم',
              subtitle: 'طلبات التوصيل المفعلة على الحساب',
            ),
            const SizedBox(height: 10),
            if (deliveryRequests.isEmpty)
              _EmptyState(
                title: 'لا توجد طلبات مطاعم',
                subtitle: 'عندما يصلك طلب مطعم سيظهر هنا',
              )
            else
              ...deliveryRequests.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DriverDeliveryOrderCard(order: order),
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
        _SectionTitle(
          title: 'الخدمات النشطة',
          subtitle: 'الطلبات المقبولة أو الجاري تنفيذها',
        ),
        const SizedBox(height: 12),
        if (!provider.driverAcceptsTaxi && !provider.driverAcceptsDelivery)
          _EmptyState(
            title: 'لا توجد خدمات مفعلة',
            subtitle: 'فعّل التكسي أو التوصيل من إعدادات الحساب',
          )
        else if (taxiActive.isEmpty && deliveryActive.isEmpty)
          _EmptyState(
            title: 'لا توجد رحلات أو طلبات نشطة',
            subtitle: 'عند قبول أي طلب سيظهر هنا.',
          )
        else ...[
          if (provider.driverAcceptsTaxi) ...[
            _SectionTitle(
              title: 'رحلات التكسي',
              subtitle: 'الطلبات المقبولة أو قيد التنفيذ',
            ),
            const SizedBox(height: 10),
            if (taxiActive.isEmpty)
              _EmptyState(
                title: 'لا توجد رحلات تكسي',
                subtitle: 'ستظهر هنا طلبات التكسي النشطة',
              )
            else
              ...taxiActive.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TaxiRequestCard(request: request),
                ),
              ),
          ],
          if (provider.driverAcceptsDelivery) ...[
            const SizedBox(height: 14),
            _SectionTitle(
              title: 'طلبات المطاعم النشطة',
              subtitle: 'الطلبات المقبولة أو الجاري توصيلها',
            ),
            const SizedBox(height: 10),
            if (deliveryActive.isEmpty)
              _EmptyState(
                title: 'لا توجد طلبات مطاعم نشطة',
                subtitle: 'ستظهر هنا طلبات المطاعم النشطة',
              )
            else
              ...deliveryActive.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DriverActiveDeliveryCard(order: order),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class DriverAccountScreen extends StatelessWidget {
  const DriverAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final profile = provider.driverProfile ?? const {};
    const typeLabel = 'سائق تكسي';
    final isAvailable = profile['available'] as bool? ?? true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading:
              const Icon(Icons.notifications_outlined, color: AppColors.accent),
          title: const Text(
            'الإشعارات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
            ),
          ),
          trailing: provider.unreadNotificationCount > 0
              ? CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFFF5A01D),
                  child: Text(
                    '${provider.unreadNotificationCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF111111), Color(0xFF2E2E2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              _DriverAvatar(
                avatarBase64: profile['avatarBase64'] as String?,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حساب سائق التكسي',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'نقل الزبائن — لا يشمل توصيل الطلبات',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? Colors.green.withValues(alpha: 0.16)
                            : Colors.red.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isAvailable ? 'متاح' : 'غير متاح',
                        style: TextStyle(
                          color: isAvailable
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ImageUploadCard(
                title: 'الصورة الشخصية',
                imageBase64: profile['avatarBase64'] as String?,
                icon: Icons.person,
                onTap: () => _showEditProfileSheet(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ImageUploadCard(
                title: 'صورة السيارة',
                imageBase64: profile['carImageBase64'] as String?,
                icon: Icons.directions_car,
                onTap: () => _showEditProfileSheet(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: isAvailable,
          onChanged: (value) => provider.setDriverAvailability(value),
          activeThumbColor: AppColors.accent,
          tileColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'التوفر',
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            isAvailable
                ? 'تستقبل طلبات التكسي الآن'
                : 'مؤقتًا لا تستقبل طلبات التكسي',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        const SizedBox(height: 12),
        _InfoTile(label: 'الاسم', value: '${profile['name'] ?? '-'}'),
        _InfoTile(label: 'الهاتف', value: '${profile['phone'] ?? '-'}'),
        _InfoTile(label: 'نوع الحساب', value: typeLabel),
        _InfoTile(label: 'السيارة', value: '${profile['vehicle'] ?? '-'}'),
        _InfoTile(label: 'اللوحة', value: '${profile['plate'] ?? '-'}'),
        _InfoTile(label: 'المنطقة', value: '${profile['area'] ?? '-'}'),
        if ((profile['notes'] as String?)?.isNotEmpty ?? false)
          _InfoTile(
            label: 'ملاحظات',
            value: '${profile['notes']}',
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(18),
            onPressed: () => _showEditProfileSheet(context),
            child: Text(
              'تعديل الحساب',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w900),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: const Color(0xFFE040FB),
            borderRadius: BorderRadius.circular(18),
            onPressed: () => showRoleSwitcher(context, provider),
            child: const Text(
              'تبديل الحساب (الدور)',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(18),
            onPressed: () => provider.resetAll(),
            child: Text(
              'تسجيل الخروج',
              style: const TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEditProfileSheet(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final profile = provider.driverProfile ?? const {};
    final nameController =
        TextEditingController(text: '${profile['name'] ?? ''}');
    final phoneController =
        TextEditingController(text: '${profile['phone'] ?? ''}');
    final vehicleController =
        TextEditingController(text: '${profile['vehicle'] ?? ''}');
    final plateController =
        TextEditingController(text: '${profile['plate'] ?? ''}');
    final areaController =
        TextEditingController(text: '${profile['area'] ?? ''}');
    final notesController =
        TextEditingController(text: '${profile['notes'] ?? ''}');
    String? avatarBase64 = profile['avatarBase64'] as String?;
    String? carImageBase64 = profile['carImageBase64'] as String?;
    bool isAvailable = profile['available'] as bool? ?? true;

    Future<String?> pickImage() async {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      return base64Encode(bytes);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.92,
              minChildSize: 0.7,
              maxChildSize: 0.98,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4F4F6),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: Container(
                          width: 54,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'تعديل ملف السائق',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ImageUploadCard(
                        title: 'الصورة الشخصية',
                        imageBase64: avatarBase64,
                        icon: Icons.person,
                        onTap: () async {
                          final picked = await pickImage();
                          if (picked != null) {
                            setSheetState(() => avatarBase64 = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _ImageUploadCard(
                        title: 'صورة السيارة',
                        imageBase64: carImageBase64,
                        icon: Icons.directions_car,
                        onTap: () async {
                          final picked = await pickImage();
                          if (picked != null) {
                            setSheetState(() => carImageBase64 = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isAvailable,
                        onChanged: (value) =>
                            setSheetState(() => isAvailable = value),
                        title: Text(
                          'متاح / غير متاح',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          isAvailable ? 'تستقبل الطلبات' : 'مؤقتًا غير متصل',
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                      _editField('الاسم الكامل', nameController),
                      _editField('رقم الهاتف', phoneController),
                      _editField('نوع السيارة', vehicleController),
                      _editField('رقم اللوحة', plateController),
                      _editField('منطقة العمل', areaController),
                      _editField('ملاحظات', notesController, maxLines: 3),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(18),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          onPressed: () async {
                            await provider.setDriverProfile({
                              'type': 'taxi',
                              'services': {'taxi': true, 'delivery': false},
                              'name': nameController.text.trim(),
                              'phone': phoneController.text.trim(),
                              'vehicle': vehicleController.text.trim(),
                              'plate': plateController.text.trim(),
                              'area': areaController.text.trim(),
                              'notes': notesController.text.trim(),
                              'available': isAvailable,
                              'avatarBase64': avatarBase64,
                              'carImageBase64': carImageBase64,
                            });
                            if (context.mounted) Navigator.pop(sheetContext);
                          },
                          child: Text(
                            'حفظ التعديلات',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    vehicleController.dispose();
    plateController.dispose();
    areaController.dispose();
    notesController.dispose();
  }

  Widget _editField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  final String? avatarBase64;

  const _DriverAvatar({required this.avatarBase64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ClipOval(
        child: AppImage(
          imageData: avatarBase64,
        ),
      ),
    );
  }
}

class _ImageUploadCard extends StatelessWidget {
  final String title;
  final String? imageBase64;
  final IconData icon;
  final VoidCallback onTap;

  const _ImageUploadCard({
    required this.title,
    required this.imageBase64,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AppImage(
                  imageData: imageBase64,
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppColors.accent : Colors.grey.shade300),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}

class _ServiceControlCard extends StatelessWidget {
  final bool taxiEnabled;
  final bool deliveryEnabled;
  final ValueChanged<bool> onTaxiChanged;
  final ValueChanged<bool> onDeliveryChanged;

  const _ServiceControlCard({
    required this.taxiEnabled,
    required this.deliveryEnabled,
    required this.onTaxiChanged,
    required this.onDeliveryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bothEnabled = taxiEnabled && deliveryEnabled;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الخدمات المفعلة',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'يمكنك تشغيل التكسي أو التوصيل أو الاثنين معًا',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              height: 1.35,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          _ServiceToggleRow(
            label: 'سائق تكسي',
            subtitle: 'يظهر له طلبات التكسي',
            icon: Icons.local_taxi_rounded,
            active: taxiEnabled,
            color: AppColors.accent,
            onChanged: onTaxiChanged,
          ),
          const SizedBox(height: 10),
          _ServiceToggleRow(
            label: 'مندوب توصيل',
            subtitle: 'يظهر له طلبات المطاعم',
            icon: Icons.delivery_dining_rounded,
            active: deliveryEnabled,
            color: Colors.blue,
            onChanged: onDeliveryChanged,
          ),
          if (bothEnabled) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'الخدمتان مفعّلتان معًا، وستظهر الطلبات جميعها داخل الحساب.',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool active;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _ServiceToggleRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.08) : const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: active,
            activeThumbColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TaxiRequestCard extends StatelessWidget {
  final TaxiRequest request;

  const _TaxiRequestCard({
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final isPending = request.statusKey == 'pending';
    final isAccepted = request.statusKey == 'accepted';
    final isCancelRequested = request.statusKey == 'cancel_requested';
    final isOnWay = request.statusKey == 'on_way';
    final isArrived = request.statusKey == 'arrived';
    final isPickedUp = request.statusKey == 'picked_up';
    final isTrip = request.statusKey == 'in_trip';
    final isDone = request.statusKey == 'completed';
    final isCancelled = request.statusKey == 'cancelled';
    final isRejected = request.statusKey == 'rejected';

    final color = isDone
        ? Colors.green
        : isTrip
            ? Colors.blue
            : isPickedUp
                ? Colors.teal
                : isArrived
                    ? Colors.indigo
                    : isOnWay
                        ? Colors.lightBlue
                        : isCancelRequested
                            ? AppColors.accent
                            : isCancelled
                                ? Colors.grey
                                : isRejected
                                    ? Colors.red
                                    : isAccepted
                                        ? Colors.teal
                                        : AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                request.requestNumber,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  request.statusAr,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${request.customerNameAr} • ${request.fare.toPrice()} د.ع',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 4),
          Text(
            '${request.pickupAddressAr} → ${request.dropoffAddressAr}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              height: 1.4,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isPending) ...[
                Expanded(
                  child: _ActionButton(
                    label: 'قبول',
                    color: Colors.green,
                    onTap: () => provider.acceptTaxiRequest(request.id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'رفض',
                    color: Colors.red,
                    onTap: () => provider.rejectTaxiRequest(request.id),
                  ),
                ),
              ] else if (isCancelRequested) ...[
                Expanded(
                  child: _ActionButton(
                    label: 'موافقة الإلغاء',
                    color: Colors.red,
                    onTap: () =>
                        provider.approveTaxiCancellationByDriver(request.id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'رفض الإلغاء',
                    color: Colors.green,
                    onTap: () =>
                        provider.rejectTaxiCancellationByDriver(request.id),
                  ),
                ),
              ] else if (isAccepted) ...[
                Expanded(
                  child: _ActionButton(
                    label: 'في الطريق',
                    color: Colors.lightBlue,
                    onTap: () => provider.markTaxiOnWay(request.id),
                  ),
                ),
              ] else if (isOnWay) ...[
                Expanded(
                  child: _ActionButton(
                    label: 'وصل للموقع',
                    color: Colors.indigo,
                    onTap: () => provider.markTaxiArrived(request.id),
                  ),
                ),
              ] else if (isArrived) ...[
                Expanded(
                  child: _ActionButton(
                    label: 'استلام الزبون',
                    color: Colors.teal,
                    onTap: () => provider.markTaxiPickedUp(request.id),
                  ),
                ),
              ] else if (isPickedUp || isTrip) ...[
                Expanded(
                  child: _ActionButton(
                    label: 'تم الوصول',
                    color: Colors.green,
                    onTap: () => provider.completeTaxiRequest(request.id),
                  ),
                ),
              ] else if (isRejected || isCancelled) ...[
                Expanded(
                  child: _ActionButton(
                    label: isCancelled ? 'ملغي' : 'مرفوض',
                    color: Colors.grey,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isCancelled
                                ? 'تم إلغاء هذا الطلب'
                                : 'تم رفض هذا الطلب ولا يمكن تنفيذه',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 8),
            Text(
              'الطلب الجديد بانتظار قرارك',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontFamily: 'Cairo',
              ),
            ),
          ] else if (isCancelRequested) ...[
            const SizedBox(height: 8),
            Text(
              'الزبون طلب إلغاء الرحلة. اختر الموافقة أو رفض الإلغاء.',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaxiRequestPreview extends StatelessWidget {
  final TaxiRequest request;

  const _TaxiRequestPreview({
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                const Icon(Icons.local_taxi_rounded, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.customerNameAr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  request.pickupAddressAr,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          Text(
            request.statusAr,
            style: const TextStyle(fontSize: 11, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }
}

class _DriverDeliveryOrderCard extends StatelessWidget {
  final ActiveOrder order;

  const _DriverDeliveryOrderCard({
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
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
              const Icon(CupertinoIcons.bag_fill,
                  color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طلب مطعم #${order.orderNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'جديد',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order.itemsNameAr,
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${order.price.toPrice()} د.ع',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              Row(
                children: [
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    minimumSize: Size.zero,
                    onPressed: () => provider.rejectDeliveryOrder(order.id),
                    child: Text('رفض',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                    minimumSize: Size.zero,
                    onPressed: () => provider.acceptDeliveryOrder(order.id),
                    child: Text('موافقة',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverActiveDeliveryCard extends StatelessWidget {
  final ActiveOrder order;

  const _DriverActiveDeliveryCard({
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final delivered = order.deliveryStatusKey == 'delivered';
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
          Text(
            'طلب #${order.orderNumber}',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 6),
          Text(
            order.deliveryStatusAr ?? 'قيد التوصيل',
            style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (order.deliveryStatusKey == 'accepted')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: Size.zero,
                  onPressed: () => provider.markDeliveryPickedUp(order.id),
                  child: Text('استلام الطلب',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              if (order.deliveryStatusKey == 'picked_up')
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: Size.zero,
                  onPressed: () => provider.markDeliveryCompleted(order.id),
                  child: Text('تم التسليم',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              if (delivered)
                const Icon(CupertinoIcons.checkmark_seal_fill,
                    color: Colors.green),
            ],
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
  final Color accentColor;

  const _TopCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.96),
            const Color(0xFF111111)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceModeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ServiceModeChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
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
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_taxi_rounded,
              size: 54, color: AppColors.accent),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              height: 1.4,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}
