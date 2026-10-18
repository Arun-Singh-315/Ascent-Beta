import 'dart:async';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/features/today/add_activity_sheet.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'activity_composer_test.dart' show settleDatabase;

class _IdleTracking extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _NoLearning extends LearningHubNotifier {
  @override
  LearningHubState build() => const LearningHubState(
    courses: [],
    activeCourseId: '',
    activeLectureId: 0,
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets(
    'editor saves To-do to Timer and back without duplicating activity',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await tester.runAsync(
        () => db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Convert me',
            plannedDate: d.Value(DateTime.now()),
          ),
        ),
      );
      var snapshot = (await tester.runAsync(
        () async => (await db.taskDao.getTaskById(id!))!,
      ))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      AddActivitySheet.show(context, existingTask: snapshot),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      for (final type in ['Timed', 'To-do']) {
        await tester.tap(find.text('Edit'));
        await settleDatabase(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text(type));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save Changes'));
        await tester.tap(find.text('Save Changes'));
        await settleDatabase(tester);
        await tester.pumpAndSettle();
        snapshot = (await tester.runAsync(
          () async => (await db.taskDao.getTaskById(id!))!,
        ))!;
        expect(snapshot.estimatedMinutes, type == 'Timed' ? 30 : null);
        expect(find.text('Edit Activity'), findsNothing);
        expect(snapshot.actualCompletedDate, isNull);
      }
      expect(
        await tester.runAsync(() => db.select(db.taskTable).get()),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  test('ended session history does not mark a converted To-do done', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(_IdleTracking.new),
        learningHubProvider.overrideWith(_NoLearning.new),
      ],
    );
    try {
      final id = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Still pending',
          plannedDate: d.Value(DateTime.now()),
          estimatedMinutes: const d.Value(30),
        ),
      );
      await db.timeSessionDao.ensureDefaultCategories();
      final category = (await db.timeSessionDao.getAllCategories()).first.id;
      await db
          .into(db.timeSessionTable)
          .insert(
            TimeSessionTableCompanion.insert(
              label: 'Still pending',
              categoryId: category,
              startedAt: DateTime.now(),
              status: const d.Value('completed'),
              durationSeconds: const d.Value(600),
              linkedTaskId: d.Value(id),
            ),
          );
      expect(
        await db.taskDao.updateTask(
          TaskTableCompanion(
            id: d.Value(id),
            estimatedMinutes: const d.Value(null),
          ),
        ),
        isTrue,
      );
      final ready = Completer<List<TodayActivityItem>>();
      final sub = container.listen(todayActivitiesProvider, (_, value) {
        if (value.hasValue && !ready.isCompleted) ready.complete(value.value!);
        if (value.hasError && !ready.isCompleted) {
          ready.completeError(value.error!, value.stackTrace);
        }
      }, fireImmediately: true);
      late List<TodayActivityItem> list;
      try {
        list = await ready.future.timeout(const Duration(seconds: 5));
      } finally {
        sub.close();
      }
      expect(
        list.singleWhere((a) => a.linkedTaskId == id).status,
        TodayActivityStatus.notStarted,
      );
    } finally {
      container.dispose();
      await db.close();
    }
  });
}
