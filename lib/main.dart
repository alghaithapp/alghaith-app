import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/app_bottom_nav_style.dart';
import 'core/ui/app_system_ui.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/account_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/delivery/delivery_setup_screen.dart';
import 'screens/delivery/delivery_pending_approval_screen.dart';
import 'screens/delivery/delivery_shell.dart';
import 'screens/driver/driver_setup_screen.dart';
import 'screens/driver/driver_shell.dart';
import 'screens/phone_login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/customer_setup_screen.dart';
import 'screens/merchant/merchant_setup_screen.dart';
import 'screens/merchant/merchant_pending_approval_screen.dart';
import 'screens/merchant/merchant_shell.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'core/notifications/push_notification_service.dart';
import 'services/supabase_service.dart';
import 'widgets/app_logo.dart';
import 'utils/role_switch_notifications.dart';
import 'widgets/customer_order_notifications.dart';
import 'widgets/exit_confirm_scope.dart';
import 'widgets/safe_bottom_bar.dart';
import 'widgets/startup_splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    AppConfig.validate(throwOnError: false);
    await AppConfig.ensureMapboxToken();
    if (AppConfig.isMapboxConfigured) {
      MapboxOptions.setAccessToken(AppConfig.effectiveMapboxPublicToken);
      MapboxMapsOptions.setLanguage('ar');
    } else {
      debugPrint(
        'Mapbox: MAPBOX_PUBLIC_TOKEN غير مضبوط — أضف pk. في Codemagic أو MAPBOX_PUBLIC_TOKEN على الخادم.',
      );
    }
    await SupabaseService.initialize();
    await PushNotificationService.instance.initialize();
    await configureAppSystemUi();
  } catch (e) {
    debugPrint('Bootstrap error: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const AlGhaithApp(),
    ),
  );
}

