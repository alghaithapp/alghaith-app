import 'dart:async';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';



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



  void closeLoadingDialog() {

    if (dialogClosed) return;

    final ctx = dialogContext;

    if (ctx != null && ctx.mounted) {

      Navigator.of(ctx, rootNavigator: true).pop();

    }

    dialogClosed = true;

    dialogContext = null;

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

    }),

  );



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


