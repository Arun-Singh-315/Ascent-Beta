import 'package:ascent/features/home/widgets/home_shortcut_summary.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_shortcut_panel.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:ascent/shared/widgets/ascent_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences shortcutPrefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    shortcutPrefs = await SharedPreferences.getInstance();
  });
  Widget buildTestApp(
    Widget child, {
    double width = 390,
    double height = 844,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(shortcutPrefs),
        homeShortcutSummaryProvider.overrideWith((ref, id) => '0 today'),
      ],
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
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Riya'), findsOneWidget);
      expect(find.text('Vault'), findsOneWidget);
    });

    testWidgets('renders customized user shortcuts (e.g. 2 shortcuts)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(const HomeShortcutPanel(shortcuts: ['today', 'learning'])),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home_shortcut_panel')), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Growth'), findsOneWidget);
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
      expect(find.text('Growth'), findsOneWidget);
      expect(find.text('Money'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('Walk'), findsNothing);
    });

    testWidgets('empty shortcuts retain an editing entry point', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(const HomeShortcutPanel(shortcuts: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose shortcuts'), findsOneWidget);
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

    testWidgets(
      'counts appear above shortcut icons without duplicate summaries',
      (tester) async {
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

        for (final (id, count) in [
          ('today', '5'),
          ('thought-wall', '3'),
          ('promises', '12'),
          ('reminders', '0'),
        ]) {
          final badge = find.byKey(ValueKey('shortcut_badge_$id'));
          expect(badge, findsOneWidget);
          expect(tester.widget<Text>(badge).data, count);
          final icon = find.byKey(ValueKey('shortcut_icon_$id'));
          expect(
            tester.getTopLeft(badge).dy,
            lessThan(tester.getTopLeft(icon).dy),
          );
          expect(
            tester.getCenter(badge).dx,
            greaterThan(tester.getCenter(icon).dx),
          );
          expect(find.text('$count today'), findsNothing);
        }
      },
    );

    testWidgets('large counts remain visible as shortcut badges', (
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

      expect(
        find.byKey(const ValueKey('shortcut_badge_today')),
        findsOneWidget,
      );
      expect(find.text('99+'), findsNothing);
    });

    testWidgets('shortcut values remain visible at large text', (tester) async {
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
      expect(find.text('99+'), findsNothing);
    });
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

      final controls = tester.widgetList<Container>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Subtle'),
            matching: find.byType(AscentCard),
          ),
          matching: find.byType(Container),
        ),
      );
      expect(controls, isNotEmpty);
      for (final control in controls) {
        final decoration = control.decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.color, isNot(const Color(0xFFD97706)));
        }
      }
    });
  });
}
