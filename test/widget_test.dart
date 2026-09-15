// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/app.dart';
import 'package:ascent/core/providers/settings_provider.dart';

void main() {
  testWidgets('AscentApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'ascent_onboarding_complete': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const AscentApp(),
      ),
    );

    // Initial frame renders AscentApp
    expect(find.byType(AscentApp), findsOneWidget);

    // Advance past splash delay so session check navigates
    await tester.pump(const Duration(milliseconds: 1300));
    // Pump navigation and subsequent frames
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AscentApp), findsOneWidget);
  });
}
