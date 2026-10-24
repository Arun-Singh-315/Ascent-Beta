import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/home_overview_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('HomeOverviewCard renders 4 quick-action toggles', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
          allRemindersProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const Scaffold(
            body: HomeOverviewCard(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify "Your day at a glance" heading
    expect(find.text('Your day at a glance'), findsOneWidget);

    // Verify 4 quick-action shortcut toggles exist
    expect(find.byKey(const ValueKey('glance_toggle_tasks')), findsOneWidget);
    expect(find.byKey(const ValueKey('glance_toggle_reminders')), findsOneWidget);
    expect(find.byKey(const ValueKey('glance_toggle_notes')), findsOneWidget);
    expect(find.byKey(const ValueKey('glance_toggle_focus')), findsOneWidget);
  });

  testWidgets('Tapping Tasks toggle opens connected quick popup and dismisses cleanly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          todayActivitiesProvider.overrideWith((ref) => Stream.value([
            TodayActivityItem(
              id: 'task_1',
              title: 'Review System Design',
              sourceType: 'task',
              categoryTag: 'Task',
              status: TodayActivityStatus.notStarted,
              elapsedSecondsToday: 0,
              kind: ActivityKind.todo,
            ),
          ])),
          allRemindersProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const Scaffold(
            body: HomeOverviewCard(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Tasks toggle
    await tester.tap(find.byKey(const ValueKey('glance_toggle_tasks')));
    await tester.pumpAndSettle();

    // Popup is open
    expect(find.byKey(const ValueKey('glance_popup_tasks')), findsOneWidget);
    expect(find.text('Review System Design'), findsOneWidget);

    // Close button dismisses popup cleanly without blocking
    final closeBtn = find.byKey(const ValueKey('glance_popup_close_tasks'));
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    // Popup is dismissed
    expect(find.byKey(const ValueKey('glance_popup_tasks')), findsNothing);
  });

  testWidgets('Tapping Notes toggle opens connected quick thought composer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
          allRemindersProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const Scaffold(
            body: HomeOverviewCard(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Notes toggle
    await tester.tap(find.byKey(const ValueKey('glance_toggle_notes')));
    await tester.pumpAndSettle();

    // Notes popup is visible
    expect(find.byKey(const ValueKey('glance_popup_notes')), findsOneWidget);
    expect(find.byKey(const ValueKey('glance_quick_note_field')), findsOneWidget);

    // Close notes popup
    await tester.tap(find.byKey(const ValueKey('glance_popup_close_notes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('glance_popup_notes')), findsNothing);
  });

  testWidgets('Tapping Focus / Habit toggle opens quick action hub', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
          allRemindersProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const Scaffold(
            body: HomeOverviewCard(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Focus toggle
    await tester.tap(find.byKey(const ValueKey('glance_toggle_focus')));
    await tester.pumpAndSettle();

    // Focus popup is visible with quick actions
    expect(find.byKey(const ValueKey('glance_popup_focus')), findsOneWidget);
    expect(find.text('Log +250ml Water'), findsOneWidget);

    // Close focus popup
    await tester.tap(find.byKey(const ValueKey('glance_popup_close_focus')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('glance_popup_focus')), findsNothing);
  });
}
