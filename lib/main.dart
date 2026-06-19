import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
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
import 'screens/driver/driver_pending_approval_screen.dart';
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
import 'core/notifications/push_notification_inbox.dart';
import 'services/supabase_service.dart';
import 'widgets/app_logo.dart';
import 'utils/role_switch_notifications.dart';
import 'widgets/customer_order_notifications.dart';
import 'widgets/exit_confirm_scope.dart';
import 'widgets/merchant_order_cross_role_alert.dart';
import 'widgets/safe_bottom_bar.dart';
import 'widgets/app_update_gate.dart';
import 'widgets/order_tracking_sheet.dart';
import 'models/app_models.dart';
import 'screens/merchant/order_details_screen.dart';

Future<void> main() async {
  // معالج عام يمنع أي "شاشة رمادية" صامتة: بدل تعطّل الإطار الأول بدون أثر،
  // نعرض واجهة بديلة مفهومة للمستخدم مع تسجيل الخطأ في سجلّات النظام.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    return AppErrorFallback(details: details);
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER_ERROR: ${details.exceptionAsString()}');
  };

  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('PLATFORM_ERROR: $error');
        return true;
      };

      // نبدأ التطبيق فوراً مع Splash، ونحمّل الإعدادات في الخلفية
      // حتى لا تبقى شاشة بيضاء بسبب انتظار Mapbox/Supabase/Push.

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppProvider()),
          ],
          child: const AlGhaithApp(),
        ),
      );

      // bootstrap في الخلفية — لا يمنع ظهور الواجهة
      _bootstrapAsync();
    },
    (error, stack) {
      debugPrint('ZONE_ERROR: $error');
    },
  );
}

Future<void> _bootstrapAsync() async {
  try {
    AppConfig.validate(throwOnError: false);
    await SupabaseService.initialize();
    await PushNotificationService.instance.initialize();
    await configureAppSystemUi();
  } catch (e) {
    debugPrint('Bootstrap error: $e');
  }
}

/// واجهة بديلة تُعرض إذا فشل بناء أي شاشة — بدل شاشة رمادية فارغة.
class AppErrorFallback extends StatelessWidget {
  final FlutterErrorDetails? details;

  const AppErrorFallback({super.key, this.details});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: AppColors.scaffold,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.refresh_rounded,
                  size: 56,
                  color: AppColors.accent,
                ),
                SizedBox(height: 16),
                Text(
                  'حدث خطأ غير متوقع',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'يرجى إعادة فتح التطبيق. إذا استمرت المشكلة تواصل مع الدعم.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF666666),
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

class AlGhaithApp extends StatefulWidget {
  const AlGhaithApp({super.key});

  @override
  State<AlGhaithApp> createState() => _AlGhaithAppState();
}

class _AlGhaithAppState extends State<AlGhaithApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // تسجيل مفتاح Root Navigator لإظهار نافذة طلب التكسي المنبثقة من الإشعارات
    PushNotificationService.setRootNavigatorKey(_navigatorKey);
    // عند الضغط على إشعار التكسي من شريط الإشعارات → افتح نافذة الطلب
    PushNotificationInbox.onTaxiNotificationTapped = (requestId) {
      debugPrint('TaxiPushAction: فتح طلب $requestId من الإشعار');
      _showTaxiDialogForRequest(requestId);
    };
  }

  /// فتح نافذة طلب التكسي بقبول/رفض عند الضغط على الإشعار الخارجي
  void _showTaxiDialogForRequest(String requestId) {
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      // نحتاج provider لتنفيذ القبول/الرفض
      final provider = context.read<AppProvider>();

      // البحث عن الطلب في القائمة
      final request = _findTaxiRequest(provider, requestId);
      if (request == null) {
        debugPrint('TaxiPush: request $requestId not found yet, will try after refresh');
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _TaxiRequestDialog(
          request: request,
          requestId: requestId,
        ),
      );
    });
  }

  /// البحث عن طلب تكسي في قائمة الطلبات
  TaxiRequest? _findTaxiRequest(AppProvider provider, String requestId) {
    for (final request in provider.visibleTaxiIncomingRequests) {
      if (request.id == requestId) return request;
    }
    for (final request in provider.visibleTaxiActiveRequests) {
      if (request.id == requestId) return request;
    }
    for (final request in provider.visibleTaxiCompletedRequests) {
      if (request.id == requestId) return request;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

// واجهة اختيار الشاشة المناسبة بناءً على حالة الحساب
    Widget getHome() {
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
        if (!appProvider.hasDriverProfile) {
          return const ExitConfirmScope(child: DriverSetupScreen());
        }
        if (!appProvider.isDriverApproved) {
          return const ExitConfirmScope(child: DriverPendingApprovalScreen());
        }
        return const ExitConfirmScope(child: DriverShell());
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

      return MerchantOrderCrossRoleAlert(child: MainShell());
    }

    return PushNotificationLifecycleScope(
      child: MaterialApp(
        title: 'الغيث',
        navigatorKey: _navigatorKey,
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
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                // طبقة Material جذرية تمنع ظهور النص بخط أصفر في الشاشات
                // المبنية على Cupertino دون Material أب.
                child: Material(
                  type: MaterialType.transparency,
                  child: child!,
                ),
              ),
            ),
          );
        },
        home: AppUpdateGate(buildContent: getHome),
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

