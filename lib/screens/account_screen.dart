import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../utils/extensions.dart';
import '../utils/translations.dart';
import '../utils/helpers.dart';
import '../utils/merchant_service_labels.dart';
import '../widgets/app_image.dart';
import '../widgets/app_logo.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'addresses_screen.dart';
import 'payment_methods_screen.dart';
import 'app_settings_screen.dart';
import 'merchant/merchant_dashboard_screen.dart';
import 'merchant/merchant_orders_screen.dart';
import 'merchant/product_form_screen.dart';
import 'merchant/merchant_products_screen.dart';
import 'merchant/merchant_store_settings_screen.dart';
import 'real_estate_form_screen.dart';
import 'account_full_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final lang = appProvider.lang;
    final isAr = lang == 'ar';

    if (appProvider.isMerchant) {
      return _MerchantAccountView(isAr: isAr);
    }

    return _CustomerAccountView(lang: lang, isAr: isAr);
  }
}

class _MerchantAccountView extends StatelessWidget {
  final bool isAr;

  const _MerchantAccountView({required this.isAr});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final storeName = appProvider.merchantStoreName;
    final isOpen = appProvider.isMerchantStoreOpen;
    final labels = appProvider.merchantActiveLabels;
    final hideFee = appProvider.merchantActiveServiceId == 'professionals' ||
        appProvider.merchantActiveServiceId == 'restaurant';
    final profileImageBase64 = appProvider.merchantProfileImageBase64;
    final workSamples = appProvider.merchantWorkSampleImagesBase64;
    final showWorkSamples = appProvider.merchantActiveServiceId != 'restaurant';
    final displayStoreName = storeName.trim().isNotEmpty
        ? storeName
        : (isAr ? 'حساب التاجر' : 'Merchant account');
    String showOrDash(String value) =>
        value.trim().isNotEmpty ? value.trim() : '-';

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: Color(0x11000000))),
        leading: const Padding(
          padding: EdgeInsets.only(top: 2),
          child: AppLogo(size: 28),
        ),
        middle: Text(
          isAr ? labels.accountTitleAr : labels.accountTitleEn,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
        ),
        trailing: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
                builder: (context) => const NotificationsScreen()),
          ),
          child: const Icon(CupertinoIcons.bell_fill,
              color: Colors.orange, size: 22),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black, Colors.grey.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: AppImage(
                      imageData: profileImageBase64,
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayStoreName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          showOrDash(appProvider.merchantDescription),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _RoleSwitchCard(
              title: isAr ? 'بيانات الحساب الكامل' : 'Full account data',
              subtitle: isAr
                  ? 'عرض كل بيانات الحساب من مكان واحد'
                  : 'View all account data in one place',
              icon: Icons.badge_rounded,
              color: Colors.purple,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const AccountFullScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _RoleSwitchCard(
              title: isAr ? 'الانتقال إلى حساب الزبون' : 'Switch to customer',
              subtitle: isAr
                  ? 'احتفظ بنفس الدخول واستخدم واجهة الزبون'
                  : 'Keep the same sign-in and use the customer view',
              icon: CupertinoIcons.person_fill,
              color: Colors.orange,
              onTap: () => appProvider.setUserRole('customer'),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: isAr ? 'المبيعات' : 'Sales',
                          value: '${appProvider.totalSales.toPrice()} د.ع',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTile(
                          label: isAr ? 'الطلبات' : 'Orders',
                          value: '${appProvider.merchantOrdersCount}',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label:
                              isAr ? labels.itemPluralAr : labels.itemPluralEn,
                          value: '${appProvider.merchantProductCount}',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTile(
                          label: isAr ? 'الحالة' : 'Status',
                          value: isOpen
                              ? (isAr ? 'مفتوح' : 'Open')
                              : (isAr ? 'مغلق' : 'Closed'),
                          color: isOpen ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'إدارة الخدمات' : 'Service management',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAr
                        ? 'يمكنك تفعيل أكثر من خدمة لنفس الحساب، ثم النشر في كل خدمة بحسب نوعها.'
                        : 'Enable multiple services on one account and publish in each service separately.',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      height: 1.5,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ServiceStatusPills(
                    isAr: isAr,
                    serviceIds: appProvider.merchantServiceIds,
                    activeServiceId: appProvider.merchantActiveServiceId,
                    onActivate: (serviceId) async {
                      await appProvider.setMerchantActiveService(serviceId);
                    },
                  ),
                  const SizedBox(height: 12),
                  ...appProvider.merchantServiceIds.map((serviceId) {
                    final serviceLabels = merchantServiceLabels(serviceId);
                    final isActive =
                        serviceId == appProvider.merchantActiveServiceId;
                    final actionLabel = _servicePublishLabel(serviceId, isAr);
                    final subtitle = _servicePublishSubtitle(serviceId, isAr);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ServiceManagementCard(
                        isAr: isAr,
                        title: isAr
                            ? serviceLabels.storeLabelAr
                            : serviceLabels.storeLabelEn,
                        subtitle: subtitle,
                        active: isActive,
                        actionLabel: actionLabel,
                        onActivate: isActive
                            ? null
                            : () async {
                                await appProvider.setMerchantActiveService(
                                    serviceId);
                              },
                        onPublish: () async {
                          await appProvider.setMerchantActiveService(serviceId);
                          if (!context.mounted) return;
                          _openServicePublisher(context, serviceId);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr
                        ? 'إدارة ${labels.storeLabelAr}'
                        : 'Account management',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 12),
                  _MerchantActionTile(
                    icon: CupertinoIcons.graph_square_fill,
                    title: isAr ? 'لوحة التاجر' : 'Dashboard',
                    subtitle: isAr
                        ? 'مؤشرات الأداء والملخصات الخاصة بـ ${labels.storeLabelAr}'
                        : 'Performance summary and key metrics',
                    color: Colors.orange,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                        builder: (_) => const MerchantDashboardScreen())),
                  ),
                  _MerchantActionTile(
                    icon: CupertinoIcons.square_grid_2x2_fill,
                    title:
                        isAr ? labels.productsTitleAr : labels.productsTitleEn,
                    subtitle: isAr
                        ? 'إضافة وتعديل وحذف ${labels.itemPluralAr}'
                        : 'Add, edit, and delete items',
                    color: Colors.blue,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                        builder: (_) => const MerchantProductsScreen())),
                  ),
                  _MerchantActionTile(
                    icon: CupertinoIcons.list_bullet_below_rectangle,
                    title: isAr ? 'الطلبات' : 'Orders',
                    subtitle: isAr
                        ? 'التحكم بحالات الطلبات'
                        : 'Manage order status updates',
                    color: Colors.green,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                        builder: (_) => const MerchantOrdersScreen())),
                  ),
                  _MerchantActionTile(
                    icon: CupertinoIcons.pencil_circle,
                    title: isAr
                        ? 'تعديل بيانات ${labels.storeLabelAr}'
                        : labels.storeSettingsTitleEn,
                    subtitle: isAr
                        ? 'الاسم والوصف والهاتف والعنوان والصور'
                        : 'Name, phone, WhatsApp, work hours and images',
                    color: Colors.purple,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const MerchantStoreSettingsScreen(),
                      ),
                    ),
                  ),
                  _MerchantActionTile(
                    icon: CupertinoIcons.power,
                    title: isAr
                        ? 'فتح / إغلاق ${labels.storeLabelAr}'
                        : 'Open / Close store',
                    subtitle: isAr
                        ? 'تبديل جاهزية الاستقبال'
                        : 'Toggle the store availability',
                    color: isOpen ? Colors.red : Colors.green,
                    onTap: appProvider.toggleMerchantOpenStatus,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'تفاصيل ${labels.storeLabelAr}' : 'Business details',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                      label: isAr ? 'رقم الهاتف' : 'Phone',
                      value: showOrDash(appProvider.merchantPhone)),
                  _InfoRow(
                      label: isAr ? 'واتساب' : 'WhatsApp',
                      value: showOrDash(appProvider.merchantWhatsApp)),
                  _InfoRow(
                      label: isAr ? 'العنوان' : 'Address',
                      value: showOrDash(appProvider.merchantAddress)),
                  _InfoRow(
                      label: isAr ? 'ساعات العمل' : 'Working hours',
                      value:
                          '${showOrDash(appProvider.merchantOpenTime)} - ${showOrDash(appProvider.merchantCloseTime)}'),
                  if (!hideFee)
                    _InfoRow(
                        label: isAr ? 'رسوم التوصيل' : 'Delivery fee',
                        value:
                            '${appProvider.merchantDeliveryFee.toPrice()} د.ع')
                  else
                    _InfoRow(
                        label: isAr ? 'نوع الخدمة' : 'Service type',
                        value: isAr ? 'بدون رسوم مباشرة' : 'No direct fee'),
                  if (profileImageBase64 != null &&
                      profileImageBase64.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InlinePreview(
                      title: isAr ? 'الصورة الشخصية' : 'Profile photo',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.memory(
                          base64Decode(profileImageBase64),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                  if (showWorkSamples && workSamples.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InlinePreview(
                      title: isAr ? 'نماذج الأعمال' : 'Work samples',
                      child: SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: workSamples.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                base64Decode(workSamples[index]),
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LogoutButton(
              isAr: isAr,
              onTap: () => appProvider.resetAll(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSwitchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleSwitchCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 12,
                      height: 1.4,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_left, size: 16),
          ],
        ),
      ),
    );
  }
}

