import 'dart:async';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/challenge/challenge_providers.dart';
import 'package:ascent/features/challenge/domain/challenge_service.dart';
import 'package:ascent/features/challenge/integration/challenge_proof_sync.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/features/home/widgets/home_dismissible_reminders_section.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/thought_wall/thought_actions.dart';
import 'package:ascent/shared/widgets/feature_guide.dart';
import 'package:ascent/shared/widgets/undo_snackbar.dart';

class _EmptyLearningHub extends LearningHubNotifier {
  @override
  LearningHubState build() => const LearningHubState(
    courses: [],
    activeCourseId: '',
    activeLectureId: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  test(
    'all active challenges sync their own Focus evidence regardless of Home selection',
    () async {
      final now = DateTime.now();
      final category = await db.timeSessionDao.insertCategory(
        SessionCategoryTableCompanion.insert(
          name: 'Study',
          colorHex: '#38664D',
        ),
      );
      final taskA = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'A'),
      );
      final taskB = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'B'),
      );
      final service = ChallengeService(db);
      Future<int> create(String title, int task) => service.create(
        type: 'activity',
        title: title,
        sourceType: 'task',
        sourceId: '$task',
        targetTotal: 120,
        dailyMinimum: 20,
        durationDays: 6,
        now: now.subtract(const Duration(hours: 1)),
      );
      final a = await create('A', taskA);
      final b = await create('B', taskB);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          learningHubProvider.overrideWith(_EmptyLearningHub.new),
        ],
      );
      try {
        await container.read(homeChallengeIdProvider.future);
        await container.read(homeChallengeIdProvider.notifier).select(a);
        container.listen(challengeProofSyncProvider, (_, _) {});
        await container.read(allChallengesProvider.future);
        for (final (task, seconds) in [(taskA, 600), (taskB, 1200)]) {
          await db
              .into(db.timeSessionTable)
              .insert(
                TimeSessionTableCompanion.insert(
                  label: 'Completed focus',
                  categoryId: category,
                  linkedTaskId: drift.Value(task),
                  startedAt: now.subtract(Duration(seconds: seconds)),
                  endedAt: drift.Value(now),
                  status: const drift.Value('completed'),
                  durationSeconds: drift.Value(seconds),
                ),
              );
        }
        final proofs = await Future.wait([
          db.challengeDao
              .watchProofs(a)
              .firstWhere((events) => events.isNotEmpty),
          db.challengeDao
              .watchProofs(b)
              .firstWhere((events) => events.isNotEmpty),
        ]).timeout(const Duration(seconds: 5));
        expect(proofs[0].single.amount, 10);
        expect(proofs[1].single.amount, 20);
        expect(proofs[0].single.sourceId, isNot(proofs[1].single.sourceId));
      } finally {
        container.dispose();
        await Future<void>.delayed(Duration.zero);
      }
    },
  );

  test(
    'bulk Todo is idempotent and reminders link to their corresponding tasks',
    () async {
      for (final text in ['Read chapter 1', 'Practice arrays']) {
        await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: text),
        );
      }
      final thoughts = await db.thoughtDao.watchAllThoughts().first;
      final actions = ThoughtActions(db);
      final first = await actions.addToTodo(thoughts);
      expect(await actions.addToTodo(thoughts), first);
      expect(await db.taskDao.watchAllTasks().first, hasLength(2));
      await db.taskDao.updateTask(
        TaskTableCompanion(
          id: drift.Value(first.first),
          notes: drift.Value('thought_id:${thoughts.first.id}'),
        ),
      );
      expect(await actions.addToTodo(thoughts), first);
      expect(await db.taskDao.watchAllTasks().first, hasLength(2));
      final at = DateTime.now().add(const Duration(days: 1));
      final reminders = await actions.remind(thoughts, at);
      expect(reminders.map((r) => r.linkedTaskId).toList(), first);
      final list = await actions.remind(thoughts, at, asList: true);
      expect(list, hasLength(1));
      expect(list.single.title, contains('1.'));
      expect(list.single.title, contains('2.'));
      expect(list.single.title, contains('Read chapter 1'));
      await expectLater(
        actions.remind(
          thoughts,
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'Home challenge choice survives container recreation and archived choice falls back',
    () async {
      final service = ChallengeService(db);
      Future<int> create(String title) => service.create(
        type: 'activity',
        title: title,
        sourceType: 'task',
        sourceId: title,
        targetTotal: 120,
        dailyMinimum: 20,
        durationDays: 6,
      );
      final first = await create('First');
      final second = await create('Second');
      var container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      await container.read(homeChallengeIdProvider.future);
      await container.read(homeChallengeIdProvider.notifier).select(first);
      container.dispose();
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      container.listen(allChallengesProvider, (_, _) {});
      expect(await container.read(homeChallengeIdProvider.future), first);
      await container.read(allChallengesProvider.future);
      expect(container.read(activeChallengeProvider).value?.id, first);
      final switched = Completer<Challenge?>();
      final subscription = container.listen(activeChallengeProvider, (_, next) {
        if (next.value?.id == second && !switched.isCompleted) {
          switched.complete(next.value);
        }
      });
      await service.archive(first);
      expect(
        (await switched.future.timeout(const Duration(seconds: 5)))?.id,
        second,
      );
      subscription.close();
      final next = await db.challengeDao.watchActiveChallenges().first;
      expect(next.single.id, second);
    },
  );

  testWidgets('Home sends a note inline without opening a sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const Scaffold(body: ThoughtWallHomePreview()),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'My direct Home note');
    await tester.pump();
    await tester.tap(find.byTooltip('Send capture'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final thoughts = await db.thoughtDao.watchAllThoughts().first;
      expect(thoughts.single.content, 'My direct Home note');
    });
    await tester.pump();
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'Home reminders hide when empty and tapping the title navigates without mutation',
    (tester) async {
      var opened = false;
      var mutated = false;
      Widget build(List<Reminder> reminders) => MaterialApp(
        theme: AscentTheme.light(),
        home: Scaffold(
          body: HomeDismissibleRemindersSection(
            reminders: reminders,
            onDismissReminder: (_) async => mutated = true,
            onViewAll: () => opened = true,
            onAddReminder: () => mutated = true,
          ),
        ),
      );
      await tester.pumpWidget(build([]));
      expect(find.byType(InkWell), findsNothing);
      final id = await tester.runAsync(
        () => db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: 'Read tonight',
            scheduledAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        ),
      );
      final reminder = await tester.runAsync(
        () => db.reminderDao.getReminderById(id!),
      );
      await tester.pumpWidget(build([reminder!]));
      expect(find.byType(Dismissible), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      await tester.tap(find.text('Read tonight'));
      expect(opened, isTrue);
      expect(mutated, isFalse);
    },
  );

  testWidgets('Undo message expires without user dismissal', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    showUndoSnackbar(context, message: 'Thought archived', onUndo: () {});
    await tester.pumpAndSettle();
    expect(find.text('Thought archived'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Thought archived'), findsNothing);
  });

  testWidgets('first-use guidance is shown once and can be replayed', (
    tester,
  ) async {
    Widget screen() => const MaterialApp(
      home: Scaffold(
        body: FeatureGuideHost(
          feature: 'Thought Wall',
          child: Text('Wall content'),
        ),
      ),
    );
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('Got it'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'feature_guide_v1_Thought Wall',
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('Got it'), findsNothing);
  });

  testWidgets('guided tour advances, goes back, and can be left for later', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAscentTour(context),
              child: const Text('Start tour'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start tour'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your daily dashboard'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Plan your work'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your daily dashboard'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
