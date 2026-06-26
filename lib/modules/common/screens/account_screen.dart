import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/account_role_switch.dart';
import '../../../utils/app_update_checker.dart';
import '../../../utils/extensions.dart';
import '../../../utils/helpers.dart';
import '../../../utils/merchant_service_labels.dart';
import '../../merchant/widgets/quick_publish_panel.dart';
import '../../../widgets/app_image.dart';
import '../../../widgets/app_logo.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import 'notifications_screen.dart';
import '../../merchant/screens/merchant_dashboard_screen.dart';
import '../../merchant/screens/merchant_orders_screen.dart';
import '../../merchant/screens/product_form_screen.dart';
import '../../merchant/screens/merchant_products_screen.dart';
import '../../merchant/screens/merchant_store_settings_screen.dart';
import '../../real_estate/screens/real_estate_form_screen.dart';
import 'account_full_screen.dart';
import 'account_deletion_screen.dart';
import 'customer_account_view.dart';
import '../../auth/screens/guest_account_view.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    if (appProvider.isGuestMode) {
      return const GuestAccountView();
    }

    if (appProvider.isMerchant) {
      return const _MerchantAccountView();
    }

    return const CustomerAccountView();
  }
}

class _MerchantAccountView extends StatelessWidget {
  const _MerchantAccountView();

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
        : 'حساب التاجر';
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
          labels.accountTitleAr,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
        ),
        trailing: GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
                builder: (context) => const NotificationsScreen()),
          ),
          child: const Icon(CupertinoIcons.bell_fill,
              color: AppColors.accent, size: 22),
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
                      color: AppColors.accentLight.withValues(alpha: 0.35),
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
            if (appProvider.hasAdminAccess) ...[
              const SizedBox(height: 14),
              _RoleSwitchCard(
                title: 'لوحة الإدارة (Super Admin)',
                subtitle: 'التحكم الكامل في المنصة والتجار',
                icon: CupertinoIcons.shield_fill,
                color: Colors.redAccent,
                onTap: () async {
                  if (!appProvider.isAdmin) {
                    final ok = await appProvider.setUserRole('admin');
                    if (!context.mounted || !ok) return;
                  }
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => const AdminDashboardScreen(),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 14),
            _RoleSwitchCard(
              title: 'بيانات الحساب الكامل',
              subtitle: 'عرض كل بيانات الحساب من مكان واحد',
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
              title: 'تبديل الحساب (الدور)',
              subtitle: 'الانتقال إلى واجهة الزبون أو المندوب أو التاجر',
              icon: Icons.swap_horiz_rounded,
              color: const Color(0xFFE040FB),
              onTap: () => showRoleSwitcher(context, appProvider),
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
                          label: 'المبيعات',
                          value: '${appProvider.totalSales.toPrice()} د.ع',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTile(
                          label: 'الطلبات',
                          value: '${appProvider.merchantOrdersCount}',
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: labels.itemPluralAr,
                          value: '${appProvider.merchantProductCount}',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTile(
                          label: 'الحالة',
                          value: isOpen ? 'مفتوح' : 'مغلق',
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
                    'إدارة الخدمات',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'يمكنك تفعيل أكثر من خدمة لنفس الحساب، ثم النشر في كل خدمة بحسب نوعها.',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      height: 1.5,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ServiceStatusPills(
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
                    final actionLabel = _servicePublishLabel(serviceId);
                    final subtitle = _servicePublishSubtitle(serviceId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ServiceManagementCard(
                        title: serviceLabels.storeLabelAr,
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
                    'إدارة ${labels.storeLabelAr}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 12),
                  _MerchantActionTile(
                    icon: CupertinoIcons.graph_square_fill,
                    title: 'لوحة التاجر',
                    subtitle:
                        'مؤشرات الأداء والملخصات الخاصة بـ ${labels.storeLabelAr}',
                    color: AppColors.accent,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                        builder: (_) => const MerchantDashboardScreen())),
                  ),
                  _MerchantActionTile(
                    icon: CupertinoIcons.square_grid_2x2_fill,
                    title: labels.productsTitleAr,
                    subtitle: 'إضافة وتعديل وحذف ${labels.itemPluralAr}',
                    color: Colors.blue,
                    onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                        builder: (_) => const MerchantProductsScreen())),
                  ),
                  if (merchantServiceUsesOrderFlow(
                      appProvider.merchantActiveServiceId))
                    _MerchantActionTile(
                      icon: CupertinoIcons.list_bullet_below_rectangle,
                      title: 'الطلبات',
                      subtitle: 'التحكم بحالات الطلبات',
                      color: Colors.green,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => const MerchantOrdersScreen(),
                        ),
                      ),
                    ),
                  _MerchantActionTile(
                    icon: CupertinoIcons.pencil_circle,
                    title: 'تعديل بيانات ${labels.storeLabelAr}',
                    subtitle: 'الاسم والوصف والهاتف والعنوان والصور',
                    color: Colors.purple,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const MerchantStoreSettingsScreen(),
                      ),
                    ),
                  ),
                  _MerchantActionTile(
                    icon: CupertinoIcons.power,
                    title: 'فتح / إغلاق ${labels.storeLabelAr}',
                    subtitle: 'تبديل جاهزية الاستقبال',
                    color: isOpen ? Colors.red : Colors.green,
                    onTap: appProvider.toggleMerchantOpenStatus,
                  ),
                  _MerchantActionTile(
                    icon: CupertinoIcons.arrow_2_circlepath,
                    title: 'التحقق من تحديث التطبيق',
                    subtitle: 'تأكد من أنك تستخدم أحدث إصدار',
                    color: const Color(0xFFE84A3A),
                    onTap: () => AppUpdateChecker.checkAndPrompt(context),
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
                    'تفاصيل ${labels.storeLabelAr}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                      label: 'رقم الهاتف',
                      value: showOrDash(appProvider.merchantPhone)),
                  _InfoRow(
                      label: 'واتساب',
                      value: showOrDash(appProvider.merchantWhatsApp)),
                  _InfoRow(
                      label: 'العنوان',
                      value: showOrDash(appProvider.merchantAddress)),
                  _InfoRow(
                      label: 'ساعات العمل',
                      value:
                          '${showOrDash(appProvider.merchantOpenTime)} - ${showOrDash(appProvider.merchantCloseTime)}'),
                  if (!hideFee)
                    _InfoRow(
                        label: 'رسوم التوصيل',
                        value:
                            '${appProvider.merchantDeliveryFee.toPrice()} د.ع')
                  else
                    _InfoRow(
                        label: 'نوع الخدمة',
                        value: 'بدون رسوم مباشرة'),
                  if (profileImageBase64 != null &&
                      profileImageBase64.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InlinePreview(
                      title: 'الصورة الشخصية',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AppImage(
                          imageData: profileImageBase64,
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
                      title: 'نماذج الأعمال',
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
                              child: AppImage(
                                imageData: workSamples[index],
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
            _DeleteAccountButton(
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const AccountDeletionScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _LogoutButton(
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

class _DeleteAccountButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteAccountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: CupertinoColors.systemRed.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(CupertinoIcons.trash,
                color: CupertinoColors.systemRed, size: 20),
            SizedBox(width: 15),
            Text(
              'حذف الحساب نهائياً',
              style: TextStyle(
                color: CupertinoColors.systemRed,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
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
  final VoidCallback onTap;

  const _LogoutButton({
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
            Text('تسجيل الخروج',
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

String _servicePublishLabel(String serviceId) => merchantPublishLabel(serviceId);

String _servicePublishSubtitle(String serviceId) =>
    merchantPublishSubtitle(serviceId);

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
  final List<String> serviceIds;
  final String activeServiceId;
  final Future<void> Function(String serviceId) onActivate;

  const _ServiceStatusPills({
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
              labels.storeLabelAr,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            selected: selected,
            onSelected: (_) => onActivate(serviceId),
            selectedColor: AppColors.accent,
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
  final String title;
  final String subtitle;
  final bool active;
  final String actionLabel;
  final VoidCallback? onActivate;
  final VoidCallback onPublish;

  const _ServiceManagementCard({
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
              ? AppColors.accent.withValues(alpha: 0.06)
              : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.25)
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
                              ? AppColors.accent.withValues(alpha: 0.12)
                              : Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          active ? 'الحالية' : 'مفعلة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            color: active ? AppColors.accent : Colors.green,
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
                backgroundColor: AppColors.accent,
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
