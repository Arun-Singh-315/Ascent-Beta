import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/shared/widgets/ascent_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every glyph has a drawing that takes the given colour', () {
    for (final g in AscentGlyph.values) {
      final svg = AscentIcon.svgFor(g, const Color(0xFF13325C));
      expect(svg, contains('#13325c'), reason: '$g');
      expect(svg, isNot(contains('currentColor')), reason: '$g');
    }
  });

  testWidgets('icons render in both themes, labelled when asked', (
    tester,
  ) async {
    for (final theme in [AscentTheme.light(), AscentTheme.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Wrap(
              children: [
                for (final g in AscentGlyph.values)
                  AscentIcon(g, size: 24, semanticLabel: g.name),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(SvgPicture),
        findsNWidgets(AscentGlyph.values.length),
      );
      expect(find.bySemanticsLabel('water'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