// StartupGate removed — splash is handled inside AlGhaithApp after MaterialApp loads.

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFCFA), Color(0xFFFFF0E9), Color(0xFFFCE4DA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                left: -60,
                child: _SplashBlob(
                  size: 240,
                  colors: [Color(0xFFFFD3BF), Color(0xFFFFA46B)],
                ),
              ),
              Positioned(
                bottom: -80,
                right: -60,
                child: _SplashBlob(
                  size: 220,
                  colors: [Color(0xFFFFE0D4), Color(0xFFE84A3A)],
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    AppLogo(size: 150),
                    SizedBox(height: 22),
                    Text(
                      'الغيث',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                        color: Color(0xFF2A1A17),
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFFE84A3A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _SplashBlob({
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class AlGhaithApp extends StatelessWidget {
  const AlGhaithApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    // واجهة اختيار الشاشة المناسبة بناءً على حالة الحساب
    Widget getHome() {
      if (!appProvider.isReady || appProvider.isLoggingIn || appProvider.isRestoring) {
        return const StartupSplashScreen();
      }

      if (!appProvider.hasPhoneSession && !appProvider.isGuestMode) {
        return const ExitConfirmScope(child: PhoneLoginScreen());
      }

      if (!appProvider.hasSelectedRole) {
        return const ExitConfirmScope(child: RoleSelectionScreen());
      }

      if (appProvider.userRole == 'merchant') {
        if (!appProvider.hasCompletedMerchantProfile) {
          return const ExitConfirmScope(child: MerchantSetupScreen());
        }
        if (!appProvider.isMerchantApproved) {
          return const ExitConfirmScope(child: MerchantPendingApprovalScreen());
        }
        return const ExitConfirmScope(child: MerchantShell());
      } else if (appProvider.userRole == 'driver') {
        return appProvider.hasDriverProfile
            ? const ExitConfirmScope(child: DriverShell())
            : const ExitConfirmScope(child: DriverSetupScreen());
      } else if (appProvider.userRole == 'delivery') {
        if (!appProvider.hasCourierProfile) {
          return const ExitConfirmScope(child: DeliverySetupScreen());
        }
        if (!appProvider.isCourierApproved) {
          return const ExitConfirmScope(child: DeliveryPendingApprovalScreen());
        }
        return const ExitConfirmScope(child: DeliveryShell());
      } else if (appProvider.userRole == 'admin') {
        return const ExitConfirmScope(child: AdminDashboardScreen());
      }

      if (appProvider.isCustomer &&
          !appProvider.hasCompletedCustomerProfile &&
          !appProvider.isGuestMode) {
        return const ExitConfirmScope(child: CustomerSetupScreen());
      }

      return const ExitConfirmScope(child: MainShell());
    }

    return PushNotificationLifecycleScope(
      child: MaterialApp(
        title: 'الغيث',
        debugShowCheckedModeBanner: false,
        themeMode: appProvider.themeMode,
        // تحديد لون الخلفية الافتراضي لمنع الشاشة الرصاصية
        color: AppColors.scaffold,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        builder: (context, child) {
          return AppSystemUiScope(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Material(
                type: MaterialType.transparency,
                child: child!,
              ),
            ),
          );
        },
        home: getHome(),
      ),
    );
  }
}

class PushNotificationLifecycleScope extends StatefulWidget {
  final Widget child;

  const PushNotificationLifecycleScope({super.key, required this.child});

  @override
  State<PushNotificationLifecycleScope> createState() =>
      _PushNotificationLifecycleScopeState();
}

class _PushNotificationLifecycleScopeState extends State<PushNotificationLifecycleScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(PushNotificationService.instance.onAppResumed());
      if (!mounted) return;
      unawaited(context.read<AppProvider>().refreshCourierApprovalIfNeeded());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PushNotificationService.instance.onAppResumed());
      if (!mounted) return;
      unawaited(context.read<AppProvider>().refreshCourierApprovalIfNeeded());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _orderRefreshTimer;
  Map<String, CustomerOrderSnapshot> _lastOrderSnapshots = {};
  OverlayEntry? _notificationEntry;
  final List<CustomerBannerData> _pendingBanners = [];

  final List<Widget> _screens = [
    const HomeScreen(),
    const FavoritesScreen(),
    const CartScreen(),
    const OrdersScreen(),
    const AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AppProvider>().addListener(_onAppProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      _lastOrderSnapshots = {
        for (final order in provider.orders)
          order.id: CustomerOrderSnapshot(
            statusKey: order.statusKey,
            deliveryStatusKey: order.deliveryStatusKey,
          ),
      };
      provider.refreshCustomerOrders();
      _orderRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _pollCustomerOrders();
      });
      RoleSwitchNotificationPresenter.showIfNeeded(context);
    });
  }

  @override
  void dispose() {
    context.read<AppProvider>().removeListener(_onAppProviderChanged);
    WidgetsBinding.instance.removeObserver(this);
    _orderRefreshTimer?.cancel();
    _notificationEntry?.remove();
    super.dispose();
  }

  void _onAppProviderChanged() {
    if (!mounted) return;
    final tab = context.read<AppProvider>().takePendingMainTab();
    if (tab == null) return;
    final clamped = tab.clamp(0, _screens.length - 1);
    if (_currentIndex != clamped) {
      setState(() => _currentIndex = clamped);
    }
  }

  Future<void> _pollCustomerOrders() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.refreshCustomerOrders();
    if (!mounted) return;
    provider.tickCustomerNotificationTimers();

    for (final order in provider.orders) {
      final previous = _lastOrderSnapshots[order.id];
      final banner = detectCustomerOrderBanner(
        order: order,
        previous: previous,
      );
      if (banner != null && provider.inAppAlertsEnabled) {
        _pendingBanners.add(banner);
      }
    }

    _lastOrderSnapshots = {
      for (final order in provider.orders)
        order.id: CustomerOrderSnapshot(
          statusKey: order.statusKey,
          deliveryStatusKey: order.deliveryStatusKey,
        ),
    };

    if (provider.inAppAlertsEnabled) {
      _showNextCustomerBanner();
    } else {
      _pendingBanners.clear();
    }
  }

  void _showNextCustomerBanner() {
    if (!context.read<AppProvider>().inAppAlertsEnabled) {
      _pendingBanners.clear();
      return;
    }
    if (_notificationEntry != null) return;
    if (_pendingBanners.isEmpty) return;
    final data = _pendingBanners.removeAt(0);
    _showCustomerBanner(data);
  }

  void _showCustomerBanner(CustomerBannerData data) {
    if (!context.read<AppProvider>().inAppAlertsEnabled) return;
    _notificationEntry?.remove();
    _notificationEntry = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => CustomerOrderNotificationBanner(
        data: data,
        onTap: () {
          context.read<AppProvider>().markNotificationsReadForOrder(
            data.orderNumber,
            'customer',
          );
          entry.remove();
          _notificationEntry = null;
          setState(() => _currentIndex = 3);
          _showNextCustomerBanner();
        },
        onDismiss: () {
          entry.remove();
          _notificationEntry = null;
          _showNextCustomerBanner();
        },
      ),
    );
    _notificationEntry = entry;
    overlay.insert(entry);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _currentIndex = 0);
      _pollCustomerOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final cartCount = appProvider.cart.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
              _buildNavItem(0, CupertinoIcons.house_fill, 'الرئيسية'),
              _buildNavItem(1, CupertinoIcons.heart_fill, 'المفضلة'),
              _buildSpecialCartItemCompact(
                  2, CupertinoIcons.shopping_cart, cartCount),
              _buildNavItem(3, CupertinoIcons.doc_text_fill, 'طلباتي',
                  badgeCount: appProvider.customerActiveOrdersCount),
              _buildNavItem(4, CupertinoIcons.person_fill, 'حسابي'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label,
      {int badgeCount = 0}) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    bool isActive = _currentIndex == index;
    final iconWidget = badgeCount > 0
        ? Badge(
            label: Text('$badgeCount'),
            child: Icon(icon,
                color: isActive
                    ? AppBottomNavStyle.activeColor
                    : CupertinoColors.systemGrey,
                size: 34),
          )
        : Icon(icon,
            color: isActive
                ? AppBottomNavStyle.activeColor
                : CupertinoColors.systemGrey,
            size: 34);
    return GestureDetector(
      onTap: () {
        if (index == 0) {
          appProvider.resetHome();
        }
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isActive
              ? FadeInUp(
                  duration: const Duration(milliseconds: 300), child: iconWidget)
              : iconWidget,
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? AppBottomNavStyle.activeColor
                    : CupertinoColors.systemGrey,
                fontFamily: 'Cairo'),
          )
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSpecialCartItem(
      int index, IconData icon, String label, int count) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -10), // جعل الزر مرتفع قليلاً
            child: ZoomIn(
              duration: const Duration(milliseconds: 400),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppBottomNavStyle.primaryGradientColors,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: Colors.white, size: 28),
                    if (count > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Pulse(
                          infinite: true,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle),
                            constraints: const BoxConstraints(
                                minWidth: 18, minHeight: 18),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? AppBottomNavStyle.activeColor
                    : CupertinoColors.systemGrey,
                fontFamily: 'Cairo'),
          )
        ],
      ),
    );
  }

  Widget _buildSpecialCartItemCompact(
      int index, IconData icon, int count) {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -4),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: AppBottomNavStyle.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.28),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(icon, color: Colors.white, size: 27),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
