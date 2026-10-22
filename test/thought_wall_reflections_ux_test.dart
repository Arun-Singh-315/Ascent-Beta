import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['ASCENT_QA_CAPTURE'] == '1') {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  double contrast(Color a, Color b) {
    final values = [a.computeLuminance(), b.computeLuminance()]..sort();
    return (values.last + .05) / (values.first + .05);
  }

  test('Merlot labels and action text contrast with their actual surfaces', () {
    final theme = AscentTheme.dark(preset: DayThemePreset.merlotLinen);
    expect(
      contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(
        theme.chipTheme.secondaryLabelStyle!.color!,
        theme.chipTheme.selectedColor!,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(theme.chipTheme.labelStyle!.color!, MerlotPalette.darkElevated),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(MerlotPalette.darkMutedInk, MerlotPalette.darkElevated),
      greaterThanOrEqualTo(4.5),
    );
  });
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'visible filters and completion in Merlot dark=$dark scale=$scale',
        (t) async {
          SharedPreferences.setMockInitialValues({
            'feature_guide_v1_Thought Wall': true,
          });
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);
          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
          );
          final id = await db.thoughtDao.insertThought(
            ThoughtTableCompanion.insert(content: 'Review the new design'),
          );
          t.view.physicalSize = Size(scale == 2 ? 320 : 390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          try {
            await t.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: dark
                      ? AscentTheme.dark(preset: DayThemePreset.merlotLinen)
                      : AscentTheme.light(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: RepaintBoundary(
                    key: const ValueKey('qa-wall'),
                    child: const ThoughtWallScreen(),
                  ),
                ),
              ),
            );
            for (var i = 0; i < 8; i++) {
              await t.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 25)),
              );
              await t.pump(const Duration(milliseconds: 100));
            }
            expect(
              t
                  .getSize(find.byKey(const ValueKey('thought_filter_bar')))
                  .height,
              lessThanOrEqualTo(90),
            );
            expect(find.text('Bugs'), findsOneWidget);
            expect(find.text('Suggestions'), findsOneWidget);
            expect(find.byTooltip('How this works'), findsNothing);
            expect(find.text('Mark done'), findsOneWidget);
            expect(t.takeException(), isNull);
            if (Platform.environment['ASCENT_QA_CAPTURE'] == '1' &&
                scale == 1) {
              final boundary = t.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('qa-wall')),
              );
              await t.runAsync(() async {
                final picture = await boundary.toImage();
                final bytes = await picture.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '/tmp/ascent-merlot-${dark ? 'night' : 'day'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                picture.dispose();
              });
            }
            await t.tap(find.text('Mark done'));
            for (var i = 0; i < 8; i++) {
              await t.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await t.pump(const Duration(milliseconds: 100));
            }
            expect(
              (await t.runAsync(
                () => db.thoughtDao.getThoughtById(id),
              ))!.isCompleted,
              isTrue,
            );
            final text = find.textContaining('Review the new design');
            await t.tap(text);
            await t.pump(const Duration(milliseconds: 50));
            await t.tap(text);
            for (var i = 0; i < 8; i++) {
              await t.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await t.pump(const Duration(milliseconds: 100));
            }
            expect(
              (await t.runAsync(
                () => db.thoughtDao.getThoughtById(id),
              ))!.isCompleted,
              isFalse,
            );
            await t.ensureVisible(find.text('Bugs'));
            await t.tap(find.text('Bugs'));
            await t.pumpAndSettle();
            expect(find.textContaining('Review the new design'), findsNothing);
            expect(t.takeException(), isNull);
            if (scale == 1) {
              await t.enterText(find.byType(TextField), 'A new bug to review');
              await t.pump();
              await t.tap(find.byKey(const ValueKey('message_composer_send')));
              for (var i = 0; i < 8; i++) {
                await t.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 20)),
                );
                await t.pump(const Duration(milliseconds: 100));
              }
              expect(
                find.textContaining('A new bug to review'),
                findsOneWidget,
              );
              expect(find.text('Move to category'), findsOneWidget);
              expect(find.text('Todo & Reminder'), findsOneWidget);
              expect(t.takeException(), isNull);
            }
          } finally {
            await t.pumpWidget(const SizedBox());
            container.dispose();
            await t.pump(const Duration(seconds: 2));
            await t.pump();
          }
        },
      );
    }
  }
}
