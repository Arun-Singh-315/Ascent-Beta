import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/thought_wall/thought_wall_appearance_sheet.dart';
import 'package:ascent/features/thought_wall/thought_wall_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailedAppearanceSave extends ThoughtWallAppearanceNotifier {
  @override
  Future<void> save(ThoughtWallAppearance appearance) async =>
      throw StateError('Storage unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test(
    'default, corrupt and future preferences recover to Soft and Compact',
    () async {
      for (final raw in [
        null,
        '{broken',
        '{"version":9}',
        '{"version":1,"style":"unknown","density":"unknown"}',
      ]) {
        final initial = <String, Object>{};
        if (raw != null) initial[thoughtWallAppearanceKey] = raw;
        SharedPreferences.setMockInitialValues(initial);
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        final appearance = container.read(thoughtWallAppearanceProvider);
        expect(appearance.style, ThoughtCardStyle.soft);
        expect(appearance.density, ThoughtCardDensity.compact);
        container.dispose();
      }
    },
  );

  test('wall-wide style and spacing persist together across restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await container
        .read(thoughtWallAppearanceProvider.notifier)
        .save(
          const ThoughtWallAppearance(
            style: ThoughtCardStyle.bubble,
            tone: ThoughtCardTone.slate,
            density: ThoughtCardDensity.comfortable,
          ),
        );
    container.dispose();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    expect(
      container.read(thoughtWallAppearanceProvider).style,
      ThoughtCardStyle.bubble,
    );
    expect(
      container.read(thoughtWallAppearanceProvider).density,
      ThoughtCardDensity.comfortable,
    );
    expect(
      container.read(thoughtWallAppearanceProvider).tone,
      ThoughtCardTone.slate,
    );
    container.dispose();
  });

  testWidgets(
    'appearance controls save changes and preserve the current choice when storage fails',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      final failed = ProviderContainer(
        overrides: [
          thoughtWallAppearanceProvider.overrideWith(FailedAppearanceSave.new),
        ],
      );
      try {
        Widget mount(ProviderContainer c) => UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: Scaffold(body: ThoughtWallAppearanceSheet()),
          ),
        );
        await tester.pumpWidget(mount(container));
        await tester.tap(find.widgetWithText(ChoiceChip, 'Minimal'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Comfortable'));
        await tester.pumpAndSettle();
        expect(
          container.read(thoughtWallAppearanceProvider).style,
          ThoughtCardStyle.minimal,
        );
        expect(
          container.read(thoughtWallAppearanceProvider).density,
          ThoughtCardDensity.comfortable,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(mount(failed));
        await tester.tap(find.widgetWithText(ChoiceChip, 'Bubble'));
        await tester.pumpAndSettle();
        expect(find.text('Could not save. Please try again.'), findsOneWidget);
        expect(
          failed.read(thoughtWallAppearanceProvider).style,
          ThoughtCardStyle.soft,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        failed.dispose();
      }
    },
  );
}
