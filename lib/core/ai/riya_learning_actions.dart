import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../learning_hub/learning_hub_models.dart';
import '../database/app_database.dart';
import '../learning_hub/learning_hub_provider.dart';
import 'riya_capabilities.dart';

const riyaLearningWriteIds = <String>{
  'learning.course.create',
  'learning.course.edit',
  'learning.course.delete',
  'learning.module.create',
  'learning.module.edit',
  'learning.module.delete',
  'learning.lecture.create',
  'learning.lecture.edit',
  'learning.lecture.delete',
  'learning.select',
  'learning.link',
};
const riyaLearningCapabilities = <RiyaCapability>[
  RiyaCapability(
    'learning.modules',
    'Read course modules',
    '/learning',
    {'courseId': RiyaValue.text, 'offset': RiyaValue.offset},
    required: ['courseId'],
  ),
  RiyaCapability(
    'learning.lectures',
    'Read module lectures',
    '/learning',
    {
      'courseId': RiyaValue.text,
      'moduleId': RiyaValue.integer,
      'offset': RiyaValue.offset,
    },
    required: ['courseId', 'moduleId'],
  ),
  RiyaCapability(
    'learning.course.create',
    'Create a course',
    '/learning',
    {'title': RiyaValue.text, 'description': RiyaValue.longText},
    required: ['title'],
    write: true,
  ),
  RiyaCapability(
    'learning.course.edit',
    'Edit a course',
    '/learning',
    {
      'courseId': RiyaValue.text,
      'title': RiyaValue.text,
      'description': RiyaValue.longText,
      'author': RiyaValue.text,
      'category': RiyaValue.text,
      'sourceUrl': RiyaValue.text,
      'clearUrl': RiyaValue.boolean,
      'targetDate': RiyaValue.date,
      'clearDate': RiyaValue.boolean,
      'dailyMinutes': RiyaValue.integer,
    },
    required: ['courseId'],
    write: true,
  ),
  RiyaCapability(
    'learning.course.delete',
    'Delete a course',
    '/learning',
    {'courseId': RiyaValue.text},
    required: ['courseId'],
    write: true,
  ),
  RiyaCapability(
    'learning.module.create',
    'Create a course module',
    '/learning',
    {
      'courseId': RiyaValue.text,
      'title': RiyaValue.text,
      'description': RiyaValue.longText,
    },
    required: ['courseId', 'title'],
    write: true,
  ),
  RiyaCapability(
    'learning.module.edit',
    'Edit a course module',
    '/learning',
    {
      'courseId': RiyaValue.text,
      'moduleId': RiyaValue.integer,
      'title': RiyaValue.text,
      'description': RiyaValue.longText,
    },
    required: ['courseId', 'moduleId'],
    write: true,
  ),
  RiyaCapability(
    'learning.module.delete',
    'Delete a course module',
    '/learning',
    {'courseId': RiyaValue.text, 'moduleId': RiyaValue.integer},
    required: ['courseId', 'moduleId'],
    write: true,
  ),
  RiyaCapability(
    'learning.lecture.create',
    'Create a lecture',
    '/learning',
    {
      'courseId': RiyaValue.text,
      'moduleId': RiyaValue.integer,
      'title': RiyaValue.text,
      'durationSeconds': RiyaValue.integer,
      'threshold': RiyaValue.integer,
      'day': RiyaValue.date,
    },
    required: ['courseId', 'moduleId', 'title', 'durationSeconds'],
    write: true,
  ),
  RiyaCapability(
    'learning.lecture.edit',
    'Edit a lecture',
    '/learning',
    {
      'courseId': RiyaValue.text,
      'lectureId': RiyaValue.integer,
      'title': RiyaValue.text,
      'description': RiyaValue.longText,
      'author': RiyaValue.text,
      'durationSeconds': RiyaValue.integer,
      'threshold': RiyaValue.integer,
    },
    required: ['courseId', 'lectureId'],
    write: true,
  ),
  RiyaCapability(
    'learning.lecture.delete',
    'Delete a lecture',
    '/learning',
    {'courseId': RiyaValue.text, 'lectureId': RiyaValue.integer},
    required: ['courseId', 'lectureId'],
    write: true,
  ),
  RiyaCapability(
    'learning.select',
    'Select a lecture',
    '/learning',
    {
      'courseId': RiyaValue.text,
      'lectureId': RiyaValue.integer,
      'play': RiyaValue.boolean,
    },
    required: ['courseId', 'lectureId'],
    write: true,
  ),
  RiyaCapability(
    'learning.link',
    'Link an activity to a lecture',
    '/learning',
    {
      'courseId': RiyaValue.text,
      'moduleId': RiyaValue.integer,
      'lectureId': RiyaValue.integer,
      'taskId': RiyaValue.integer,
      'day': RiyaValue.date,
    },
    required: ['courseId', 'moduleId', 'lectureId', 'taskId'],
    write: true,
  ),
];

