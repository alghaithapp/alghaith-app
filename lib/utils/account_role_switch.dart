import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../providers/app_provider.dart';
import 'role_switch_notifications.dart';

Future<void> switchAccountRoleWithLoading(
  BuildContext context,
  AppProvider provider,
  String role, {
  required String loadingMessage,
  required String errorMessage,
}) async {
  if (!context.mounted) return;

  BuildContext? dialogContext;
  var dialogClosed = false;
  var closeRequested = false;
  Timer? safetyTimer;

  void closeLoadingDialog() {
    if (dialogClosed) return;

    final ctx = dialogContext;
    if (ctx == null) {
      closeRequested = true;
      return;
    }
    if (ctx.mounted) {
      Navigator.of(ctx, rootNavigator: true).pop();
    }
    dialogClosed = true;
    dialogContext = null;
    safetyTimer?.cancel();
  }

  void onRoleUpdated() {
    if (provider.userRole == role) {
      closeLoadingDialog();
    }
  }

  provider.addListener(onRoleUpdated);

  unawaited(
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        if (closeRequested && !dialogClosed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            closeLoadingDialog();
          });
        }
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loadingMessage,
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      dialogClosed = true;
      dialogContext = null;
      safetyTimer?.cancel();
    }),
  );

  safetyTimer = Timer(const Duration(seconds: 6), closeLoadingDialog);

  // ننتظر فريم كامل لنتأكد أن الـ Dialog بُني قبل متابعة التبديل.
  // لو ما انتظرنا، `dialogContext` يكون null ومن ثم listener ما يقدر يغلقه،
  // وتظهر صفحة الإعداد الجديدة وفوقها الـ Dialog معلّق.
  await Future<void>.delayed(Duration.zero);

  var switched = false;
  try {
    switched = await provider.setUserRole(role);
  } finally {
    provider.removeListener(onRoleUpdated);
    closeLoadingDialog();
  }

  if (!context.mounted) return;

  if (switched) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        RoleSwitchNotificationPresenter.showIfNeeded(context);
      }
    });
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMessage)),
  );
}

/// يعرض نافذة منبثقة مميزة (Bottom Sheet) لاختيار الدور الجديد والانتقال إليه
void showRoleSwitcher(BuildContext context, AppProvider provider) {
  final currentRole = provider.userRole;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 25,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'تبديل الحساب',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اختر نوع الحساب الذي تريد الانتقال إليه',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Cairo',
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            if (currentRole != 'customer')
              _buildRoleItem(
                ctx,
                provider,
                title: 'حساب الزبون',
                subtitle: 'تصفح المتاجر واطلب المنتجات والتوصيل',
                roleKey: 'customer',
                icon: CupertinoIcons.person_fill,
                color: const Color(0xFFF5A01D),
                loadingMsg: 'يرجى الانتظار... جارٍ التحويل إلى حساب الزبون',
                errorMsg: 'تعذر الانتقال إلى حساب الزبون حالياً.',
                isDark: isDark,
              ),
            if (currentRole != 'customer' && currentRole != 'merchant')
              const SizedBox(height: 12),
            if (currentRole != 'merchant')
              _buildRoleItem(
                ctx,
                provider,
                title: 'حساب التاجر',
                subtitle: 'إدارة متجرك، منتجاتك، وتتبع مبيعاتك',
                roleKey: 'merchant',
                icon: Icons.storefront_rounded,
                color: const Color(0xFFFF3D00),
                loadingMsg: 'يرجى الانتظار... جارٍ التحويل إلى حساب التاجر',
                errorMsg: 'تعذر الانتقال إلى حساب التاجر حالياً.',
                isDark: isDark,
              ),
            if (currentRole != 'delivery' && (currentRole != 'customer' || currentRole != 'merchant'))
              const SizedBox(height: 12),
            if (currentRole != 'delivery')
              _buildRoleItem(
                ctx,
                provider,
                title: 'حساب مندوب التوصيل',
                subtitle: provider.hasCourierProfile
                    ? 'استلام طلبات التوصيل وتتبع الأرباح'
                    : 'سجّل بيانات المندوب أولاً لتفعيل الحساب',
                roleKey: 'delivery',
                icon: Icons.delivery_dining_rounded,
                color: const Color(0xFF00A3A3),
                loadingMsg: 'يرجى الانتظار... جارٍ التحويل إلى حساب المندوب',
                errorMsg: 'تعذر الانتقال إلى حساب المندوب حالياً.',
                isDark: isDark,
              ),
            if (currentRole != 'delivery' && (currentRole != 'customer' || currentRole != 'merchant'))
              const SizedBox(height: 12),
            if (currentRole != 'driver')
              _buildRoleItem(
                ctx,
                provider,
                title: 'سائق تكسي',
                subtitle: provider.hasDriverProfile
                    ? 'استقبال طلبات التكسي وإدارة الرحلات'
                    : 'سجّل بيانات السائق أولاً لتفعيل الحساب',
                roleKey: 'driver',
                icon: CupertinoIcons.car_fill,
                color: const Color(0xFF1565C0),
                loadingMsg: 'يرجى الانتظار... جارٍ التحويل إلى حساب التكسي',
                errorMsg: 'تعذر الانتقال إلى حساب التكسي حالياً.',
                isDark: isDark,
              ),
          ],
        ),
      );
    },
  );
}

Widget _buildRoleItem(
  BuildContext context,
  AppProvider provider, {
  required String title,
  required String subtitle,
  required String roleKey,
  required IconData icon,
  required Color color,
  required String loadingMsg,
  required String errorMsg,
  required bool isDark,
}) {
  return GestureDetector(
    onTap: () async {
      Navigator.of(context).pop();
      // ننتظر لحظة حتى تكتمل أنيميشن إغلاق القائمة السفلية (خاصة iOS)
      // قبل فتح نافذة التحميل الجديدة لتجنب تعارض الأنيميشن والبطء
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!context.mounted) return;
      switchAccountRoleWithLoading(
        context,
        provider,
        roleKey,
        loadingMessage: loadingMsg,
        errorMessage: errorMsg,
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE9ECEF),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Cairo',
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_left_rounded,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
        ],
      ),
    ),
  );
}
