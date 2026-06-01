import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alghaith_app/main.dart';
import 'package:alghaith_app/providers/app_provider.dart';
import 'package:alghaith_app/screens/phone_login_screen.dart';

void main() {
  testWidgets('shows the phone login screen on launch',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
        ],
        child: const AlGhaithApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.byType(PhoneLoginScreen), findsOneWidget);
  });
}
