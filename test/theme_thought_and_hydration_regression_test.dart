import 'dart:ui' as ui;

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/shared/widgets/animated_water_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';


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
            await tester.pump(const Duration(seconds: 2));
          }
        },
      );
    }
  }
}
