import 'dart:async';
import 'dart:io';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/home_dismissible_reminders_section.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:ascent/shared/utils/action_text.dart';
import 'package:ascent/shared/widgets/note_list_button.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelayedDeleteDao extends TaskDao {
  DelayedDeleteDao(super.db);
  final gate = Completer<void>();
  @override
  Future<int> deleteTask(int id, {bool bypassProtection = false}) async {
    await gate.future;
    return super.deleteTask(id, bypassProtection: bypassProtection);
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settleDb(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test(
    'supporting text hides duplicates while preserving distinct words and notes',
    () {
      expect(actionSupportingText('Read Java', '  read  Java\n'), isNull);
      expect(
        actionSupportingText('Read Java', 'Read Java\n\nChapter 2'),
        'Chapter 2',
      );
      expect(
        actionSupportingText('Run', 'Running tomorrow'),
        'Running tomorrow',
      );
      expect(
        actionSupportingText('New title', 'Original thought'),
        'Original thought',
      );
    },
  );

  test('arrow insertion respects existing spacing and cursor selection', () {
    for (final text in ['First', 'First\n', 'First\n\n']) {
      final controller = TextEditingController(text: text);
      NoteListButton.insertNextItem(controller);
      expect(controller.text, 'First\n\n→ ');
      NoteListButton.insertNextItem(controller);
      expect(controller.text, 'First\n\n→ ');
      controller.dispose();
    }
    final controller = TextEditingController(text: 'FirstreplaceLast')
      ..selection = const TextSelection(baseOffset: 5, extentOffset: 12);
    NoteListButton.insertNextItem(controller);
    expect(controller.text, 'First\n\n→ Last');
    controller.dispose();
  });

  test(
    'schema 18 migration preserves thought type, history and task link',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ascent-thought-category-',
      );
      final file = File('${directory.path}/workspace.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'My life goal',
            mood: const d.Value('promise'),
            isArchived: const d.Value(true),
          ),
        );
        final task = await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Act on goal',
            linkedThoughtId: d.Value(id),
          ),
        );
        await db.customStatement('ALTER TABLE thoughts DROP COLUMN category');
        await db.customStatement('PRAGMA user_version = 18');
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        final migrated = (await db.thoughtDao.getThoughtById(id))!;
        expect(migrated.category, 'general');
        expect(migrated.mood, 'promise');
        expect(migrated.isArchived, true);
        await db.thoughtDao.moveToCategory([id], 'life_goals');
        expect(
          (await db.thoughtDao.getThoughtById(id))!.category,
          'life_goals',
        );
        expect((await db.taskDao.getTaskById(task))!.linkedThoughtId, id);
        await expectLater(
          db.thoughtDao.moveToCategory([id], 'invalid'),
          throwsArgumentError,
        );
        expect(
          (await db.thoughtDao.getThoughtById(id))!.category,
          'life_goals',
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('Reminders heading disappears together with the empty preview', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    try {
      final id = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Call',
          scheduledAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final reminder = (await db.reminderDao.getReminderById(id))!;
      Widget view(List<Reminder> reminders) => MaterialApp(
        home: Scaffold(
          body: HomeDismissibleRemindersSection(
            reminders: reminders,
            onDismissReminder: (_) async {},
          ),
        ),
      );
      await tester.pumpWidget(view([reminder]));
      expect(find.text('Reminders'), findsOneWidget);
      await tester.pumpWidget(view([]));
      expect(find.text('Reminders'), findsNothing);
      expect(find.byType(Dismissible), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  for (final fail in [false, true]) {
    testWidgets(
      'swipe removes dismissed widget during slow deletion; failure=$fail',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'feature_guide_v1_Thought Wall': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final dao = DelayedDeleteDao(db);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            taskDaoProvider.overrideWithValue(dao),
          ],
        );
        try {
          final id = await db.taskDao.insertTask(
            TaskTableCompanion.insert(title: 'Swipe me'),
          );
          final child = await db.taskDao.insertTask(
            TaskTableCompanion.insert(
              title: 'Child',
              parentTaskId: d.Value(id),
            ),
          );
          final reminderId = await db.reminderDao.insertReminder(
            ReminderTableCompanion.insert(
              title: 'Linked reminder',
              scheduledAt: DateTime.now().add(const Duration(hours: 1)),
              linkedTaskId: d.Value(id),
            ),
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AscentTheme.light(),
                home: Scaffold(
                  body: ActivityRowItem(
                    activity: TodayActivityItem(
                      id: 'task_$id',
                      title: 'Swipe me',
                      sourceType: 'task',
                      status: TodayActivityStatus.notStarted,
                      elapsedSecondsToday: 0,
                      categoryTag: 'task',
                      linkedTaskId: id,
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          await tester.drag(
            find.byKey(ValueKey('task_$id')),
            const Offset(-700, 0),
          );

          await settleDb(tester);

          expect(find.byKey(ValueKey('task_$id')), findsNothing);
          expect(tester.takeException(), isNull);
          if (fail) {
            dao.gate.completeError(StateError('Simulated write failure'));
          } else {
            dao.gate.complete();
          }
          await settleDb(tester);

          if (fail) {
            expect(find.byKey(ValueKey('task_$id')), findsOneWidget);
            expect(
              await tester.runAsync(() => db.taskDao.getTaskById(id)),
              isNotNull,
            );
          } else {
            expect(
              await tester.runAsync(() => db.taskDao.getTaskById(id)),
              isNull,
            );

            await tester.tap(find.text('Undo'));
            await settleDb(tester);

            expect(
              await tester.runAsync(() => db.taskDao.getTaskById(id)),
              isNotNull,
            );
            expect(
              await tester.runAsync(() => db.taskDao.getTaskById(child)),
              isNotNull,
            );
            expect(
              await tester.runAsync(
                () => db.reminderDao.getReminderById(reminderId),
              ),
              isNotNull,
            );
            expect(find.byKey(ValueKey('task_$id')), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          container.dispose();
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
        }
      },
    );
  }

  testWidgets(
    'bulk category moves persist into category-filtered history and Undo restores both',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'feature_guide_v1_Thought Wall': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      tester.view.physicalSize = const Size(500, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        final now = DateTime.now();
        final ids = <int>[];
        for (final title in ['First reflection', 'Second reflection']) {
          ids.add(
            await db.thoughtDao.insertThought(
              ThoughtTableCompanion.insert(
                content: title,
                createdAt: d.Value(DateTime(now.year, now.month, now.day - 1)),
              ),
            ),
          );
        }
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const ThoughtWallScreen(),
            ),
          ),
        );
        await settleDb(tester);
        await tester.tap(find.text('History & Archive'));
        await tester.pumpAndSettle();
        await tester.longPress(find.textContaining('First reflection'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Second reflection'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Move to category'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Life Goals').last);
        await settleDb(tester);
        for (final id in ids) {
          expect(
            (await tester.runAsync(
              () => db.thoughtDao.getThoughtById(id),
            ))!.category,
            'life_goals',
          );
        }
        await tester.tap(find.byTooltip('Category filter'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Life Goals'));
        await tester.pumpAndSettle();
        expect(find.textContaining('First reflection'), findsOneWidget);
        expect(find.textContaining('Second reflection'), findsOneWidget);
        await tester.tap(find.text('Undo'));
        await settleDb(tester);
        for (final id in ids) {
          final thought = (await tester.runAsync(
            () => db.thoughtDao.getThoughtById(id),
          ))!;
          expect(thought.category, 'general');
          expect(thought.isArchived, false);
        }
        expect(find.textContaining('First reflection'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }
    },
  );
}
