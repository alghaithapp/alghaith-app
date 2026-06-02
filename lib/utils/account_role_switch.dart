import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

Future<void> switchAccountRoleWithLoading(
  BuildContext context,
  AppProvider provider,
  String role, {
  required String loadingMessage,
  required String errorMessage,
}) async {
  BuildContext? dialogContext;
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) {
      dialogContext = ctx;
      return AlertDialog(
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
      );
    },
  ).then((_) {
    dialogContext = null;
  });

  var switched = false;
  try {
    switched = await provider.setUserRole(role);
  } finally {
    final ctx = dialogContext;
    if (ctx != null) {
      Navigator.of(ctx, rootNavigator: true).pop();
    }
  }

  if (!context.mounted || switched) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMessage)),
  );
}
