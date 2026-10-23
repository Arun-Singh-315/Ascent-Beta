import 'dart:io';
import 'dart:ui' as ui;

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/thought_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:ascent/shared/widgets/animated_water_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final preset in DayThemePreset.values) {
    for (final dark in [false, true]) {
      final name = '${preset.name}_${dark ? 'night' : 'day'}';
      testWidgets('Transparent wall and matching home bubbles: $name', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(430, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Take a breath. One small step is enough.',
          ),
        );
        final thought = (await db.thoughtDao.getThoughtById(id))!;
        final theme = HomeTheme.from(
          dark
              ? AscentTheme.dark(preset: preset)
              : AscentTheme.light(preset: preset),
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              recentThoughtsStreamProvider.overrideWith(
                (ref) => Stream.value([thought]),
              ),
            ],
            child: MaterialApp(
              theme: theme,
              home: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const ThoughtWallHomePreview(),
                          const SizedBox(height: 20),
                          ThoughtCardBubble(
                            thought: thought,
                            index: 0,
                            compact: true,
                          ),
                          ThoughtCardBubble(thought: thought, index: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final wall = tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .where((w) => w.key.toString().contains('thought_surface_'));
        expect(wall.length, 2);
        for (final widget in wall) {
          final box = widget.decoration! as BoxDecoration;
          expect(box.color, Colors.transparent);
          expect(box.gradient, isNull);
          expect((box.border! as Border).top.color.a, greaterThan(.25));
          expect(box.boxShadow, isEmpty);
        }
        final bubble = tester.widget<Container>(
          find.byKey(ValueKey('home_thought_$id')),
        );
        final box = bubble.decoration! as BoxDecoration;
        expect(box.gradient, isNull);
        expect(box.color!.a, lessThan(.15));
        expect(
          box.borderRadius,
          const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
        );
        final bubbleContext = tester.element(
          find.byKey(ValueKey('home_thought_$id')),
        );
        final glass = bubbleContext.glass;
        final background = Color.alphaBlend(
          box.color!, Color.alphaBlend(glass.fill, glass.bg),
        );
        if (!dark && preset != DayThemePreset.merlotLinen) {
          final expectedSurface = preset == DayThemePreset.nordicSky
              ? ThoughtTheme.frozenSurface
              : ThoughtTheme.claySurface;
          expect(glass.fill, expectedSurface);
          expect(bubbleContext.surfaces.cardFill, expectedSurface);
          expect(glass.fill, isNot(Colors.white));
        }
        expect(contrast(glass.ink, background), greaterThan(4.5));
        expect(
          contrast(glass.inkMuted, background),
          greaterThan(!dark && preset != DayThemePreset.merlotLinen ? 4.5 : 3),
        );
        if (Platform.environment['ASCENT_THEME_SCREENSHOTS'] == '1') {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final img = await render.toImage();
            final png = await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '/tmp/ascent_$name.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            img.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('Thought Wall uses its themed canvas: $name', (tester) async {
        SharedPreferences.setMockInitialValues({
          'feature_guide_v1_Thought Wall': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final theme = dark
            ? AscentTheme.dark(preset: preset)
            : AscentTheme.light(preset: preset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              thoughtCategoriesStreamProvider.overrideWith(
                (ref) => Stream.value(<String, String>{}),
              ),
              allThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
              archivedThoughtsStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(theme: theme, home: const ThoughtWallScreen()),
          ),
        );
        await tester.pumpAndSettle();
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        final expected = !dark && preset != DayThemePreset.merlotLinen
            ? (preset == DayThemePreset.nordicSky
                  ? ThoughtTheme.frozenCanvas
                  : ThoughtTheme.clayCanvas)
            : theme.extension<AscentGlass>()!.bg;
        expect(scaffold.backgroundColor, expected);
        final context = tester.element(find.byType(Scaffold).first);
        expect(context.glass.bg, expected);
        if (!dark && preset != DayThemePreset.merlotLinen) {
          expect(context.surfaces.cardFill, isNot(Colors.white));
          expect(contrast(context.glass.ink, expected), greaterThan(4.5));
          expect(contrast(context.glass.inkMuted, expected), greaterThan(4.5));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });

      testWidgets(
        'Water paints empty, half and full with bounded tank: $name',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final theme = dark
              ? AscentTheme.dark(preset: preset)
              : AscentTheme.light(preset: preset);
          for (final amount in [0, 1250, 2500, 3000]) {
            await tester.pumpWidget(
              ProviderScope(
                key: ValueKey(amount),
                overrides: [
                  todayWaterMlStreamProvider.overrideWith(
                    (ref) => Stream.value(amount),
                  ),
                  dailyWaterGoalStreamProvider.overrideWith(
                    (ref) => Stream.value(2500),
                  ),
                ],
                child: MaterialApp(
                  theme: theme,
                  home: const Scaffold(body: AnimatedWaterCard()),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
            expect(
              find.text('${((amount / 2500) * 100).toInt()}%'),
              findsOneWidget,
            );
            final finder = find.byKey(const ValueKey('hydration_water_level'));
            final size = tester.getSize(finder);
            expect(size.height, 72);
            expect(size.width, greaterThan(100));
            final painter = tester.widget<CustomPaint>(finder).painter!;
            await tester.runAsync(() async {
              final recorder = ui.PictureRecorder();
              painter.paint(Canvas(recorder), const Size(100, 72));
              final picture = recorder.endRecording();
              final image = await picture.toImage(100, 72);
              final pixels = (await image.toByteData())!;
              // Below half-height must contain water at 50% and above.
              expect(
                pixels.getUint8((60 * 100 + 50) * 4 + 3),
                amount == 0 ? 0 : greaterThan(0),
              );
              // Above half-height only fills once the goal is reached.
              expect(
                pixels.getUint8((12 * 100 + 50) * 4 + 3),
                amount < 2500 ? 0 : greaterThan(0),
              );
              picture.dispose();
              image.dispose();
            });
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        },
      );
    }
  }
}
