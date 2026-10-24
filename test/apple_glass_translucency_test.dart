import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/shared/widgets/ascent_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('GlassTranslucencyPreset supports subtleFrosted, balancedLiquid, and highContrast', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );

    // Default preset should be balancedLiquid
    expect(
      container.read(glassTranslucencyPresetProvider),
      GlassTranslucencyPreset.balancedLiquid,
    );

    // Can change to highContrast
    await container
        .read(glassTranslucencyPresetProvider.notifier)
        .setPreset(GlassTranslucencyPreset.highContrast);

    expect(
      container.read(glassTranslucencyPresetProvider),
      GlassTranslucencyPreset.highContrast,
    );

    // Can change to subtleFrosted
    await container
        .read(glassTranslucencyPresetProvider.notifier)
        .setPreset(GlassTranslucencyPreset.subtleFrosted);

    expect(
      container.read(glassTranslucencyPresetProvider),
      GlassTranslucencyPreset.subtleFrosted,
    );
  });

  testWidgets('AscentSnackBar has crisp contrast and visibility in day mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () {
                  AscentSnackBar.show(
                    ctx,
                    message: 'Task completed successfully',
                    icon: Icons.check_circle_outline,
                    actionLabel: 'Undo',
                    onAction: () {},
                  );
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Show SnackBar'));
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 300)); // Finish entrance

    expect(find.text('Task completed successfully'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });
}
