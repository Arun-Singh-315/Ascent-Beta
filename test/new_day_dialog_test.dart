import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/shared/widgets/new_day_dialog.dart';
import 'package:ascent/core/providers/settings_provider.dart';

void main() {
  testWidgets('NewDayDialog pumps and renders without error', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () {
                    showNewDayDialog(context, ref);
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Tap button to show dialog
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    // Verify dialog elements exist
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text("Today's Battle Plan"), findsOneWidget);
    expect(find.text("Let's Conquer Today! 🚀"), findsOneWidget);

    // Dismiss dialog to ensure clean teardown
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });
}
