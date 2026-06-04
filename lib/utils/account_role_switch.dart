import 'dart:async';

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
    // امنع أي إغلاق مكرر.
    if (dialogClosed) return;

    final ctx = dialogContext;
    if (ctx == null) {
      // النافذة لم تُبنَ بعد (سباق زمني): سجّل طلب الإغلاق ليُنفَّذ فور ظهورها.
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
        // إذا طُلب الإغلاق قبل اكتمال بناء النافذة، أغلقها بعد أول إطار.
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

  // شبكة أمان: إن بقيت النافذة مفتوحة لأي سبب، تُغلق تلقائياً.
  safetyTimer = Timer(const Duration(seconds: 6), closeLoadingDialog);

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
