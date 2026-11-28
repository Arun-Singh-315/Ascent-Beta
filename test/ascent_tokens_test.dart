import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/ascent_tokens.dart';
import 'package:ascent/app/theme/calm_blue_palette.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

void main() {
  group('AscentTokens', () {
    test('both themes carry the tokens', () {
      expect(AscentTheme.light().extension<AscentTokens>(), AscentTokens.light);
      expect(AscentTheme.dark().extension<AscentTokens>(), AscentTokens.dark);
    });

    test('dark mode is charcoal, not navy', () {
      expect(AscentTokens.dark.canvas, const Color(0xFF111317));
      expect(AscentTokens.dark.surface, const Color(0xFF191C22));
      final c = AscentTokens.dark.canvas;
      // Neutral: the blue channel may lead red by only a hair.
      expect((c.b - c.r).abs(), lessThan(0.03));
    });

    for (final (name, t) in [
      ('light', AscentTokens.light),
      ('dark', AscentTokens.dark),
    ]) {
      test('$name text and accents are readable', () {
        for (final bg in [t.canvas, t.surface]) {
          expect(_contrast(t.label, bg), greaterThanOrEqualTo(7));
          for (final ink in [
            t.labelSecondary,
            t.labelTertiary,
            t.action,
            t.danger,
            t.think,
            t.commit,
            t.care,
            t.water,
            t.money,
          ]) {
            expect(_contrast(ink, bg), greaterThanOrEqualTo(4.5));
          }
        }
        expect(_contrast(t.onAction, t.actionFill), greaterThanOrEqualTo(4.5));
      });

      test('$name zones keep text readable at full strength', () {
        for (final z in HomeZone.values) {
          final bg = t.zone(z, strength: 1);
          expect(_contrast(t.label, bg), greaterThanOrEqualTo(7), reason: '$z');
          expect(
            _contrast(t.labelSecondary, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$z',
          );
        }
      });
    }

    test('a theme switch fades every colour; nothing jumps', () {
      final from = AscentTokens.light, to = AscentTokens.dark;
      var last = from.canvas.computeLuminance();
      for (var i = 1; i <= 20; i++) {
        final mid = from.lerp(to, i / 20);
        final lum = mid.canvas.computeLuminance();
        // Light → dark only ever gets darker, a little at a time.
        expect(lum, lessThanOrEqualTo(last + 1e-9));
        expect(last - lum, lessThan(0.15));
        last = lum;
      }
      expect(from.lerp(to, 1).zones, to.zones);
    });
  });

  testWidgets('switching day and night mid-way never throws or snaps', (
    tester,
  ) async {
    Widget app(ThemeMode mode) => MaterialApp(
      theme: AscentTheme.light(),
      darkTheme: AscentTheme.dark(),
      themeMode: mode,
      home: Builder(
        builder: (context) => ColoredBox(
          key: const ValueKey('canvas'),
          color: context.tokens.canvas,
          child: Text('Hi', style: AscentTextStyles.row),
        ),
      ),
    );
    Color canvas() =>
        tester.widget<ColoredBox>(find.byKey(const ValueKey('canvas'))).color;

    await tester.pumpWidget(app(ThemeMode.light));
    expect(canvas(), CalmBluePalette.canvas);
    await tester.pumpWidget(app(ThemeMode.dark));
    final seen = <double>[];
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      seen.add(canvas().computeLuminance());
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(canvas(), CalmBluePalette.darkCanvas);
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], lessThanOrEqualTo(seen[i - 1] + 1e-9));
    }
    // It really fades: some frames sit between day and night.
    expect(
      seen.where(
        (l) =>
            l < CalmBluePalette.canvas.computeLuminance() - .01 &&
            l > CalmBluePalette.darkCanvas.computeLuminance() + .01,
      ),
      isNotEmpty,
    );
  });

  test('Day Page type roles use Inter, thoughts use Newsreader', () {
    expect(AscentTextStyles.row.fontFamily, startsWith('Inter'));
    expect(AscentTextStyles.row.fontSize, 15);
    expect(AscentTextStyles.meta.fontSize, 12.5);
    expect(AscentTextStyles.thought.fontFamily, startsWith('Newsreader'));
    expect(AscentTextStyles.body.fontFamily, startsWith('Inter'));
  });
}