class RiyaLearningActions {
  RiyaLearningActions(this.notifier, this.read, this.clock, {this.db});
  final AppDatabase? db;
  final LearningHubNotifier notifier;
  final LearningHubState Function() read;
  final DateTime Function() clock;
  static String courseId(String request) =>
      'riya_${sha256.convert(utf8.encode(request)).toString().substring(0, 16)}';
  static int moduleId(String request) =>
      int.parse(
        sha256.convert(utf8.encode(request)).toString().substring(0, 7),
        radix: 16,
      ) +
      1;
  String _identity(RiyaCommand c) =>
      c.executionRequestId ??
      (throw StateError('A durable request identity is required'));
  Course _course(String id) =>
      read().courses.where((c) => c.id == id).firstOrNull ??
      (throw StateError('This course no longer exists'));
  CourseModule _module(Course course, int id) =>
      course.modules.where((m) => m.id == id).firstOrNull ??
      (throw StateError('This module no longer exists in the selected course'));
  Lecture _lecture(Course course, int id) =>
      course.modules
          .expand((m) => m.lectures)
          .where((l) => l.id == id)
          .firstOrNull ??
      (throw StateError(
        'This lecture no longer exists in the selected course',
      ));
  void _policy(Map<String, dynamic> a) {
    if (a.containsKey('threshold') && ![50, 100].contains(a['threshold'])) {
      throw ArgumentError('Choose 50% or 100% completion policy');
    }
    if ((a['durationSeconds'] as int? ?? 1) > 86400) {
      throw ArgumentError('Use a lecture duration of up to 24 hours');
    }
    if ((a['dailyMinutes'] as int? ?? 1) > 1440) {
      throw ArgumentError('Use a daily pace of up to 1440 minutes');
    }
  }

