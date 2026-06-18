import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_logo.dart';

import 'tabs/overview_tab.dart';
import 'tabs/merchants_tab.dart';
import 'tabs/couriers_tab.dart';
import 'tabs/drivers_tab.dart';
import 'tabs/home_categories_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final merchants = provider.allMerchants;
    final couriers = provider.allCouriers;
    final drivers = provider.allDrivers;

    final pendingMerchants = merchants.where((m) =>
      m['isApproved'] != true && (m['approvalStatus']?.toString() ?? 'pending') == 'pending'
    ).length;

    final pendingCouriers = couriers.where((c) =>
      c['isApproved'] != true && (c['approvalStatus']?.toString() ?? 'pending') == 'pending'
    ).length;

    final pendingDrivers = drivers.where((d) =>
      d['isApproved'] != true && (d['approvalStatus']?.toString() ?? 'pending') == 'pending'
    ).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: AppLogo(size: 28),
        ),
        title: const Text(
          'مركز التحكم',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1A1A1A)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          isScrollable: true,
          tabs: [
            const Tab(text: 'نظرة عامة', icon: Icon(Icons.dashboard_rounded, size: 20)),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('التجار'),
                  if (pendingMerchants > 0) ...[
                    const SizedBox(width: 6),
                    CountBadge(count: pendingMerchants, color: Colors.red),
                  ]
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('المندوبين'),
                  if (pendingCouriers > 0) ...[
                    const SizedBox(width: 6),
                    CountBadge(count: pendingCouriers, color: Colors.red),
                  ]
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('السائقين'),
                  if (pendingDrivers > 0) ...[
                    const SizedBox(width: 6),
                    CountBadge(count: pendingDrivers, color: Colors.red),
                  ]
                ],
              ),
            ),
            const Tab(text: 'الأقسام', icon: Icon(Icons.grid_view_rounded, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OverviewTab(reports: provider.adminReports ?? const {}),
          const MerchantManagementTab(),
          const CourierManagementTab(),
          const DriverManagementTab(),
          const HomeCategoriesTab(),
        ],
      ),
    );
  }
}
