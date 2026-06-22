import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/app_system_ui.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/notifications/push_notification_inbox.dart';
import 'features/taxi/providers/taxi_provider.dart';
import 'providers/app_provider.dart';
import 'screens/phone_login_screen.dart';
import 'screens/customer_setup_screen.dart';
import 'screens/merchant/merchant_setup_screen.dart';
import 'screens/merchant/merchant_pending_approval_screen.dart';
import 'screens/merchant/merchant_shell.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/delivery/delivery_pending_approval_screen.dart';
import 'screens/delivery/delivery_shell.dart';
import 'screens/driver/driver_pending_approval_screen.dart';
import 'screens/shared/operator_setup_screen.dart';
import 'screens/driver/driver_shell.dart';
import 'utils/driver_profile_fields.dart';
import 'services/supabase_service.dart';
import 'widgets/splash_screen.dart';
import 'widgets/main_shell.dart';
import 'widgets/push_notification_lifecycle_scope.dart';
import 'widgets/exit_confirm_scope.dart';
import 'widgets/merchant_order_cross_role_alert.dart';
import 'widgets/app_update_gate.dart';
import 'utils/role_switch_notifications.dart';

Future<void> main() async {
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

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppProvider()),
            ChangeNotifierProvider(create: (_) => TaxiProvider()),
          ],
          child: const AlGhaithApp(),
        ),
      );

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
    PushNotificationService.setRootNavigatorKey(_navigatorKey);
    PushNotificationInbox.onTaxiNotificationTapped = (requestId) {
      debugPrint('TaxiPushAction: فتح طلب $requestId من الإشعار');
    };
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    Widget getHome() {
      if (!appProvider.hasPhoneSession && !appProvider.isGuestMode) {
        return const ExitConfirmScope(child: PhoneLoginScreen());
      }

      if (appProvider.isGuestMode || (!appProvider.hasPhoneSession && !appProvider.hasSelectedRole)) {
        return const ExitConfirmScope(child: MainShell());
      }

      if (appProvider.isAdmin) {
        return const ExitConfirmScope(child: AdminDashboardScreen());
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
          return const ExitConfirmScope(child: OperatorSetupScreen(role: 'driver'));
        }
        if (appProvider.isDriverApproved) {
          return const ExitConfirmScope(child: DriverShell());
        }
        return const ExitConfirmScope(child: DriverPendingApprovalScreen());
      } else if (appProvider.userRole == 'delivery') {
        if (!appProvider.hasCourierProfile) {
          return const ExitConfirmScope(child: OperatorSetupScreen(role: 'delivery'));
        }
        if (!appProvider.isCourierApproved) {
          return const ExitConfirmScope(child: DeliveryPendingApprovalScreen());
        }
        return const ExitConfirmScope(child: DeliveryShell());
      }

      if (appProvider.isCustomer &&
          !appProvider.isGuestMode &&
          !appProvider.skippedCustomerSetup &&
          !appProvider.hasCompletedCustomerProfile) {
        // إذا كان المستخدم لديه متجر/سائق/مندوب، لا تجبره على إكمال ملف الزبون
        if (!appProvider.hasCompletedMerchantProfile &&
            !appProvider.hasDriverProfile &&
            !appProvider.hasCourierProfile) {
          return const ExitConfirmScope(child: CustomerSetupScreen());
        }
      }

      return MerchantOrderCrossRoleAlert(child: MainShell());
    }

    return PushNotificationLifecycleScope(
      child: MaterialApp(
        title: 'الغيث',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        themeMode: appProvider.themeMode,
        color: AppColors.scaffold,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        builder: (context, child) {
          return AppSystemUiScope(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
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
