import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/thought_wall/thought_wall_appearance_sheet.dart';
import 'package:ascent/features/thought_wall/thought_wall_preferences.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:drift/native.dart';
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

  testWidgets(
    'the wall-wide controls update every card without changing Home preferences',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'feature_guide_v1_Thought Wall': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      Future<void> settleDb() async {
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        for (final content in ['First thought', 'Second thought']) {
          await db.thoughtDao.insertThought(
            ThoughtTableCompanion.insert(content: content),
          );
        }
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const ThoughtWallScreen(),
            ),
          ),
        );
        await settleDb();
        final compactHeight = tester
            .getSize(find.byType(ThoughtCardBubble).first)
            .height;
        await tester.tap(find.byTooltip('Wall appearance'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Minimal'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close appearance'));
        await tester.pumpAndSettle();
        for (final card in tester.widgetList<ThoughtCardBubble>(
          find.byType(ThoughtCardBubble),
        )) {
          expect(card.appearance.style, ThoughtCardStyle.minimal);
        }
        await tester.tap(find.byTooltip('Wall appearance'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Bubble'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Comfortable'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close appearance'));
        await tester.pumpAndSettle();
        for (final card in tester.widgetList<ThoughtCardBubble>(
          find.byType(ThoughtCardBubble),
        )) {
          expect(card.appearance.style, ThoughtCardStyle.bubble);
          expect(card.appearance.density, ThoughtCardDensity.comfortable);
        }
        expect(
          tester.getSize(find.byType(ThoughtCardBubble).first).height,
          greaterThan(compactHeight),
        );
        expect(
          prefs.getKeys().where((k) => k.startsWith('ascent_home')),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }
    },
  );

  for (final dark in [false, true]) {
    testWidgets('wall appearance styles fit 320px at large text, dark=$dark', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content:
              'A longer reflection to check readable text, a selected state, and comfortable spacing.',
        ),
      );
      final thought = (await db.thoughtDao.getThoughtById(id))!;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      BoxDecoration decoration() => tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .single;
      try {
        for (final style in ThoughtCardStyle.values) {
          double? compactHeight;
          for (final density in ThoughtCardDensity.values) {
            for (final selected in [false, true]) {
              await tester.pumpWidget(
                UncontrolledProviderScope(
                  container: container,
                  child: MaterialApp(
                    theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                    home: MediaQuery(
                      data: const MediaQueryData(
                        textScaler: TextScaler.linear(2),
                      ),
                      child: Scaffold(
                        body: SingleChildScrollView(
                          child: ThoughtCardBubble(
                            key: ValueKey('$style-$density-$selected'),
                            compact: true,
                            thought: thought,
                            index: 0,
                            categoryLabel: 'Learning',
                            appearance: ThoughtWallAppearance(
                              style: style,
                              density: density,
                            ),
                            isSelectionMode: selected,
                            isSelected: selected,
                            onToggleSelect: () {},
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final height = tester
                  .getSize(find.byType(ThoughtCardBubble))
                  .height;
              if (!selected && density == ThoughtCardDensity.compact) {
                compactHeight = height;
              }
              if (!selected && density == ThoughtCardDensity.comfortable) {
                expect(height, greaterThan(compactHeight!));
              }
              final box = decoration();
              if (style == ThoughtCardStyle.minimal) {
                expect(box.boxShadow, isEmpty);
              }
              if (!selected) {
                final radius = box.borderRadius;
                await tester.tap(find.byTooltip('Expand thought'));
                await tester.pumpAndSettle();
                expect(decoration().borderRadius, radius);
                expect(find.byTooltip('Edit thought'), findsOneWidget);
                await tester.tap(find.byTooltip('Collapse thought'));
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
              }
            }
          }
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }
    });
  }
}