  Future<RiyaResult> run(RiyaCommand command) async {
    await notifier.ready;
    final a = command.arguments;
    _policy(a);
    if (command.id == 'learning.course.create') {
      final id = courseId(_identity(command));
      await notifier.addCourse(
        Course(
          id: id,
          title: a['title'],
          description: a['description'] ?? '',
          modules: [],
        ),
      );
      return RiyaResult(
        'Course saved: ${a['title']} ($id). Add a module when ready.',
        '/learning',
        learningCourseId: id,
      );
    }
    final course = _course(a['courseId']);
    final offset = a['offset'] as int? ?? 0;
    switch (command.id) {
      case 'learning.modules':
        final rows = course.modules.skip(offset).take(4).toList();
        return RiyaResult(
          'Modules · ${course.title}:\n${rows.isEmpty ? 'No modules yet.' : rows.take(3).map((m) => '#${m.id} ${m.title}: ${m.completedCount}/${m.lectures.length} completed').join('\n')}',
          '/learning',
          learningCourseId: course.id,
          options: [if (rows.length > 3) 'More modules in course ${course.id}'],
        );
      case 'learning.lectures':
        final module = _module(course, a['moduleId']);
        final rows = module.lectures.skip(offset).take(4).toList();
        return RiyaResult(
          'Lectures · ${course.title} / ${module.title}:\n${rows.isEmpty ? 'No lectures yet.' : rows.take(3).map((l) => '#${l.id} ${l.title}: ${l.isCompleted ? 'completed' : '${l.studyProgressPercent}% study time'}').join('\n')}',
          '/learning',
          learningCourseId: course.id,
          learningModuleId: module.id,
          options: [
            if (rows.length > 3)
              'More lectures in module ${module.id} in course ${course.id}',
          ],
        );
      case 'learning.course.edit':
        if (a.keys.every((k) => k == 'courseId')) {
          throw ArgumentError('Choose a course field to change');
        }
        if (a['clearUrl'] == true && a.containsKey('sourceUrl') ||
            a['clearDate'] == true && a.containsKey('targetDate')) {
          throw ArgumentError('Choose a new value or clear it');
        }
        final url = a['clearUrl'] == true
            ? null
            : a['sourceUrl'] ?? course.sourceUrl;
        if (url != null) {
          final uri = Uri.tryParse(url);
          if (uri == null ||
              !['http', 'https'].contains(uri.scheme) ||
              uri.host.isEmpty) {
            throw ArgumentError('Use an http or https course URL');
          }
        }
        await notifier.updateCourse(
          course.copyWith(
            title: a['title'],
            description: a['description'],
            author: a['author'],
            category: a['category'],
            sourceUrl: url,
            targetCompletionDate: a['clearDate'] == true
                ? null
                : a.containsKey('targetDate')
                ? DateTime.parse(a['targetDate']).toLocal()
                : course.targetCompletionDate,
            targetMinutesPerDay: a['dailyMinutes'],
          ),
        );
        return RiyaResult(
          'Course ${course.id} updated.',
          '/learning',
          learningCourseId: course.id,
        );
      case 'learning.course.delete':
        if (read().courses.length <= 1) {
          throw StateError(
            'Keep at least one course, or create another before deleting this one',
          );
        }
        await notifier.deleteCourse(course.id);
        return RiyaResult(
          'Course ${course.id} deleted. Recorded timer history is kept.',
          '/learning',
        );
      case 'learning.module.create':
        final request = _identity(command), id = moduleId(_identity(command));
        if (course.modules.any((m) => m.id == id)) {
          throw StateError(
            'A module already uses this identity; verify the original request',
          );
        }
        await notifier.addModule(
          course.id,
          CourseModule(
            id: id,
            title: a['title'],
            description: a['description'] ?? '',
            lectures: [],
            originRequestId: request,
          ),
        );
        return RiyaResult(
          'Module #$id saved in ${course.title}.',
          '/learning',
          learningCourseId: course.id,
          learningModuleId: id,
        );
      case 'learning.module.edit':
        final module = _module(course, a['moduleId']);
        if (a.keys.every((k) => k == 'courseId' || k == 'moduleId')) {
          throw ArgumentError('Choose a module field to change');
        }
        await notifier.updateModule(
          course.id,
          module.copyWith(title: a['title'], description: a['description']),
        );
        return RiyaResult(
          'Module #${module.id} updated in ${course.title}.',
          '/learning',
          learningCourseId: course.id,
          learningModuleId: module.id,
        );
      case 'learning.module.delete':
        final module = _module(course, a['moduleId']);
        await notifier.deleteModule(course.id, module.id);
        return RiyaResult(
          'Module #${module.id} and its lectures removed from ${course.title}. Recorded timer history is kept.',
          '/learning',
        );
      case 'learning.lecture.create':
      case 'learning.link':
        final lecture = await notifier.saveLectureActivity(
          requestId: _identity(command),
          courseId: course.id,
          moduleId: a['moduleId'],
          plannedDate: a['day'] == null
              ? clock()
              : DateTime.parse(a['day']).toLocal(),
          taskId: a['taskId'],
          existingLectureId: a['lectureId'],
          title: a['title'],
          durationSeconds: a['durationSeconds'],
          thresholdPercent: a['threshold'] ?? 100,
        );
        return RiyaResult(
          'Lecture #${lecture.id} saved in ${course.title}. Study time governs completion.',
          '/learning',
          learningCourseId: course.id,
          learningLectureId: lecture.id,
        );
      case 'learning.lecture.edit':
        final lecture = _lecture(course, a['lectureId']);
        if (a.keys.every((k) => k == 'courseId' || k == 'lectureId')) {
          throw ArgumentError('Choose a lecture field to change');
        }
        await notifier.updateLecture(
          course.id,
          lecture.copyWith(
            title: a['title'],
            description: a['description'],
            author: a['author'],
            durationSeconds: a['durationSeconds'],
            completionThresholdPercent: a['threshold'],
          ),
        );
        return RiyaResult(
          'Lecture #${lecture.id} updated. Existing study evidence and completion are preserved.',
          '/learning',
          learningCourseId: course.id,
          learningLectureId: lecture.id,
        );
      case 'learning.lecture.delete':
        final lecture = _lecture(course, a['lectureId']);
        await notifier.deleteLecture(course.id, lecture.id);
        return RiyaResult(
          'Lecture #${lecture.id} removed from ${course.title}. Recorded timer history is kept.',
          '/learning',
        );
      case 'learning.select':
        final lecture = _lecture(course, a['lectureId']);
        if (read().activeCourseId != course.id) {
          notifier.switchCourse(course.id);
        }
        notifier.selectLecture(lecture.id, autoPlay: a['play'] == true);
        await notifier.settled;
        return RiyaResult(
          'Selected ${lecture.title} in ${course.title}${a['play'] == true ? ' and started study time' : ''}.',
          '/learning',
          learningCourseId: course.id,
          learningLectureId: lecture.id,
        );
      default:
        throw UnsupportedError('Unsupported Learning command');
    }
  }

