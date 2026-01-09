// Widget test for Fruits of the Spirit app
// Tests that the app loads successfully

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fruitsofspirit/main.dart';
import 'helpers/test_setup.dart';

void main() {
  // Initialize test environment
  setUpAll(() async {
    await setupTestEnvironment();
    await EasyLocalization.ensureInitialized();
  });
  
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app with EasyLocalization wrapper
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('es')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const MyApp(),
      ),
    );

    // Wait for app to settle
    await tester.pumpAndSettle();

    // Verify that app scaffold is present
    expect(find.byType(Scaffold), findsWidgets);
  });
}
