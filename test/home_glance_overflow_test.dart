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

  testWidgets('HomeOverviewCard renders without overflow at 320px with 2.0x text scale', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(320 * 2, 700 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          todayActivitiesProvider.overrideWith((ref) => Stream.value([
            TodayActivityItem(
              id: 'task_1',
              title: 'Review System Design Specifications with Long Multi-Line Title',
              sourceType: 'task',
              categoryTag: 'Task',
              status: TodayActivityStatus.notStarted,
              elapsedSecondsToday: 0,
              kind: ActivityKind.todo,
            ),
          ])),
          allRemindersProvider.overrideWith((ref) => Stream.value([
            Reminder(
              id: 1,
              title: 'Pay server bill and schedule meeting with infrastructure team',
              scheduledAt: DateTime.now().add(const Duration(hours: 2)),
              alarmEnabled: true,
              alertSyncPending: false,
              isActive: true,
              createdAt: DateTime.now(),
            ),
          ])),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: HomeOverviewCard(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify card renders cleanly with zero RenderFlex overflows
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('home_overview')), findsOneWidget);

    // Test opening the Tasks popup under 320px + 2.0x scale
    await tester.tap(find.byKey(const ValueKey('glance_toggle_tasks')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('glance_popup_tasks')), findsOneWidget);

    // Close
    await tester.tap(find.byKey(const ValueKey('glance_popup_close_tasks')));
    await tester.pumpAndSettle();

    // Test opening the Reminders popup under 320px + 2.0x scale
    await tester.tap(find.byKey(const ValueKey('glance_toggle_reminders')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('glance_popup_reminders')), findsOneWidget);

    // Close
    await tester.tap(find.byKey(const ValueKey('glance_popup_close_reminders')));
    await tester.pumpAndSettle();
  });
}
