import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/learning_hub/learning_catalog.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/ai/riya_capabilities.dart';
import 'package:ascent/core/ai/riya_intents.dart';
import 'package:ascent/core/ai/riya_learning_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;
  late LearningHubNotifier notifier;
  late RiyaLearningActions actions;
  late RiyaExecutor executor;
  late RiyaIntentResolver resolver;
  bool fail = false;
  Course course(String id) => Course(
    id: id,
    title: id,
    modules: [
      CourseModule(
        id: 1,
        title: 'Module',
        lectures: [
          const Lecture(
            id: 1,
            moduleId: 1,
            moduleTitle: 'Module',
            title: 'Original',
            durationSeconds: 100,
          ),
        ],
      ),
    ],
  );
  setUp(() async {
    fail = false;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'ascent_learning_hub_courses_v3': jsonEncode([
        course('a').toJson(),
        course('b').toJson(),
      ]),
      'ascent_learning_hub_active_course_v3': 'a',
    });
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        learningCourseSaveProvider.overrideWithValue((json) async {
          if (fail) throw StateError('disk failure');
          await LearningCatalog(db, prefs).saveJson(json);
        }),
      ],
    );
    notifier = container.read(learningHubProvider.notifier);
    await notifier.ready;
    actions = RiyaLearningActions(
      notifier,
      () => container.read(learningHubProvider),
      DateTime.now,
      db: db,
    );
    executor = RiyaExecutor(
      db,
      external: actions.run,
      verifyExternal: actions.verify,
    );
    resolver = RiyaIntentResolver(db);
  });
  tearDown(() async {
    await notifier.settled;
    container.dispose();
    await db.close();
  });
  Future<RiyaResult> run(
    String id,
    Map<String, dynamic> args,
    String request,
  ) => executor.execute(
    RiyaCommand(id, args),
    requestId: request,
    approved: true,
  );

  test(
    'Course/module/lecture creation, scoped reads and edit/delete share the catalog without fabricated progress',
    () async {
      await run('learning.course.create', {'title': 'Networks'}, 'course');
      final id = RiyaLearningActions.courseId('course');
      expect(container.read(learningHubProvider).course.totalLectures, 0);
      await run('learning.module.create', {
        'courseId': id,
        'title': 'Protocols',
      }, 'module');
      final module = RiyaLearningActions.moduleId('module');
      await run('learning.lecture.create', {
        'courseId': id,
        'moduleId': module,
        'title': 'TCP',
        'durationSeconds': 600,
        'threshold': 50,
      }, 'lecture');
      final lecture = container
          .read(learningHubProvider)
          .course
          .modules
          .single
          .lectures
          .single;
      expect(lecture.studySeconds, 0);
      expect(lecture.isCompleted, false);
      expect(lecture.completionThresholdPercent, 50);
      expect(
        (await run('learning.lectures', {
          'courseId': id,
          'moduleId': module,
        }, 'read')).message,
        contains('0% study time'),
      );
      await run('learning.lecture.edit', {
        'courseId': id,
        'lectureId': lecture.id,
        'title': 'TCP basics',
      }, 'edit');
      expect(container.read(learningHubProvider).activeCourseId, id);
      await run('learning.lecture.delete', {
        'courseId': id,
        'lectureId': lecture.id,
      }, 'delete-lecture');
      await run('learning.module.delete', {
        'courseId': id,
        'moduleId': module,
      }, 'delete-module');
      await run('learning.course.delete', {'courseId': id}, 'delete-course');
      expect(await db.courseDao.getCourseById(id), isNull);
      expect(container.read(learningHubProvider).courses, hasLength(2));
    },
  );
  test(
    'Concurrent/replayed creation creates one course with a durable identity',
    () async {
      final command = const RiyaCommand('learning.course.create', {
        'title': 'One course',
      });
      await Future.wait([
        for (var i = 0; i < 2; i++)
          executor.execute(command, requestId: 'one', approved: true),
      ]);
      expect(container.read(learningHubProvider).courses, hasLength(3));
      expect(
        (await executor.execute(
          command,
          requestId: 'one',
          approved: true,
        )).replayed,
        true,
      );
      expect(container.read(learningHubProvider).courses, hasLength(3));
    },
  );
  test(
    'A failed confirmation receipt verifies creation without overwriting later edits',
    () async {
      await db.customStatement(
        "CREATE TRIGGER fail_receipt BEFORE UPDATE ON ${db.aiCommandTable.actualTableName} WHEN OLD.request_id = 'recover' BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await expectLater(
        run('learning.module.create', {
          'courseId': 'a',
          'title': 'Initial',
        }, 'recover'),
        throwsA(isA<RiyaCommittedActionError>()),
      );
      final id = RiyaLearningActions.moduleId('recover');
      final module = container
          .read(learningHubProvider)
          .course
          .modules
          .singleWhere((m) => m.id == id);
      await notifier.updateModule('a', module.copyWith(title: 'Newer title'));
      await db.customStatement('DROP TRIGGER fail_receipt');
      await run('learning.module.create', {
        'courseId': 'a',
        'title': 'Initial',
      }, 'recover');
      expect(
        container
            .read(learningHubProvider)
            .course
            .modules
            .singleWhere((m) => m.id == id)
            .title,
        'Newer title',
      );
      expect(
        container
            .read(learningHubProvider)
            .course
            .modules
            .where((m) => m.originRequestId == 'recover'),
        hasLength(1),
      );
    },
  );
  test(
    'Invalid/missing targets and persistence failure cannot publish success or forge evidence',
    () async {
      await expectLater(
        run('learning.lecture.create', {
          'courseId': 'a',
          'moduleId': 1,
          'title': 'Bad policy',
          'durationSeconds': 100,
          'threshold': 10,
        }, 'policy'),
        throwsArgumentError,
      );
      await expectLater(
        run('learning.lecture.edit', {
          'courseId': 'a',
          'lectureId': 999,
          'title': 'Missing',
        }, 'missing'),
        throwsStateError,
      );
      await expectLater(
        run('learning.lecture.edit', {
          'courseId': 'a',
          'lectureId': 1,
          'studySeconds': 100,
        }, 'forged'),
        throwsArgumentError,
      );
      fail = true;
      await expectLater(
        run('learning.course.create', {'title': 'Fails'}, 'fails'),
        throwsStateError,
      );
      expect(container.read(learningHubProvider).courses, hasLength(2));
      expect(
        await db.courseDao.getCourseById(RiyaLearningActions.courseId('fails')),
        isNull,
      );
      expect(
        container
            .read(learningHubProvider)
            .course
            .modules
            .single
            .lectures
            .single
            .studySeconds,
        0,
      );
    },
  );
  test(
    'Course edit can clear nullable fields without changing other fields',
    () async {
      await run('learning.course.edit', {
        'courseId': 'a',
        'sourceUrl': 'https://example.com/course',
        'targetDate': '2027-04-01',
      }, 'set');
      await run('learning.course.edit', {
        'courseId': 'a',
        'title': 'Renamed',
        'clearUrl': true,
        'clearDate': true,
      }, 'clear');
      final current = container
          .read(learningHubProvider)
          .courses
          .singleWhere((c) => c.id == 'a');
      expect(current.sourceUrl, isNull);
      expect(current.targetCompletionDate, isNull);
      expect(current.modules.single.lectures.single.title, 'Original');
    },
  );
  test(
    'Natural course references resolve real unique titles and reject ambiguity; equal lecture IDs stay scoped',
    () async {
      final parsed = (await resolver.resolve(
        'Create module New module in course a',
      ))!.command!;
      expect(parsed.id, 'learning.module.create');
      expect(parsed.arguments['courseId'], 'a');
      await run('learning.lecture.edit', {
        'courseId': 'b',
        'lectureId': 1,
        'title': 'B changed',
      }, 'edit-b');
      expect(
        container
            .read(learningHubProvider)
            .courses
            .singleWhere((c) => c.id == 'a')
            .modules
            .single
            .lectures
            .single
            .title,
        'Original',
      );
      await notifier.updateCourse(
        container
            .read(learningHubProvider)
            .courses
            .singleWhere((c) => c.id == 'b')
            .copyWith(title: 'a'),
      );
      expect(
        (await resolver.resolve(
          'Show modules in course a',
        ))!.command!.arguments['courseId'],
        'a',
      ); // Exact ID wins.
      await run('learning.course.create', {'title': 'Duplicate'}, 'dup1');
      await run('learning.course.create', {'title': 'Duplicate'}, 'dup2');
      expect(
        (await resolver.resolve('Show modules in course Duplicate'))!.command,
        isNull,
      );
    },
  );
}
