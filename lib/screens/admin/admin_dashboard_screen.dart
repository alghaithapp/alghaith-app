import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';
import 'tabs/overview_tab.dart';
import 'tabs/merchants_tab.dart';
import 'tabs/couriers_tab.dart';
import 'tabs/drivers_tab.dart';
import 'tabs/home_categories_tab.dart';
import 'widgets/admin_sidebar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminNavItem _selectedItem = AdminNavItem.overview;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  void _refreshAll() {
    final provider = context.read<AppProvider>();
    provider.refreshAdminReports();
    provider.refreshAllMerchants();
    provider.refreshAllCouriers();
    provider.refreshAllDrivers();
    provider.refreshHomeCategoriesConfig();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF111118) : const Color(0xFFF8F9FB);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            if (_selectedItem == AdminNavItem.overview) ...[
              const Icon(Icons.dashboard_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
            ],
            Text(
              _selectedItem.label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
      drawer: AdminSidebar(
        selectedItem: _selectedItem,
        onItemSelected: (item) {
          setState(() => _selectedItem = item);
          Navigator.of(context).pop();
        },
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    final provider = context.watch<AppProvider>();

    switch (_selectedItem) {
      case AdminNavItem.overview:
        return OverviewTab(reports: provider.adminReports ?? const {});
      case AdminNavItem.merchants:
        return const MerchantManagementTab();
      case AdminNavItem.couriers:
        return const CourierManagementTab();
      case AdminNavItem.drivers:
        return const DriverManagementTab();
      case AdminNavItem.accounts:
        return _ComingSoon(label: 'إدارة الحسابات');
      case AdminNavItem.homeCategories:
        return const HomeCategoriesTab();
      case AdminNavItem.appUpdate:
        return _ComingSoon(label: 'تحديث التطبيق');
      case AdminNavItem.reports:
        return _ComingSoon(label: 'التقارير');
      case AdminNavItem.auditLog:
        return _ComingSoon(label: 'سجل النشاطات');
      case AdminNavItem.settings:
        return _ComingSoon(label: 'الإعدادات');
    }
  }
}

class _ComingSoon extends StatelessWidget {
  final String label;
  const _ComingSoon({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.construction_rounded,
            size: 64,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قيد التطوير',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
