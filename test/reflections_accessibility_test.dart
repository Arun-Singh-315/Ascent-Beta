import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/shared/widgets/ascent_snack_bar.dart';
import 'package:ascent/shared/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  double contrast(Color a, Color b) {
    final values = [a.computeLuminance(), b.computeLuminance()]..sort();
    return (values.last + .05) / (values.first + .05);
  }

  for (final preset in DayThemePreset.values) {
    for (final dark in [false, true]) {
      testWidgets('Undo feedback contrasts in $preset dark=$dark', (t) async {
        final theme = dark
            ? AscentTheme.dark(preset: preset)
            : AscentTheme.light(preset: preset);
        final snack = theme.snackBarTheme;
        expect(
          contrast(snack.actionTextColor!, snack.backgroundColor!),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(snack.contentTextStyle!.color!, snack.backgroundColor!),
          greaterThanOrEqualTo(4.5),
        );
        var undone = false;
        await t.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AscentSnackBar.undo(
                    context,
                    message: 'Thought removed',
                    onUndo: () => undone = true,
                  ),
                  child: const Text('Remove'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Remove'));
        await t.pumpAndSettle();
        final action = t.widget<SnackBarAction>(find.byType(SnackBarAction));
        final surface = t.widget<GlassSurface>(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.byType(GlassSurface),
          ),
        );
        final context = t.element(find.byType(SnackBarAction));
        expect(
          contrast(action.textColor!, surface.fillColor!),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(context.glass.ink, surface.fillColor!),
          greaterThanOrEqualTo(4.5),
        );
        await t.tap(find.text('UNDO'));
        await t.pumpAndSettle();
        expect(undone, isTrue);
        expect(t.takeException(), isNull);
      });
    }
  }
}
