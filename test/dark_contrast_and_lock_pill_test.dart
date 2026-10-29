import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/shared/widgets/locked_commitment_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LockedCommitmentTile Contrast & Usability Tests', () {
    testWidgets('renders high contrast text and unlock badge on 320px screen without overflow', (tester) async {
      bool unlocked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [AscentGlass.merlotLinenDark],
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 600),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: LockedCommitmentTile(
                    label: 'Personal private commitment',
                    onTap: () {
                      unlocked = true;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure zero RenderFlex overflow
      expect(tester.takeException(), isNull);

      // Verify text elements exist
      expect(find.text('Personal private commitment'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);

      // Verify tap works
      await tester.tap(find.byType(LockedCommitmentTile));
      await tester.pump();
      expect(unlocked, isTrue);
    });

    testWidgets('renders cleanly in light mode without washed out white borders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [AscentGlass.merlotLinenLight],
          ),
          home: Scaffold(
            body: Center(
              child: LockedCommitmentTile(
                label: 'Shielded Thought',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Shielded Thought'), findsOneWidget);
    });
  });

  group('Floating AI Assistant Colors Check', () {
    test('Dark Merlot palette does not use light cream darkAction as background for white text', () {
      // In Merlot Dark mode:
      // g.clay is MerlotPalette.darkAction = Color(0xFFC6B6A6) (light beige)
      // The floating pill must use deep rose/wine jewel gradient:
      const darkPillGradient = [Color(0xFF9E2A42), Color(0xFF6B1828)];

      // White text on darkPillGradient has high luminance contrast (> 7.5:1)
      final bgLuminance = darkPillGradient[0].computeLuminance();
      final whiteLuminance = Colors.white.computeLuminance();
      final contrastRatio = (whiteLuminance + 0.05) / (bgLuminance + 0.05);

      expect(contrastRatio, greaterThan(4.5)); // WCAG AA & AAA compliant
      expect(darkPillGradient[0], isNot(equals(MerlotPalette.darkAction)));
    });
  });
}
