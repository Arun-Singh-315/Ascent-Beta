import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_shortcut_panel.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:ascent/shared/widgets/ascent_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp(
    Widget child, {
    double width = 390,
    double height = 844,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  group('HomeShortcutPanel Dynamic Shortcuts Tests', () {
    testWidgets('renders default 4 shortcuts when no shortcuts passed', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const HomeShortcutPanel()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home_shortcut_panel')), findsOneWidget);
      expect(find.text('Mind Space'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Challenges'), findsOneWidget);
      expect(find.text('Vault'), findsOneWidget);
    });

    testWidgets('renders customized user shortcuts (e.g. 2 shortcuts)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const HomeShortcutPanel(shortcuts: ['today', 'learning']),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home_shortcut_panel')), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Learning'), findsOneWidget);
      expect(find.text('Mind Space'), findsNothing);
      expect(find.text('Vault'), findsNothing);
    });

    testWidgets('caps at 4 shortcuts even if more IDs provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const HomeShortcutPanel(
            shortcuts: ['today', 'learning', 'money', 'focus', 'walk'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home_shortcut_panel')), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Learning'), findsOneWidget);
      expect(find.text('Money'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('Walk'), findsNothing);
    });

    testWidgets('hides panel when empty list provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const HomeShortcutPanel(shortcuts: [])),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home_shortcut_panel')), findsNothing);
    });

    testWidgets('immune to overflow at 320px width with 2.0x text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const HomeShortcutPanel(
            shortcuts: ['thought-wall', 'hydration', 'momentum', 'vault'],
          ),
          width: 320,
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('home_shortcut_panel')), findsOneWidget);
    });

    testWidgets('renders badge counters for active counts and hides when zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const HomeShortcutPanel(
            shortcuts: ['today', 'thought-wall', 'reminders', 'promises'],
            badgeCounts: {
              'today': 5,
              'thought-wall': 3,
              'reminders': 0,
              'promises': 12,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badges for positive counts should appear
      expect(find.byKey(const ValueKey('shortcut_badge_today')), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      expect(
        find.byKey(const ValueKey('shortcut_badge_thought-wall')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);

      expect(
        find.byKey(const ValueKey('shortcut_badge_promises')),
        findsOneWidget,
      );
      expect(find.text('12'), findsOneWidget);

      // Badge for 0 count should NOT appear
      expect(
        find.byKey(const ValueKey('shortcut_badge_reminders')),
        findsNothing,
      );
    });

    testWidgets('caps badge counter at 99+ when count exceeds 99', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          const HomeShortcutPanel(
            shortcuts: ['today'],
            badgeCounts: {'today': 150},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('shortcut_badge_today')), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets(
      'badges remain immune to overflow at 320px width with 2.0x text scale',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const HomeShortcutPanel(
              shortcuts: ['today', 'thought-wall', 'reminders', 'promises'],
              badgeCounts: {
                'today': 24,
                'thought-wall': 18,
                'reminders': 9,
                'promises': 150,
              },
            ),
            width: 320,
            textScale: 2.0,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('24'), findsOneWidget);
        expect(find.text('18'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
        expect(find.text('99+'), findsOneWidget);
      },
    );
  });

  group('Glass Translucency Selection UI Tests', () {
    testWidgets('Settings screen does NOT show mustard yellow in selection', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Display Mode is removed
      expect(find.text('Display Mode'), findsNothing);
      expect(find.text('Day / Light'), findsNothing);
      expect(find.text('Night / Dark'), findsNothing);

      // Verify Glass Translucency header and options exist
      expect(find.text('Glass Translucency'), findsOneWidget);
      expect(find.text('Subtle'), findsOneWidget);
      expect(find.text('Balanced'), findsOneWidget);
      expect(find.text('Contrast'), findsOneWidget);

      // Verify that no option in Glass Translucency has mustard yellow
      final cards = tester.widgetList<AppCard>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Subtle'),
            matching: find.byType(AscentCard),
          ),
          matching: find.byType(AppCard),
        ),
      );
      expect(cards, isNotEmpty);
      for (final card in cards) {
        final nightDec = card.nightDecoration;
        if (nightDec != null) {
          expect(
            nightDec.color,
            isNot(equals(MerlotPalette.antiqueGold)),
            reason: 'Mustard yellow antiqueGold was found in glass selection',
          );
          expect(
            nightDec.color,
            isNot(equals(const Color(0xFFD97706))),
            reason: 'Color 0xFFD97706 was found in glass selection',
          );
        }
      }
    });
  });
}
