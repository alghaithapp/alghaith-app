import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../widgets/app_logo.dart';

enum AdminNavItem {
  overview,
  merchants,
  couriers,
  drivers,
  accounts,
  homeCategories,
  appUpdate,
  reports,
  auditLog,
  settings,
}

extension AdminNavItemLabel on AdminNavItem {
  String get label {
    switch (this) {
      case AdminNavItem.overview:
        return 'نظرة عامة';
      case AdminNavItem.merchants:
        return 'التجار';
      case AdminNavItem.couriers:
        return 'المندوبين';
      case AdminNavItem.drivers:
        return 'السائقين';
      case AdminNavItem.accounts:
        return 'الحسابات';
      case AdminNavItem.homeCategories:
        return 'الأقسام الرئيسية';
      case AdminNavItem.appUpdate:
        return 'تحديث التطبيق';
      case AdminNavItem.reports:
        return 'التقارير';
      case AdminNavItem.auditLog:
        return 'سجل النشاطات';
      case AdminNavItem.settings:
        return 'الإعدادات';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminNavItem.overview:
        return Icons.dashboard_rounded;
      case AdminNavItem.merchants:
        return Icons.store_rounded;
      case AdminNavItem.couriers:
        return Icons.two_wheeler_rounded;
      case AdminNavItem.drivers:
        return Icons.directions_car_rounded;
      case AdminNavItem.accounts:
        return Icons.people_rounded;
      case AdminNavItem.homeCategories:
        return Icons.grid_view_rounded;
      case AdminNavItem.appUpdate:
        return Icons.system_update_rounded;
      case AdminNavItem.reports:
        return Icons.bar_chart_rounded;
      case AdminNavItem.auditLog:
        return Icons.history_rounded;
      case AdminNavItem.settings:
        return Icons.settings_rounded;
    }
  }

  int get pendingCountKey {
    switch (this) {
      case AdminNavItem.merchants:
        return 0;
      case AdminNavItem.couriers:
        return 1;
      case AdminNavItem.drivers:
        return 2;
      default:
        return -1;
    }
  }
}

class AdminSidebar extends StatelessWidget {
  final AdminNavItem selectedItem;
  final ValueChanged<AdminNavItem> onItemSelected;

  const AdminSidebar({
    super.key,
    required this.selectedItem,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final fgColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    final pendingMerchants = provider.allMerchants.where((m) =>
      m['isApproved'] != true &&
      (m['approvalStatus']?.toString() ?? 'pending') == 'pending'
    ).length;

    final pendingCouriers = provider.allCouriers.where((c) =>
      c['isApproved'] != true &&
      (c['approvalStatus']?.toString() ?? 'pending') == 'pending'
    ).length;

    final pendingDrivers = provider.allDrivers.where((d) =>
      d['isApproved'] != true &&
      (d['approvalStatus']?.toString() ?? 'pending') == 'pending'
    ).length;

    final mainItems = <AdminNavItem>[
      AdminNavItem.overview,
      AdminNavItem.merchants,
      AdminNavItem.couriers,
      AdminNavItem.drivers,
      AdminNavItem.accounts,
    ];

    final contentItems = <AdminNavItem>[
      AdminNavItem.homeCategories,
      AdminNavItem.appUpdate,
    ];

    final systemItems = <AdminNavItem>[
      AdminNavItem.reports,
      AdminNavItem.auditLog,
      AdminNavItem.settings,
    ];

    int pendingFor(AdminNavItem item) {
      switch (item) {
        case AdminNavItem.merchants:
          return pendingMerchants;
        case AdminNavItem.couriers:
          return pendingCouriers;
        case AdminNavItem.drivers:
          return pendingDrivers;
        default:
          return 0;
      }
    }

    Widget buildSection(String title, List<AdminNavItem> items) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...items.map((item) => _SidebarItem(
                item: item,
                isSelected: selectedItem == item,
                pendingCount: pendingFor(item),
                onTap: () => onItemSelected(item),
                fgColor: fgColor,
                isDark: isDark,
              )),
        ],
      );
    }

    final hasMerchantStores = provider.merchantStoreName.isNotEmpty;
    final hasCourier = provider.hasCourierProfile;
    final hasDriver = provider.hasDriverProfile;

    return Drawer(
      backgroundColor: bgColor,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const AppLogo(size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الغيث',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'مركز التحكم',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  buildSection('الرئيسية', mainItems),
                  const Divider(indent: 16, endIndent: 16),
                  buildSection('تبديل الحساب', []),
                  _SidebarItem(
                    item: AdminNavItem.overview,
                    isSelected: false,
                    pendingCount: 0,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.setUserRole('customer');
                    },
                    fgColor: fgColor,
                    isDark: isDark,
                    customIcon: Icons.person_rounded,
                    customLabel: 'حساب الزبون',
                  ),
                  _SidebarItem(
                    item: AdminNavItem.overview,
                    isSelected: false,
                    pendingCount: 0,
                    onTap: () {
                      Navigator.of(context).pop();
                      provider.setUserRole('merchant');
                    },
                    fgColor: fgColor,
                    isDark: isDark,
                    customIcon: Icons.store_rounded,
                    customLabel: hasMerchantStores ? 'متجري' : 'إنشاء متجر',
                  ),
                  if (hasCourier)
                    _SidebarItem(
                      item: AdminNavItem.overview,
                      isSelected: false,
                      pendingCount: 0,
                      onTap: () {
                        Navigator.of(context).pop();
                        provider.setUserRole('delivery');
                      },
                      fgColor: fgColor,
                      isDark: isDark,
                      customIcon: Icons.two_wheeler_rounded,
                        customLabel: 'مندوب توصيل',
                    ),
                  if (hasDriver)
                    _SidebarItem(
                      item: AdminNavItem.overview,
                      isSelected: false,
                      pendingCount: 0,
                      onTap: () {
                        Navigator.of(context).pop();
                        provider.setUserRole('driver');
                      },
                      fgColor: fgColor,
                      isDark: isDark,
                      customIcon: Icons.directions_car_rounded,
                      customLabel: 'حساب السائق',
                    ),
                  const Divider(indent: 16, endIndent: 16),
                  buildSection('المحتوى', contentItems),
                  const Divider(indent: 16, endIndent: 16),
                  buildSection('النظام', systemItems),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final AdminNavItem item;
  final bool isSelected;
  final int pendingCount;
  final VoidCallback onTap;
  final Color fgColor;
  final bool isDark;
  final IconData? customIcon;
  final String? customLabel;

  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.pendingCount,
    required this.onTap,
    required this.fgColor,
    required this.isDark,
    this.customIcon,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? (isDark ? AppColors.primary.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.08))
        : Colors.transparent;
    final iconColor = isSelected ? AppColors.primary : fgColor.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(customIcon ?? item.icon, size: 20, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    customLabel ?? item.label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: isSelected ? AppColors.primary : fgColor,
                    ),
                  ),
                ),
                if (pendingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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