class _PushNotificationLifecycleScopeState
    extends State<PushNotificationLifecycleScope> with WidgetsBindingObserver {
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
  final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
  Timer? _orderRefreshTimer;
  Map<String, CustomerOrderSnapshot> _lastOrderSnapshots = {};
  OverlayEntry? _notificationEntry;
  final List<CustomerBannerData> _pendingBanners = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AppProvider>().addListener(_onAppProviderChanged);
    PushNotificationService.instance.setOnNotificationOpened((data) {
      if (!mounted) return;
      context.read<AppProvider>().handleNotificationOpen(data);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
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
      // فتح تفاصيل الطلب إذا كان هناك orderId معلّق من الإشعار
      _openPendingOrderDetail();
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
    final clamped = tab.clamp(0, 4);
    if (_currentIndex != clamped) {
      setState(() => _currentIndex = clamped);
    }
  }

  Widget _buildHomeTab() {
    return Navigator(
      key: _homeNavigatorKey,
      onGenerateRoute: (settings) {
        return CupertinoPageRoute(
          settings: settings,
          builder: (context) {
            if (settings.name == '/') {
              return const HomeScreen();
            }
            return const HomeScreen();
          },
        );
      },
    );
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

  /// فتح تفاصيل الطلب إذا كان هناك orderId معلّق من الإشعار
  void _openPendingOrderDetail() {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final orderId = provider.takePendingOrderId('customer');
    if (orderId == null || orderId.isEmpty) return;

    // ننتظر قليلاً حتى يتم تحميل الطلبات ثم نفتح التفاصيل
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final updatedProvider = context.read<AppProvider>();
      final order = updatedProvider.orders.where((o) => o.id == orderId).firstOrNull;
      if (order == null) return;
      showCupertinoModalPopup(
        context: context,
        builder: (context) => OrderTrackingSheet(order: order),
      );
    });
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
    final cartCount = appProvider.cartCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screens = [
      _buildHomeTab(),
      const FavoritesScreen(),
      const CartScreen(),
      const OrdersScreen(),
      const AccountScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex == 0) {
          final canPop = await _homeNavigatorKey.currentState?.maybePop() ?? false;
          if (canPop) return;
        } else {
          setState(() => _currentIndex = 0);
          return;
        }
        // إذا كنا في التبويب الرئيسي ولا يوجد صفحات للرجوع، نعرض تأكيد الخروج
        final shouldExit = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black54,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              surfaceTintColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'تأكيد الخروج',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
              content: const Text(
                'هل تريد الخروج من تطبيق الغيث؟',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
              actionsAlignment: MainAxisAlignment.start,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'خروج',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
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
          // إرجاع جميع الصفحات داخل تبويب الرئيسية حتى يعود المستخدم مباشرة
          _homeNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isActive
              ? FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: iconWidget)
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

  Widget _buildSpecialCartItemCompact(int index, IconData icon, int count) {
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

/// نافذة منبثقة لطلب التكسي — تظهر عند الضغط على الإشعار الخارجي
class _TaxiRequestDialog extends StatefulWidget {
  final TaxiRequest request;
  final String requestId;

  const _TaxiRequestDialog({
    required this.request,
    required this.requestId,
  });

  @override
  State<_TaxiRequestDialog> createState() => _TaxiRequestDialogState();
}

class _TaxiRequestDialogState extends State<_TaxiRequestDialog> {
  bool _isBusy = false;
  String? _resultMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final req = widget.request;

    return AlertDialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('🚕', style: TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.requestNumber,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      req.customerNameAr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _detailRow(Icons.trip_origin, 'نقطة الانطلاق', req.pickupAddressAr),
          const SizedBox(height: 10),
          _detailRow(Icons.location_on, 'الوجهة', req.dropoffAddressAr),
          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  '${req.fare} د.ع',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (req.rideTypeAr.isNotEmpty)
                  Text(
                    req.rideTypeAr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'Cairo',
                    ),
                  ),
              ],
            ),
          ),

          if (_resultMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _resultMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _resultMessage!.contains('✅')
                    ? Colors.green
                    : Colors.orange,
                fontFamily: 'Cairo',
              ),
            ),
          ],

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : () => _reject(),
                    icon: _isBusy
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close, size: 20),
                    label: const Text('رفض', style: TextStyle(fontSize: 15, fontFamily: 'Cairo')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : () => _accept(),
                    icon: _isBusy
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('قبول', style: TextStyle(fontSize: 15, fontFamily: 'Cairo')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dark ? Colors.white70 : Colors.black87, fontFamily: 'Cairo')),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _accept() async {
    setState(() { _isBusy = true; _resultMessage = null; });
    try {
      await context.read<AppProvider>().acceptTaxiRequest(widget.requestId);
      if (!mounted) return;
      setState(() => _resultMessage = '✅ تم قبول الطلب بنجاح');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() { _resultMessage = '❌ تعذر قبول الطلب'; _isBusy = false; });
    }
  }

  Future<void> _reject() async {
    setState(() { _isBusy = true; _resultMessage = null; });
    try {
      await context.read<AppProvider>().rejectTaxiRequest(widget.requestId);
      if (!mounted) return;
      setState(() => _resultMessage = '⏭️ تم رفض الطلب');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() { _resultMessage = '❌ تعذر رفض الطلب'; _isBusy = false; });
    }
  }
}
