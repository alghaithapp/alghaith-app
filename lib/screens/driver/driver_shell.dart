import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_image.dart';

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
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = provider.lang == 'ar';
    final accentColor = provider.driverAcceptsBoth
        ? Colors.green
        : provider.driverAcceptsDelivery
            ? Colors.blue
            : Colors.orange;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
      body: SafeArea(bottom: false, child: _screens[_currentIndex]),
      bottomNavigationBar: Container(
        height: 90,
        decoration: BoxDecoration(
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
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, CupertinoIcons.graph_square_fill, accentColor,
                isAr ? 'الرئيسية' : 'Home'),
            if (provider.driverAcceptsTaxi || provider.driverAcceptsDelivery)
              _navItem(1, CupertinoIcons.bell_fill, accentColor,
                  isAr ? 'الطلبات' : 'Requests'),
            if (provider.driverAcceptsTaxi || provider.driverAcceptsDelivery)
              _navItem(2, CupertinoIcons.car_detailed, accentColor,
                  isAr ? 'الرحلات' : 'Trips'),
            _navItem(3, CupertinoIcons.person_fill, accentColor,
                isAr ? 'الحساب' : 'Account'),
          ],
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

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAr = provider.lang == 'ar';
    final profile = provider.driverProfile ?? const {};
    final typeLabel = isAr
        ? provider.driverServiceModeLabelAr
        : provider.driverServiceModeLabelEn;
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
          isAr ? 'لوحة السائق' : 'Driver Dashboard',
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
              title: isAr
                  ? 'أهلاً ${profile['name'] ?? 'بك'}'
                  : 'Welcome ${profile['name'] ?? 'driver'}',
              subtitle:
                  isAr ? 'نوع الحساب: $typeLabel' : 'Account type: $typeLabel',
              icon: CupertinoIcons.car_fill,
              accentColor: provider.driverAcceptsBoth
                  ? Colors.green
                  : provider.driverAcceptsDelivery
                      ? Colors.blue
                      : Colors.orange,
            ),
            const SizedBox(height: 10),
            _ServiceModeChip(
              label: typeLabel,
              color: provider.driverAcceptsBoth
                  ? Colors.green
                  : provider.driverAcceptsDelivery
                      ? Colors.blue
                      : Colors.orange,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _StatBox(
                        label: isAr ? 'جديد' : 'New',
                        value: '$newCount',
                        color: provider.driverAcceptsBoth
                            ? Colors.green
                            : provider.driverAcceptsDelivery
                                ? Colors.blue
                                : Colors.orange)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatBox(
                        label: isAr ? 'نشط' : 'Active',
                        value: '$activeCount',
                        color: provider.driverAcceptsTaxi &&
                                provider.driverAcceptsDelivery
                            ? Colors.deepPurple
                            : provider.driverAcceptsDelivery
                                ? Colors.blue
                                : Colors.orange)),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatBox(
                        label: isAr ? 'مكتمل' : 'Done',
                        value: '$doneCount',
                        color: provider.driverAcceptsBoth
                            ? Colors.green
                            : Colors.teal)),
              ],
            ),
            const SizedBox(height: 16),
            _SectionTitle(
              title: isAr ? 'آخر الطلبات' : 'Latest requests',
              subtitle: isAr
                  ? 'تابع الطلبات الجديدة وقم بقبولها بسرعة'
                  : 'Track and manage incoming taxi requests',
            ),
            const SizedBox(height: 8),
            _ServiceModeChip(
              label: typeLabel,
              color: provider.driverAcceptsBoth
                  ? Colors.green
                  : provider.driverAcceptsDelivery
                      ? Colors.blue
                      : Colors.orange,
            ),
            const SizedBox(height: 12),
            if (!provider.driverAcceptsTaxi && !provider.driverAcceptsDelivery)
              _EmptyState(
                isAr: isAr,
                title: isAr ? 'لا توجد خدمات مفعلة' : 'No services enabled',
                subtitle: isAr
                    ? 'فعّل التكسي أو التوصيل من إعدادات الحساب'
                    : 'Enable taxi or delivery from account settings',
              )
            else if (provider.visibleTaxiRequests.isEmpty &&
                provider.visibleDeliveryIncomingOrders.isEmpty)
              _EmptyState(
                isAr: isAr,
                title: isAr ? 'لا توجد طلبات حتى الآن' : 'No requests yet',
                subtitle: isAr
                    ? 'ستظهر هنا الطلبات الجديدة فور إرسالها من الزبائن.'
                    : 'New requests will appear here as soon as customers send them.',
              )
            else ...[
              if (provider.driverAcceptsTaxi) ...[
                _SectionTitle(
                  title: isAr ? 'طلبات التكسي' : 'Taxi requests',
                  subtitle: isAr
                      ? 'الطلبات المتاحة لخدمة التكسي'
                      : 'Requests for the taxi service',
                ),
                const SizedBox(height: 10),
                if (provider.visibleTaxiRequests.isEmpty)
                  _EmptyState(
                    isAr: isAr,
                    title: isAr ? 'لا توجد طلبات تكسي' : 'No taxi requests',
                    subtitle: isAr
                        ? 'عندما يطلب الزبون تكسي ستظهر هنا'
                        : 'Taxi requests will show here',
                  )
                else
                  ...provider.visibleTaxiRequests.take(3).map(
                        (request) => _TaxiRequestPreview(
                          request: request,
                          isAr: isAr,
                        ),
                      ),
              ],
              if (provider.driverAcceptsDelivery) ...[
                const SizedBox(height: 12),
                _SectionTitle(
                  title: isAr ? 'طلبات المطاعم' : 'Restaurant orders',
                  subtitle: isAr
                      ? 'طلبات التوصيل المفعلة على حسابك'
                      : 'Delivery requests enabled for your account',
                ),
                const SizedBox(height: 10),
                if (provider.visibleDeliveryIncomingOrders.isEmpty)
                  _EmptyState(
                    isAr: isAr,
                    title:
                        isAr ? 'لا توجد طلبات مطاعم' : 'No restaurant orders',
                    subtitle: isAr
                        ? 'ستظهر طلبات المطاعم هنا'
                        : 'Restaurant delivery requests will show here',
                  )
                else
                  ...provider.visibleDeliveryIncomingOrders.take(3).map(
                        (order) =>
                            _DriverDeliveryOrderCard(order: order, isAr: isAr),
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
    final isAr = provider.lang == 'ar';
    final taxiRequests = provider.visibleTaxiIncomingRequests;
    final deliveryRequests = provider.visibleDeliveryIncomingOrders;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(
          title: isAr ? 'الطلبات الواردة' : 'Incoming requests',
          subtitle: isAr
              ? 'كل الخدمات المفعلة على حسابك'
              : 'All enabled services on your account',
        ),
        const SizedBox(height: 12),
        if (!provider.driverAcceptsTaxi && !provider.driverAcceptsDelivery)
          _EmptyState(
            isAr: isAr,
            title: isAr ? 'لا توجد خدمات مفعلة' : 'No services enabled',
            subtitle: isAr
                ? 'فعّل التكسي أو التوصيل من إعدادات الحساب'
                : 'Enable taxi or delivery from account settings',
          )
        else if (taxiRequests.isEmpty && deliveryRequests.isEmpty)
          _EmptyState(
            isAr: isAr,
            title: isAr ? 'لا توجد طلبات' : 'No requests',
            subtitle: isAr
                ? 'ستظهر الطلبات هنا عندما تصل من الزبائن.'
                : 'Requests will show here when customers send them.',
          )
        else ...[
          if (provider.driverAcceptsTaxi) ...[
            _SectionTitle(
              title: isAr ? 'طلبات التكسي' : 'Taxi requests',
              subtitle: isAr
                  ? 'الطلبات الخاصة بنقل الزبائن'
                  : 'Passenger ride requests',
            ),
            const SizedBox(height: 10),
            if (taxiRequests.isEmpty)
              _EmptyState(
                isAr: isAr,
                title: isAr ? 'لا توجد طلبات تكسي' : 'No taxi requests',
                subtitle: isAr
                    ? 'عندما يطلب الزبون تكسي ستظهر هنا'
                    : 'Taxi requests will appear here',
              )
            else
              ...taxiRequests.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TaxiRequestCard(request: request, isAr: isAr),
                ),
              ),
          ],
          if (provider.driverAcceptsDelivery) ...[
            const SizedBox(height: 14),
            _SectionTitle(
              title: isAr ? 'طلبات المطاعم' : 'Restaurant orders',
              subtitle: isAr
                  ? 'طلبات التوصيل المفعلة على الحساب'
                  : 'Delivery orders enabled on your account',
            ),
            const SizedBox(height: 10),
            if (deliveryRequests.isEmpty)
              _EmptyState(
                isAr: isAr,
                title: isAr ? 'لا توجد طلبات مطاعم' : 'No restaurant requests',
                subtitle: isAr
                    ? 'عندما يصلك طلب مطعم سيظهر هنا'
                    : 'Restaurant requests will appear here',
              )
            else
              ...deliveryRequests.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DriverDeliveryOrderCard(order: order, isAr: isAr),
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
    final isAr = provider.lang == 'ar';
    final taxiActive = provider.visibleTaxiActiveRequests;
    final deliveryActive = provider.visibleDeliveryActiveOrders;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(
          title: isAr ? 'الخدمات النشطة' : 'Active services',
          subtitle: isAr
              ? 'الطلبات المقبولة أو الجاري تنفيذها'
              : 'Accepted or in-progress requests',
        ),
        const SizedBox(height: 12),
        if (!provider.driverAcceptsTaxi && !provider.driverAcceptsDelivery)
          _EmptyState(
            isAr: isAr,
            title: isAr ? 'لا توجد خدمات مفعلة' : 'No services enabled',
            subtitle: isAr
                ? 'فعّل التكسي أو التوصيل من إعدادات الحساب'
                : 'Enable taxi or delivery from account settings',
          )
        else if (taxiActive.isEmpty && deliveryActive.isEmpty)
          _EmptyState(
            isAr: isAr,
            title: isAr ? 'لا توجد رحلات أو طلبات نشطة' : 'No active requests',
            subtitle: isAr
                ? 'عند قبول أي طلب سيظهر هنا.'
                : 'Accepted requests will appear here.',
          )
        else ...[
          if (provider.driverAcceptsTaxi) ...[
            _SectionTitle(
              title: isAr ? 'رحلات التكسي' : 'Taxi trips',
              subtitle: isAr
                  ? 'الطلبات المقبولة أو قيد التنفيذ'
                  : 'Accepted or in-progress taxi rides',
            ),
            const SizedBox(height: 10),
            if (taxiActive.isEmpty)
              _EmptyState(
                isAr: isAr,
                title: isAr ? 'لا توجد رحلات تكسي' : 'No taxi trips',
                subtitle: isAr
                    ? 'ستظهر هنا طلبات التكسي النشطة'
                    : 'Active taxi requests will appear here',
              )
            else
              ...taxiActive.map(
                (request) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TaxiRequestCard(request: request, isAr: isAr),
                ),
              ),
          ],
          if (provider.driverAcceptsDelivery) ...[
            const SizedBox(height: 14),
            _SectionTitle(
              title: isAr ? 'طلبات المطاعم النشطة' : 'Active delivery orders',
              subtitle: isAr
                  ? 'الطلبات المقبولة أو الجاري توصيلها'
                  : 'Accepted or in-progress restaurant deliveries',
            ),
            const SizedBox(height: 10),
            if (deliveryActive.isEmpty)
              _EmptyState(
                isAr: isAr,
                title:
                    isAr ? 'لا توجد طلبات مطاعم نشطة' : 'No active deliveries',
                subtitle: isAr
                    ? 'ستظهر هنا طلبات المطاعم النشطة'
                    : 'Active delivery orders will appear here',
              )
            else
              ...deliveryActive.map(
                (order) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DriverActiveDeliveryCard(order: order, isAr: isAr),
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
    final isAr = provider.lang == 'ar';
    final profile = provider.driverProfile ?? const {};
    final typeLabel = isAr
        ? provider.driverServiceModeLabelAr
        : provider.driverServiceModeLabelEn;
    final isAvailable = profile['available'] as bool? ?? true;
    final taxiEnabled = provider.driverAcceptsTaxi;
    final deliveryEnabled = provider.driverAcceptsDelivery;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                      isAr ? 'حساب السائق' : 'Driver account',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAr
                          ? 'إدارة ملفك وتوفر الطلبات'
                          : 'Manage your profile and availability',
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
                        isAvailable
                            ? (isAr ? 'متاح' : 'Available')
                            : (isAr ? 'غير متاح' : 'Unavailable'),
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
        _ServiceControlCard(
          isAr: isAr,
          taxiEnabled: taxiEnabled,
          deliveryEnabled: deliveryEnabled,
          onTaxiChanged: (value) =>
              provider.setDriverServiceEnabled('taxi', value),
          onDeliveryChanged: (value) =>
              provider.setDriverServiceEnabled('delivery', value),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ImageUploadCard(
                title: isAr ? 'الصورة الشخصية' : 'Profile photo',
                imageBase64: profile['avatarBase64'] as String?,
                icon: Icons.person,
                onTap: () => _showEditProfileSheet(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ImageUploadCard(
                title: isAr ? 'صورة السيارة' : 'Car photo',
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
          activeThumbColor: Colors.orange,
          tileColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            isAr ? 'التوفر' : 'Availability',
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            isAvailable
                ? (isAr ? 'تستقبل الطلبات الآن' : 'Receiving requests now')
                : (isAr
                    ? 'مؤقتًا لا تستقبل الطلبات'
                    : 'Incoming requests are paused'),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        const SizedBox(height: 12),
        _InfoTile(
            label: isAr ? 'الاسم' : 'Name', value: '${profile['name'] ?? '-'}'),
        _InfoTile(
            label: isAr ? 'الهاتف' : 'Phone',
            value: '${profile['phone'] ?? '-'}'),
        _InfoTile(label: isAr ? 'نوع الحساب' : 'Type', value: typeLabel),
        _InfoTile(
            label: isAr ? 'السيارة' : 'Vehicle',
            value: '${profile['vehicle'] ?? '-'}'),
        _InfoTile(
            label: isAr ? 'اللوحة' : 'Plate',
            value: '${profile['plate'] ?? '-'}'),
        _InfoTile(
            label: isAr ? 'المنطقة' : 'Area',
            value: '${profile['area'] ?? '-'}'),
        if ((profile['notes'] as String?)?.isNotEmpty ?? false)
          _InfoTile(
            label: isAr ? 'ملاحظات' : 'Notes',
            value: '${profile['notes']}',
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.circular(18),
            onPressed: () => _showEditProfileSheet(context),
            child: Text(
              isAr ? 'تعديل الحساب' : 'Edit profile',
              style: const TextStyle(
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
              isAr ? 'تسجيل الخروج' : 'Logout',
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
    final isAr = provider.lang == 'ar';
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
    String driverType = provider.driverType ?? 'taxi';

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
                        isAr ? 'تعديل ملف السائق' : 'Edit driver profile',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ImageUploadCard(
                        title: isAr ? 'الصورة الشخصية' : 'Profile photo',
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
                        title: isAr ? 'صورة السيارة' : 'Car photo',
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
                          isAr ? 'متاح / غير متاح' : 'Available / Unavailable',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          isAvailable
                              ? (isAr ? 'تستقبل الطلبات' : 'Receiving requests')
                              : (isAr
                                  ? 'مؤقتًا غير متصل'
                                  : 'Temporarily offline'),
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                      _editField(
                          isAr ? 'الاسم الكامل' : 'Full name', nameController),
                      _editField(isAr ? 'رقم الهاتف' : 'Phone number',
                          phoneController),
                      _editField(isAr ? 'نوع السيارة' : 'Vehicle type',
                          vehicleController),
                      _editField(isAr ? 'رقم اللوحة' : 'Plate number',
                          plateController),
                      _editField(isAr ? 'منطقة العمل' : 'Working area',
                          areaController),
                      _editField(isAr ? 'ملاحظات' : 'Notes', notesController,
                          maxLines: 3),
                      const SizedBox(height: 8),
                      Text(
                        isAr ? 'نوع الخدمة' : 'Driver type',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _TypePill(
                              label: isAr ? 'سائق تكسي فقط' : 'Taxi only',
                              selected: driverType == 'taxi',
                              onTap: () =>
                                  setSheetState(() => driverType = 'taxi'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TypePill(
                              label: isAr ? 'مندوب توصيل فقط' : 'Delivery only',
                              selected: driverType == 'delivery',
                              onTap: () =>
                                  setSheetState(() => driverType = 'delivery'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _TypePill(
                        label: isAr ? 'الخدمتان معًا' : 'Both services',
                        selected: driverType == 'both',
                        onTap: () => setSheetState(() => driverType = 'both'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          color: Colors.deepOrange,
                          borderRadius: BorderRadius.circular(18),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          onPressed: () async {
                            await provider.setDriverProfile({
                              'type': driverType,
                              'services': {
                                'taxi': driverType == 'taxi' ||
                                    driverType == 'both',
                                'delivery': driverType == 'delivery' ||
                                    driverType == 'both',
                              },
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
                            isAr ? 'حفظ التعديلات' : 'Save changes',
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
          color: selected ? Colors.deepOrange : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? Colors.deepOrange : Colors.grey.shade300),
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
  final bool isAr;
  final bool taxiEnabled;
  final bool deliveryEnabled;
  final ValueChanged<bool> onTaxiChanged;
  final ValueChanged<bool> onDeliveryChanged;

  const _ServiceControlCard({
    required this.isAr,
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
            isAr ? 'الخدمات المفعلة' : 'Enabled services',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAr
                ? 'يمكنك تشغيل التكسي أو التوصيل أو الاثنين معًا'
                : 'Turn taxi, delivery, or both on or off',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              height: 1.35,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          _ServiceToggleRow(
            label: isAr ? 'سائق تكسي' : 'Taxi service',
            subtitle: isAr ? 'يظهر له طلبات التكسي' : 'Receives taxi requests',
            icon: Icons.local_taxi_rounded,
            active: taxiEnabled,
            color: Colors.orange,
            onChanged: onTaxiChanged,
          ),
          const SizedBox(height: 10),
          _ServiceToggleRow(
            label: isAr ? 'مندوب توصيل' : 'Delivery service',
            subtitle:
                isAr ? 'يظهر له طلبات المطاعم' : 'Receives restaurant orders',
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
                isAr
                    ? 'الخدمتان مفعّلتان معًا، وستظهر الطلبات جميعها داخل الحساب.'
                    : 'Both services are on, so all matching requests will appear here.',
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
  final bool isAr;

  const _TaxiRequestCard({
    required this.request,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final isPending = request.statusKey == 'pending';
    final isAccepted = request.statusKey == 'accepted';
    final isOnWay = request.statusKey == 'on_way';
    final isArrived = request.statusKey == 'arrived';
    final isPickedUp = request.statusKey == 'picked_up';
    final isTrip = request.statusKey == 'in_trip';
    final isDone = request.statusKey == 'completed';
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
                        : isRejected
                            ? Colors.red
                            : isAccepted
                                ? Colors.teal
                                : Colors.orange;

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
                  isAr ? request.statusAr : request.statusEn,
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
            '${isAr ? request.customerNameAr : request.customerNameEn} • ${request.fare.toPrice()} د.ع',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 4),
          Text(
            '${isAr ? request.pickupAddressAr : request.pickupAddressEn} → ${isAr ? request.dropoffAddressAr : request.dropoffAddressEn}',
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
                    label: isAr ? 'قبول' : 'Accept',
                    color: Colors.green,
                    onTap: () => provider.acceptTaxiRequest(request.id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: isAr ? 'رفض' : 'Reject',
                    color: Colors.red,
                    onTap: () => provider.rejectTaxiRequest(request.id),
                  ),
                ),
              ] else if (isAccepted) ...[
                Expanded(
                  child: _ActionButton(
                    label: isAr ? 'في الطريق' : 'On the way',
                    color: Colors.lightBlue,
                    onTap: () => provider.markTaxiOnWay(request.id),
                  ),
                ),
              ] else if (isOnWay) ...[
                Expanded(
                  child: _ActionButton(
                    label: isAr ? 'وصل للموقع' : 'Arrived',
                    color: Colors.indigo,
                    onTap: () => provider.markTaxiArrived(request.id),
                  ),
                ),
              ] else if (isArrived) ...[
                Expanded(
                  child: _ActionButton(
                    label: isAr ? 'استلام الزبون' : 'Picked up',
                    color: Colors.teal,
                    onTap: () => provider.markTaxiPickedUp(request.id),
                  ),
                ),
              ] else if (isPickedUp || isTrip) ...[
                Expanded(
                  child: _ActionButton(
                    label: isAr ? 'تم الوصول' : 'Complete',
                    color: Colors.green,
                    onTap: () => provider.completeTaxiRequest(request.id),
                  ),
                ),
              ] else if (isRejected) ...[
                Expanded(
                  child: _ActionButton(
                    label: isAr ? 'مرفوض' : 'Rejected',
                    color: Colors.grey,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isAr
                                ? 'تم رفض هذا الطلب ولا يمكن تنفيذه'
                                : 'This request was rejected and cannot be continued',
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
              isAr
                  ? 'الطلب الجديد بانتظار قرارك'
                  : 'New request waiting for your action',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontFamily: 'Cairo',
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
  final bool isAr;

  const _TaxiRequestPreview({
    required this.request,
    required this.isAr,
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
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_taxi_rounded, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? request.customerNameAr : request.customerNameEn,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAr ? request.pickupAddressAr : request.pickupAddressEn,
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
            isAr ? request.statusAr : request.statusEn,
            style: const TextStyle(fontSize: 11, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }
}

class _DriverDeliveryOrderCard extends StatelessWidget {
  final ActiveOrder order;
  final bool isAr;

  const _DriverDeliveryOrderCard({
    required this.order,
    required this.isAr,
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
                  color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAr
                      ? 'طلب مطعم #${order.orderNumber}'
                      : 'Restaurant order #${order.orderNumber}',
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
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isAr ? 'جديد' : 'New',
                  style: const TextStyle(
                    color: Colors.orange,
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
            isAr ? order.itemsNameAr : order.itemsNameEn,
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
                    child: Text(isAr ? 'رفض' : 'Reject',
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
                    child: Text(isAr ? 'موافقة' : 'Accept',
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
  final bool isAr;

  const _DriverActiveDeliveryCard({
    required this.order,
    required this.isAr,
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
            isAr ? 'طلب #${order.orderNumber}' : 'Order #${order.orderNumber}',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
          ),
          const SizedBox(height: 6),
          Text(
            isAr
                ? (order.deliveryStatusAr ?? 'قيد التوصيل')
                : (order.deliveryStatusEn ?? 'Out for delivery'),
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
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                  minimumSize: Size.zero,
                  onPressed: () => provider.markDeliveryPickedUp(order.id),
                  child: Text(isAr ? 'استلام الطلب' : 'Pick Up',
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
                  child: Text(isAr ? 'تم التسليم' : 'Delivered',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_taxi_rounded, size: 54, color: Colors.orange),
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
