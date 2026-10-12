import 'support/returning_user_guides.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:ascent/core/providers/settings_provider.dart';

void main() {
  testWidgets('SettingsScreen pumps without error', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(returningUserGuidePrefs);
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance & Theme'), findsOneWidget);
  });
}
