import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/color_tokens.dart';
import 'package:ascent/app/theme/frozen_palette.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
import 'package:ascent/shared/widgets/ascent_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance(), second = b.computeLuminance();
  return ((first > second ? first : second) + .05) /
      ((first < second ? first : second) + .05);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  test(
    'Frozen text and primary actions retain readable contrast on actual surfaces',
    () {
      expect(
        contrast(FrozenPalette.ink, FrozenPalette.canvas),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(FrozenPalette.mutedInk, FrozenPalette.canvas),
        greaterThanOrEqualTo(4.5),
      );
      for (final fill in [
        FrozenPalette.aqua,
        FrozenPalette.mint,
        FrozenPalette.lavender,
      ]) {
        expect(
          contrast(FrozenPalette.mutedInk, fill),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        contrast(Colors.white, FrozenPalette.action),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(FrozenPalette.ink, FrozenPalette.surface),
        greaterThanOrEqualTo(4.5),
      );
    },
  );
  for (final route in ['workspace', 'Home', 'Riya']) {
    testWidgets(
      '$route honors the selected preset in color helpers and shared cards/buttons',
      (tester) async {
        final base = AscentTheme.light(preset: DayThemePreset.nordicSky);
        final theme = route == 'Home'
            ? HomeTheme.from(base)
            : route == 'Riya'
            ? AscentTheme.assistant(base)
            : base;
        late BuildContext surfaceContext;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                surfaceContext = context;
                return Scaffold(
                  body: Column(
                    children: [
                      AscentCard.solid(child: const Text('Solid card')),
                      AscentCard.elevated(child: const Text('Elevated card')),
                      AscentButton.primary(label: 'Save', onPressed: () {}),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        expect(surfaceContext.glass.frozen, isTrue);
        expect(surfaceContext.bgBase, FrozenPalette.canvas);
        expect(surfaceContext.bgSurface, FrozenPalette.surface);
        expect(surfaceContext.bgSurfaceElevated, FrozenPalette.elevated);
        expect(surfaceContext.textSecondary, FrozenPalette.secondaryInk);
        expect(surfaceContext.accentSecondary, FrozenPalette.secondary);
        expect(surfaceContext.accentInfo, FrozenPalette.warning);
        expect(surfaceContext.stateSuccess, FrozenPalette.success);
        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(
          button.style!.backgroundColor!.resolve({}),
          FrozenPalette.action.withValues(alpha: .94),
        );
        expect(
          theme.textButtonTheme.style!.foregroundColor!.resolve({}),
          FrozenPalette.action,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'preset marker survives extension cloning without color-identity guessing',
    () {
      final changed =
          AscentGlass.nordicSky.copyWith(clay: Colors.black) as AscentGlass;
      expect(changed.frozen, isTrue);
      final parent = AscentTheme.light(
        preset: DayThemePreset.nordicSky,
      ).copyWith(extensions: [changed]);
      expect(HomeTheme.from(parent).extension<AscentGlass>()!.frozen, isTrue);
      expect(
        AscentTheme.assistant(parent).extension<AscentGlass>()!.frozen,
        isTrue,
      );
      expect(AscentTheme.dark().extension<AscentGlass>()!.frozen, isFalse);
      expect(AscentTheme.light().extension<AscentGlass>()!.frozen, isFalse);
    },
  );
}
