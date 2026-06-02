import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';

/// يفتح تبويب الرئيسية في MainShell ويُغلق أي مسارات مفتوحة فوقها.
void goToCustomerHome(BuildContext context) {
  context.read<AppProvider>().goToCustomerHomeTab();
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil((route) => route.isFirst);
  }
}
