import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'providers/app_provider.dart';
import 'utils/translations.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/account_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/delivery/delivery_shell.dart';
import 'screens/driver/driver_setup_screen.dart';
import 'screens/driver/driver_shell.dart';
import 'screens/phone_login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/customer_setup_screen.dart';
import 'screens/merchant/merchant_setup_screen.dart';
import 'screens/merchant/merchant_shell.dart';
import 'services/supabase_service.dart';
import 'widgets/app_logo.dart';
import 'widgets/exit_confirm_scope.dart';
import 'widgets/startup_splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase Init Error: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const StartupGate(),
    ),
  );
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2)).then((_) {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const StartupSplashScreen();
    }
    return const AlGhaithApp();
  }
}

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
      if (!appProvider.isReady) {
        return const StartupSplashScreen();
      }

      if (appProvider.isLoggingIn) {
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppLogo(size: 100),
                SizedBox(height: 30),
                CircularProgressIndicator(color: Colors.orange),
                SizedBox(height: 20),
                Text(
                  'جاري استعادة بياناتك من السحابة...',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }

      if (!appProvider.hasPhoneSession) {
        return const ExitConfirmScope(child: PhoneLoginScreen());
      }

      if (!appProvider.hasSelectedRole) {
        return const ExitConfirmScope(child: RoleSelectionScreen());
      }

      if (appProvider.userRole == 'merchant') {
        return appProvider.merchantStore == null
            ? const ExitConfirmScope(child: MerchantSetupScreen())
            : const ExitConfirmScope(child: MerchantShell());
      } else if (appProvider.userRole == 'driver') {
        return appProvider.hasDriverProfile
            ? const ExitConfirmScope(child: DriverShell())
            : const ExitConfirmScope(child: DriverSetupScreen());
      } else if (appProvider.userRole == 'delivery') {
        return const ExitConfirmScope(child: DeliveryShell());
      }

      if (appProvider.isCustomer && !appProvider.hasCompletedCustomerProfile) {
        return const ExitConfirmScope(child: CustomerSetupScreen());
      }

      return const ExitConfirmScope(child: MainShell());
    }

    return MaterialApp(
      title: 'الغيث',
      debugShowCheckedModeBanner: false,
      themeMode: appProvider.themeMode,
      // تحديد لون الخلفية الافتراضي لمنع الشاشة الرصاصية
      color: const Color(0xFFF2F2F7),
      theme: ThemeData(
        platform: TargetPlatform.iOS,
        primarySwatch: Colors.orange,
        textTheme: GoogleFonts.cairoTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        platform: TargetPlatform.iOS,
        primarySwatch: Colors.orange,
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF111111),
        cupertinoOverrideTheme: const CupertinoThemeData(
          brightness: Brightness.dark,
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            type: MaterialType.transparency,
            child: child!,
          ),
        );
      },
      home: getHome(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _currentIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final lang = appProvider.lang;
    final cartCount = appProvider.cart.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, -5))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
                0, CupertinoIcons.house_fill, AppTranslations.t('home', lang)),
            _buildNavItem(1, CupertinoIcons.heart_fill,
                AppTranslations.t('favorites', lang)),

            // زر السلة المميز (Unique Cart Button)
            _buildSpecialCartItemCompact(2, CupertinoIcons.shopping_cart,
                AppTranslations.t('cart', lang), cartCount),

            _buildNavItem(3, CupertinoIcons.doc_text_fill,
                AppTranslations.t('orders', lang)),
            _buildNavItem(4, CupertinoIcons.person_fill,
                AppTranslations.t('account', lang)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    bool isActive = _currentIndex == index;
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
                  duration: const Duration(milliseconds: 300),
                  child: Icon(icon, color: Colors.orange[800], size: 26))
              : Icon(icon, color: CupertinoColors.systemGrey, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color:
                    isActive ? Colors.orange[800] : CupertinoColors.systemGrey,
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
                    colors: isActive
                        ? [Colors.orange[900]!, Colors.orange[700]!]
                        : [Colors.orange[700]!, Colors.orange[500]!],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.4),
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
                                color: Colors.red, shape: BoxShape.circle),
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
                color:
                    isActive ? Colors.orange[800] : CupertinoColors.systemGrey,
                fontFamily: 'Cairo'),
          )
        ],
      ),
    );
  }

  Widget _buildSpecialCartItemCompact(
      int index, IconData icon, String label, int count) {
    final bool isActive = _currentIndex == index;

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
                gradient: LinearGradient(
                  colors: isActive
                      ? [Colors.orange[900]!, Colors.deepOrange[700]!]
                      : [Colors.orange[700]!, Colors.orange[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.28),
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
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.25),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.orange[800] : CupertinoColors.systemGrey,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
