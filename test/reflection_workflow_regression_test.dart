import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/medicine/medicine_time_dialog.dart';
import 'package:ascent/features/thought_wall/thought_wall_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test(
    'quick categories persist including an intentionally empty list',
    () async {
      SharedPreferences.setMockInitialValues({
        'feature_guide_v1_Thought Wall': true,
      });
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer create() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      var container = create();
      await container
          .read(thoughtCategoryShortcutsProvider.notifier)
          .toggle('bugs');
      await container
          .read(thoughtCategoryShortcutsProvider.notifier)
          .toggle('suggestions');
      container.dispose();
      container = create();
      expect(container.read(thoughtCategoryShortcutsProvider), isEmpty);
      await container
          .read(thoughtCategoryShortcutsProvider.notifier)
          .toggle('general');
      expect(prefs.getStringList(thoughtCategoryShortcutsKey), ['general']);
      container.dispose();
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'medicine time fits short keyboard viewport and validates 24-hour input dark=$dark',
      (t) async {
        t.view.physicalSize = const Size(320, 568);
        t.view.devicePixelRatio = 1;
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetViewInsets);
        TimeOfDay? saved;
        await t.pumpWidget(
          MaterialApp(
            theme: dark
                ? AscentTheme.dark(preset: DayThemePreset.merlotLinen)
                : AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    saved = await showDialog<TimeOfDay>(
                      context: context,
                      builder: (_) => const MedicineTimeDialog(
                        initialTime: TimeOfDay(hour: 6, minute: 23),
                        dose: 1,
                      ),
                    );
                  },
                  child: const Text('Choose'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Choose'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.enterText(find.byType(TextFormField).first, '29');
        await t.ensureVisible(find.text('Save time'));
        await t.tap(find.text('Save time'));
        await t.pumpAndSettle();
        expect(find.text('Use 0–23'), findsOneWidget);
        await t.enterText(find.byType(TextFormField).first, '23');
        await t.enterText(find.byType(TextFormField).last, '08');
        await t.ensureVisible(find.text('Save time'));
        await t.tap(find.text('Save time'));
        await t.pumpAndSettle();
        expect(saved, const TimeOfDay(hour: 23, minute: 8));
        expect(t.takeException(), isNull);
      },
    );
  }
}