class _CustomerAccountView extends StatelessWidget {
  final String lang;
  final bool isAr;

  const _CustomerAccountView({
    required this.lang,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        leading: const Padding(
          padding: EdgeInsets.only(top: 2),
          child: AppLogo(size: 28),
        ),
        middle: Text(AppTranslations.t('account', lang),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        trailing: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
                builder: (context) => const NotificationsScreen()),
          ),
          child: const Icon(CupertinoIcons.bell_fill,
              color: Colors.orange, size: 22),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    _CustomerAvatar(appProvider: appProvider),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appProvider.customerName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  fontFamily: 'Cairo')),
                          const SizedBox(height: 4),
                          Text(appProvider.customerPhone,
                              style: const TextStyle(
                                  color: CupertinoColors.systemGrey,
                                  fontSize: 12,
                                  fontFamily: 'Cairo')),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(14),
                      minimumSize: Size.zero,
                      onPressed: () => _showEditProfileDialog(
                        context,
                        appProvider,
                        isAr,
                      ),
                      child: Text(
                        isAr ? 'تعديل' : 'Edit',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              _RoleSwitchCard(
                title: isAr ? 'الانتقال إلى حساب التاجر' : 'Switch to merchant',
                subtitle: isAr
                    ? 'استخدم نفس الحساب وادخل إلى واجهة التاجر'
                    : 'Use the same sign-in and open the merchant view',
                icon: Icons.storefront_rounded,
                color: Colors.deepOrange,
                onTap: () => appProvider.setUserRole('merchant'),
              ),
              const SizedBox(height: 25),
              _RoleSwitchCard(
                title: isAr ? 'بيانات الحساب الكامل' : 'Full account data',
                subtitle: isAr
                    ? 'عرض كل بيانات الحساب من مكان واحد'
                    : 'View all account data in one place',
                icon: Icons.badge_rounded,
                color: Colors.purple,
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const AccountFullScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Container(
                decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildSettingItem(
                      context,
                      CupertinoIcons.location_fill,
                      isAr ? "عناويني" : "My Addresses",
                      color: Colors.orange,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(CupertinoPageRoute(
                              builder: (context) => const AddressesScreen())),
                    ),
                    _buildSettingItem(
                      context,
                      CupertinoIcons.creditcard_fill,
                      isAr ? "طرق الدفع" : "Payment Methods",
                      color: Colors.amber,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(CupertinoPageRoute(
                              builder: (context) =>
                                  const PaymentMethodsScreen())),
                    ),
                    _buildSettingItem(
                      context,
                      CupertinoIcons.doc_text_fill,
                      isAr ? "سجل الطلبات" : "Order History",
                      color: Colors.blue,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(CupertinoPageRoute(
                              builder: (context) => const OrdersScreen())),
                    ),
                    _buildSettingItem(
                      context,
                      CupertinoIcons.settings,
                      isAr ? "الإعدادات" : "Settings",
                      color: Colors.grey,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .push(CupertinoPageRoute(
                              builder: (context) => const AppSettingsScreen())),
                    ),
                    _buildSettingItem(
                      context,
                      Icons.headset_mic,
                      isAr ? "اتصل بنا (واتساب)" : "Contact Us",
                      color: Colors.green,
                      onTap: () => AppHelpers.launchWhatsApp(
                          AppHelpers.supportWhatsAppNumber,
                          isAr
                              ? "مرحبا، أحتاج مساعدة في تطبيق الغيث"
                              : "Hello, I need help with the Al-Ghaith app."),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () => appProvider.resetAll(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(25)),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.power,
                          color: CupertinoColors.systemRed),
                      const SizedBox(width: 15),
                      Text(AppTranslations.t('logout', lang),
                          style: const TextStyle(
                              color: CupertinoColors.systemRed,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, IconData icon, String title,
      {required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          border: Border(
              bottom: BorderSide(
                  color: CupertinoColors.systemGrey6.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 15),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    fontFamily: 'Cairo')),
            const Spacer(),
            Icon(CupertinoIcons.chevron_left,
                color: Colors.grey[300], size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    AppProvider provider,
    bool isAr,
  ) async {
    final nameController = TextEditingController(text: provider.customerName);
    final phoneController = TextEditingController(text: provider.customerPhone);
    String? selectedAvatarBase64 = provider.customerAvatarBase64;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Widget avatarPreview;
            if (selectedAvatarBase64 != null &&
                selectedAvatarBase64!.isNotEmpty) {
              avatarPreview = AppImage(
                imageData: selectedAvatarBase64,
                width: 72,
                height: 72,
                borderRadius: BorderRadius.circular(36),
              );
            } else {
              avatarPreview = const CircleAvatar(
                radius: 36,
                backgroundColor: Colors.orange,
                child: Icon(
                  CupertinoIcons.person_fill,
                  color: Colors.white,
                  size: 38,
                ),
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                isAr ? 'تعديل الملف الشخصي' : 'Edit Profile',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.orange, width: 2),
                          ),
                          child: avatarPreview,
                        ),
                        GestureDetector(
                          onTap: () async {
                            final picked = await AppHelpers.pickImage(context);
                            if (picked == null) return;

                            final bytes = await picked.readAsBytes();
                            setStateDialog(() {
                              selectedAvatarBase64 = base64Encode(bytes);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.camera_fill,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _profileField(
                      label: isAr ? 'الاسم' : 'Name',
                      controller: nameController,
                    ),
                    const SizedBox(height: 12),
                    _profileField(
                      label: isAr ? 'رقم الهاتف' : 'Phone number',
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(isAr ? 'إلغاء' : 'Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await provider.updateCustomerProfile(
                      name: nameController.text,
                      phone: phoneController.text,
                      avatarBase64: selectedAvatarBase64,
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: Text(isAr ? 'حفظ' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _profileField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF7F8FC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final AppProvider appProvider;

  const _CustomerAvatar({required this.appProvider});

  @override
  Widget build(BuildContext context) {
    final avatarBase64 = appProvider.customerAvatarBase64;
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        shape: BoxShape.circle,
      ),
      child: AppImage(
        imageData: avatarBase64,
        borderRadius: BorderRadius.circular(35),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.grey, fontFamily: 'Cairo')),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MerchantActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MerchantActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontFamily: 'Cairo')),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_left,
                color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12, fontFamily: 'Cairo')),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlinePreview extends StatelessWidget {
  final String title;
  final Widget child;

  const _InlinePreview({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final bool isAr;
  final VoidCallback onTap;

  const _LogoutButton({
    required this.isAr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(25)),
        child: Row(
          children: [
            const Icon(CupertinoIcons.power, color: CupertinoColors.systemRed),
            const SizedBox(width: 15),
            Text(isAr ? 'تسجيل الخروج' : 'Logout',
                style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo')),
          ],
        ),
      ),
    );
  }
}

String _servicePublishLabel(String serviceId, bool isAr) {
  switch (serviceId) {
    case 'restaurant':
      return isAr ? 'نشر منيو' : 'Publish menu';
    case 'product':
      return isAr ? 'نشر منتجات' : 'Publish products';
    case 'real_estate':
      return isAr ? 'نشر عقار' : 'Publish property';
    case 'professionals':
      return isAr ? 'تحديث الملف' : 'Update profile';
    case 'cars':
      return isAr ? 'نشر سيارة' : 'Publish car';
    default:
      return isAr ? 'نشر الآن' : 'Publish now';
  }
}

String _servicePublishSubtitle(String serviceId, bool isAr) {
  switch (serviceId) {
    case 'restaurant':
      return isAr
          ? 'أضف وجباتك ومنيو مطعمك من هنا.'
          : 'Add your meals and restaurant menu from here.';
    case 'product':
      return isAr
          ? 'أضف المنتجات واختر القسم الفرعي المناسب.'
          : 'Add products and choose the right sub-category.';
    case 'real_estate':
      return isAr
          ? 'أنشئ إعلان بيع أو إيجار للعقار.'
          : 'Create a sale or rent property listing.';
    case 'professionals':
      return isAr
          ? 'حدّث ملفك المهني وصور أعمالك ووسائل التواصل.'
          : 'Update your professional profile and contact details.';
    case 'cars':
      return isAr
          ? 'أنشئ إعلانًا أو خدمة خاصة بالسيارات.'
          : 'Create a car listing or related service.';
    default:
      return isAr
          ? 'نشر المحتوى الخاص بهذه الخدمة.'
          : 'Publish content for this service.';
  }
}

void _openServicePublisher(
  BuildContext context,
  String serviceId,
) {
  Widget page;
  if (serviceId == 'professionals') {
    page = const MerchantStoreSettingsScreen();
  } else if (serviceId == 'real_estate') {
    page = const RealEstateFormScreen(mode: 'sell');
  } else {
    page = ProductFormScreen(
      isRestaurant: serviceId == 'restaurant',
      serviceId: serviceId,
    );
  }

  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => page),
  );
}

class _ServiceStatusPills extends StatelessWidget {
  final bool isAr;
  final List<String> serviceIds;
  final String activeServiceId;
  final Future<void> Function(String serviceId) onActivate;

  const _ServiceStatusPills({
    required this.isAr,
    required this.serviceIds,
    required this.activeServiceId,
    required this.onActivate,
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
          final labels = merchantServiceLabels(serviceId);
          final selected = serviceId == activeServiceId;
          return ChoiceChip(
            label: Text(
              isAr ? labels.storeLabelAr : labels.storeLabelEn,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            selected: selected,
            onSelected: (_) => onActivate(serviceId),
            selectedColor: Colors.deepOrange,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
            ),
          );
        },
      ),
    );
  }
}

class _ServiceManagementCard extends StatelessWidget {
  final bool isAr;
  final String title;
  final String subtitle;
  final bool active;
  final String actionLabel;
  final VoidCallback? onActivate;
  final VoidCallback onPublish;

  const _ServiceManagementCard({
    required this.isAr,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.actionLabel,
    required this.onActivate,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onActivate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? Colors.deepOrange.withValues(alpha: 0.06)
              : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? Colors.deepOrange.withValues(alpha: 0.25)
                : const Color(0xFFE6E8F0),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.deepOrange.withValues(alpha: 0.12)
                              : Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          active
                              ? (isAr ? 'الحالية' : 'Current')
                              : (isAr ? 'مفعلة' : 'Enabled'),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.deepOrange : Colors.green,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onPublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                actionLabel,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
