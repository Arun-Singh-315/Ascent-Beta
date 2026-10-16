import 'dart:convert';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_catalog.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/today/task_board_screen.dart';
import 'package:ascent/features/study_plan/lecture_focus_player_sheet.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets(
    'Timed todo sends once to selected course and opens its lecture player',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'feature_guide_v1_Tasks & Today': true,
        learningCatalogPreferenceKey: jsonEncode([
          Course(
            id: 'sql',
            title: 'SQL Course',
            modules: [CourseModule(id: 1, title: 'Basics', lectures: [])],
          ).toJson(),
        ]),
      });
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      await container.read(learningHubProvider.notifier).ready;
      final id = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Watch SQL lesson',
          estimatedMinutes: const d.Value(20),
          notes: const d.Value('Keep these notes'),
          plannedDate: d.Value(DateTime.now()),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 30; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 300));
      }

      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: TaskBoardScreen()),
          ),
        );
        await settle();
        await tester.tap(find.text('Watch SQL lesson'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Send to lecture'));
        await tester.pumpAndSettle();
        expect(find.text('Send to lecture'), findsOneWidget);
        await tester.ensureVisible(find.text('Cancel').last);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(
            () => db.taskDao.getTaskById(id),
          ))!.learningCourseId,
          isNull,
        );
        await tester.tap(find.text('Watch SQL lesson'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Send to lecture'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save lecture activity'));
        await tester.tap(find.text('Save lecture activity'));
        await settle();
        final task = (await tester.runAsync(() => db.taskDao.getTaskById(id)))!;
        expect(task.learningCourseId, 'sql');
        expect(task.learningLectureId, isNotNull);
        expect(task.notes, 'Keep these notes');
        expect(
          await tester.runAsync(() => db.select(db.taskTable).get()),
          hasLength(1),
        );
        final hub = container.read(learningHubProvider);
        expect(hub.activeLecture.title, 'Watch SQL lesson');
        expect(hub.activeLecture.durationSeconds, 1200);
        expect(hub.activeLecture.studySeconds, 0);
        expect(find.byType(LectureFocusPlayerSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(
          () => container.read(learningHubProvider.notifier).settled,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
        container.dispose();
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(db.close);
      }
    },
  );
}