  Future<RiyaResult?> verify(RiyaCommand command) async {
    await notifier.ready;
    final a = command.arguments;
    final request = command.executionRequestId;
    final courses = read().courses;
    if (command.id == 'learning.course.create') {
      if (request == null || !courses.any((c) => c.id == courseId(request))) {
        return null;
      }
      return const RiyaResult(
        'Course creation verified. Newer edits were kept.',
        '/learning',
      );
    }
    final course = courses.where((c) => c.id == a['courseId']).firstOrNull;
    if (command.id == 'learning.course.delete') {
      return course == null
          ? const RiyaResult('Course removal verified.', '/learning')
          : null;
    }
    if (course == null) return null;
    bool fields(
      Map<String, dynamic> current, {
      Map<String, String> aliases = const {},
    }) {
      for (final entry in a.entries) {
        if ({'courseId', 'moduleId', 'lectureId'}.contains(entry.key)) continue;
        final key = aliases[entry.key] ?? entry.key;
        if (entry.key == 'clearUrl') {
          if (entry.value == true && current['sourceUrl'] != null) return false;
          continue;
        }
        if (entry.key == 'clearDate') {
          if (entry.value == true && current['targetCompletionDate'] != null) {
            return false;
          }
          continue;
        }
        final actual = current[key];
        if (entry.key == 'targetDate') {
          if (actual == null ||
              !DateTime.parse(
                actual,
              ).isAtSameMomentAs(DateTime.parse(entry.value))) {
            return false;
          }
        } else if (actual != entry.value) {
          return false;
        }
      }
      return true;
    }

    if (command.id == 'learning.course.edit') {
      return fields(
            course.toJson(),
            aliases: {
              'dailyMinutes': 'targetMinutesPerDay',
              'targetDate': 'targetCompletionDate',
            },
          )
          ? const RiyaResult('Course edits verified.', '/learning')
          : null;
    }
    final module = course.modules
        .where((m) => m.id == a['moduleId'])
        .firstOrNull;
    if (command.id == 'learning.module.create') {
      final created = course.modules
          .where((m) => m.originRequestId == request)
          .firstOrNull;
      return created == null
          ? null
          : RiyaResult(
              'Module #${created.id} creation verified. Newer edits were kept.',
              '/learning',
            );
    }
    if (command.id == 'learning.module.delete') {
      return module == null
          ? const RiyaResult('Module removal verified.', '/learning')
          : null;
    }
    if (command.id == 'learning.module.edit') {
      return module != null && fields(module.toJson())
          ? const RiyaResult('Module edits verified.', '/learning')
          : null;
    }
    final lecture = course.modules
        .expand((m) => m.lectures)
        .where((l) => l.id == a['lectureId'])
        .firstOrNull;
    if (command.id == 'learning.lecture.create') {
      final created = module?.lectures
          .where((l) => l.originRequestId == request)
          .firstOrNull;
      return created == null
          ? null
          : RiyaResult(
              'Lecture #${created.id} creation verified. Newer edits were kept.',
              '/learning',
            );
    }
    if (command.id == 'learning.lecture.delete') {
      return lecture == null
          ? const RiyaResult('Lecture removal verified.', '/learning')
          : null;
    }
    if (command.id == 'learning.lecture.edit') {
      return lecture != null &&
              fields(
                lecture.toJson(),
                aliases: {'threshold': 'completionThresholdPercent'},
              )
          ? const RiyaResult('Lecture edits verified.', '/learning')
          : null;
    }
    if (command.id == 'learning.link') {
      final task = await db?.taskDao.getTaskById(a['taskId']);
      return task?.learningCourseId == course.id &&
              task?.learningLectureId == a['lectureId']
          ? const RiyaResult('Activity lecture link verified.', '/learning')
          : null;
    }
    if (command.id == 'learning.select' &&
        read().activeCourseId == course.id &&
        read().activeLectureId == a['lectureId'] &&
        read().isPlaying == (a['play'] == true)) {
      return const RiyaResult('Lecture selection verified.', '/learning');
    }
    return null;
  }
}
