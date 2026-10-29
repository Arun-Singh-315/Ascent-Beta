import 'dart:math' as math;

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_outline_surface.dart';
import 'package:ascent/shared/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  double contrast(Color a, Color b) {
    final first = a.computeLuminance();
    final second = b.computeLuminance();
    return (math.max(first, second) + .05) / (math.min(first, second) + .05);
  }

  for (final dark in [false, true]) {
    final theme = dark
        ? AscentTheme.dark(preset: DayThemePreset.merlotLinen)
        : AscentTheme.light(preset: DayThemePreset.merlotLinen);
    test('Signature text hierarchy remains readable, dark=$dark', () {
      final glass = theme.extension<AscentGlass>()!;
      for (final background in [glass.bg, theme.colorScheme.surface]) {
        for (final foreground in [
          glass.ink,
          glass.inkSecondary,
          glass.inkMuted,
        ]) {
          expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
        }
      }
    });

    testWidgets('Content stays opaque without background blur, dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: Colors.pink)),
                HomeOutlineSurface(child: Text('Readable content')),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      final container = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(GlassSurface),
              matching: find.byType(Container),
            ),
          )
          .firstWhere((widget) => widget.decoration is BoxDecoration);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color?.a, 1);
      expect(decoration.gradient, isNull);
      expect(decoration.boxShadow, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Floating glass remains available when explicitly requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AscentTheme.light(),
        home: const Scaffold(
          body: GlassSurface(
            enableBlur: true,
            child: Text('Floating navigation'),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('Opaque panes preserve row and surface tap feedback', (
    tester,
  ) async {
    var paneTaps = 0;
    var rowTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AscentTheme.light(),
        home: Scaffold(
          body: GlassSurface(
            onTap: () => paneTaps++,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Open panel'),
                ListTile(title: const Text('Open row'), onTap: () => rowTaps++),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open row'));
    await tester.pumpAndSettle();
    expect(rowTaps, 1);
    expect(paneTaps, 0);
    await tester.tap(find.text('Open panel'));
    await tester.pumpAndSettle();
    expect(paneTaps, 1);
    expect(tester.takeException(), isNull);
  });
}
