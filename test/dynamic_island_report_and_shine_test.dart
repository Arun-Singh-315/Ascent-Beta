import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/island_preferences_provider.dart';
import 'package:ascent/core/providers/daily_briefing_provider.dart';
import 'package:ascent/features/home/widgets/ascent_dynamic_island.dart';
import 'package:ascent/features/home/widgets/island_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const sampleBriefing = DailyBriefing(
    completedYesterday: 4,
    plannedYesterday: 5,
    finishedPlannedYesterday: 4,
    trackedMinutesYesterday: 50,
    dueToday: 1,
    overdue: 1,
    unscheduled: 0,
  );

  Widget buildTestApp({
    required Widget child,
    DailyBriefing briefing = sampleBriefing,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dailyBriefingProvider.overrideWith((ref, day) async => briefing),
        allRemindersProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('Dynamic Island Report & Specular Shine Tests', () {
    testWidgets('Expanded recap displays clean executive report points with icons and phrased text, not square boxes', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const AscentDynamicIsland(
            initiallyExpanded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Island expanded is present
      expect(find.byKey(const ValueKey('dynamic_island_expanded')), findsOneWidget);

      // Report heading is present
      expect(find.text("Yesterday's Executive Report"), findsOneWidget);

      // Executive report points are rendered with phrased copy and icons
      expect(find.text('Completed Tasks'), findsOneWidget);
      expect(find.text('4 tasks finished on schedule'), findsOneWidget);

      expect(find.text('Focus & Flow'), findsOneWidget);
      expect(find.text('50 minutes of deep tracked flow'), findsOneWidget);

      expect(find.text('Action Needed'), findsOneWidget);
      expect(find.text('1 overdue task pending review'), findsOneWidget);

      // Verify no shortcuts panel exists inside the dynamic island
      expect(find.byKey(const ValueKey('home_shortcut_panel')), findsNothing);
    });

    testWidgets('Dismissing the recap report makes the island completely vanish when no other activity is active', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const AscentDynamicIsland(
            initiallyExpanded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dynamic_island_surface')), findsOneWidget);
      expect(find.byKey(const ValueKey('island_dismiss_report_button')), findsOneWidget);

      // Tap Dismiss Report / Got it button
      await tester.tap(find.byKey(const ValueKey('island_dismiss_report_button')));
      await tester.pumpAndSettle();

      // Island vanishes completely! No useless static cards left on screen.
      expect(find.byKey(const ValueKey('dynamic_island_surface')), findsNothing);
    });

    testWidgets('IslandSurface renders specular top shine glass highlight', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IslandSurface(
              palette: IslandPalette.resolve(IslandFinish.sapphire, false),
              child: const Text('Test Surface'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('island_specular_shine')), findsOneWidget);
      expect(find.text('Test Surface'), findsOneWidget);
    });
  });
}
