import '../database/app_database.dart';
import 'riya_capabilities.dart';
import 'riya_intents.dart';

class RiyaLearningIntents {
  RiyaLearningIntents(this.db);
  final AppDatabase db;
  final _offsets = <String, int>{};
  void cancel() => _offsets.clear();
  Future<RiyaResolution?> resolve(String prompt) async {
    final text = prompt.trim();
    final create = RegExp(
      r'^(?:create|add|banao) (?:a )?course (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (create != null) {
      return RiyaResolution(
        command: RiyaCommand('learning.course.create', {
          'title': create.group(1)!.trim(),
        }),
      );
    }
    final courseAction = RegExp(
      r'^(rename|delete|remove) course (.+?)(?: to (.+))?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (courseAction != null) {
      final course = await _course(courseAction.group(2)!);
      if (course.command == null) return course;
      final id = course.command!.arguments['courseId'];
      if (courseAction.group(1)!.toLowerCase() == 'rename') {
        if (courseAction.group(3) == null) {
          return const RiyaResolution(
            message:
                'What should the course be called? Use “Rename course name to new name”.',
          );
        }
        return RiyaResolution(
          command: RiyaCommand('learning.course.edit', {
            'courseId': id,
            'title': courseAction.group(3)!.trim(),
          }),
        );
      }
      return RiyaResolution(
        command: RiyaCommand('learning.course.delete', {'courseId': id}),
      );
    }
    final modules = RegExp(
      r'^(show|list|more) modules in course (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (modules != null) {
      final target = await _course(modules.group(2)!);
      if (target.command == null) return target;
      final id = target.command!.arguments['courseId'];
      final key = 'modules:$id';
      if (modules.group(1)!.toLowerCase() == 'more' &&
          !_offsets.containsKey(key)) {
        return const RiyaResolution(
          message: 'Show that course’s modules first.',
        );
      }
      final offset = modules.group(1)!.toLowerCase() == 'more'
          ? (_offsets[key] ?? 0) + 3
          : 0;
      _offsets[key] = offset;
      return RiyaResolution(
        command: RiyaCommand('learning.modules', {
          'courseId': id,
          'offset': offset,
        }),
      );
    }
    final moduleCreate = RegExp(
      r'^(?:create|add) module (.+) in course (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (moduleCreate != null) {
      return _withCourse(moduleCreate.group(2)!, 'learning.module.create', {
        'title': moduleCreate.group(1)!.trim(),
      });
    }
    final moduleAction = RegExp(
      r'^(rename|delete|remove) module #(\d+) in course (.+?)(?: to (.+))?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (moduleAction != null) {
      if (moduleAction.group(1)!.toLowerCase() == 'rename' &&
          moduleAction.group(4) == null) {
        return const RiyaResolution(
          message: 'Include the new module title after “to”.',
        );
      }
      return _withCourse(
        moduleAction.group(3)!,
        moduleAction.group(1)!.toLowerCase() == 'rename'
            ? 'learning.module.edit'
            : 'learning.module.delete',
        {
          'moduleId': int.parse(moduleAction.group(2)!),
          if (moduleAction.group(4) != null)
            'title': moduleAction.group(4)!.trim(),
        },
      );
    }
    final lectures = RegExp(
      r'^(show|list|more) lectures in module #(\d+) in course (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (lectures != null) {
      final target = await _course(lectures.group(3)!);
      if (target.command == null) return target;
      final id = target.command!.arguments['courseId'];
      final module = int.parse(lectures.group(2)!);
      final key = 'lectures:$id:$module';
      if (lectures.group(1)!.toLowerCase() == 'more' &&
          !_offsets.containsKey(key)) {
        return const RiyaResolution(
          message: 'Show that module’s lectures first.',
        );
      }
      final offset = lectures.group(1)!.toLowerCase() == 'more'
          ? (_offsets[key] ?? 0) + 3
          : 0;
      _offsets[key] = offset;
      return RiyaResolution(
        command: RiyaCommand('learning.lectures', {
          'courseId': id,
          'moduleId': module,
          'offset': offset,
        }),
      );
    }
    final link = RegExp(
      r'^link activity #(\d+) to lecture #(\d+) in module #(\d+) in course (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (link != null) {
      return _withCourse(link.group(4)!, 'learning.link', {
        'taskId': int.parse(link.group(1)!),
        'lectureId': int.parse(link.group(2)!),
        'moduleId': int.parse(link.group(3)!),
      });
    }
    final lectureCreate = RegExp(
      r'^(?:create|add) lecture (.+) in module #(\d+) in course (.+) duration (\d+) minutes$',
      caseSensitive: false,
    ).firstMatch(text);
    if (lectureCreate != null) {
      return _withCourse(lectureCreate.group(3)!, 'learning.lecture.create', {
        'title': lectureCreate.group(1)!.trim(),
        'moduleId': int.parse(lectureCreate.group(2)!),
        'durationSeconds': int.parse(lectureCreate.group(4)!) * 60,
      });
    }
    final lectureAction = RegExp(
      r'^(delete|remove|play|select) lecture #(\d+) in course (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (lectureAction != null) {
      return _withCourse(
        lectureAction.group(3)!,
        {'delete', 'remove'}.contains(lectureAction.group(1)!.toLowerCase())
            ? 'learning.lecture.delete'
            : 'learning.select',
        {
          'lectureId': int.parse(lectureAction.group(2)!),
          if (!{
            'delete',
            'remove',
          }.contains(lectureAction.group(1)!.toLowerCase()))
            'play': lectureAction.group(1)!.toLowerCase() == 'play',
        },
      );
    }
    final editLecture = RegExp(
      r'^edit lecture #(\d+) in course (.+?) (title|duration|policy) to (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (editLecture != null) {
      final field = editLecture.group(3)!.toLowerCase();
      final value = editLecture.group(4)!.trim();
      final number = int.tryParse(
        value.replaceAll(RegExp(r'\s*(?:seconds|%)$'), ''),
      );
      if (field != 'title' && number == null) {
        return const RiyaResolution(
          message:
              'Use duration in seconds or a completion policy of 50 or 100%.',
        );
      }
      return _withCourse(editLecture.group(2)!, 'learning.lecture.edit', {
        'lectureId': int.parse(editLecture.group(1)!),
        switch (field) {
          'title' => 'title',
          'duration' => 'durationSeconds',
          _ => 'threshold',
        }: field == 'title'
            ? value
            : number,
      });
    }
    return null;
  }

  Future<RiyaResolution> _withCourse(
    String reference,
    String command,
    Map<String, dynamic> arguments,
  ) async {
    final target = await _course(reference);
    if (target.command == null) return target;
    return RiyaResolution(
      command: RiyaCommand(command, {
        ...arguments,
        'courseId': target.command!.arguments['courseId'],
      }),
    );
  }

  Future<RiyaResolution> _course(String reference) async {
    final query = reference.trim().replaceFirst(RegExp(r'^#'), '');
    final rows = await db.courseDao.getAllCourses();
    final exact = rows.where((c) => c.id == query).toList();
    final found = exact.isNotEmpty
        ? exact
        : rows
              .where((c) => c.title.toLowerCase() == query.toLowerCase())
              .toList();
    if (found.length != 1) {
      return RiyaResolution(
        message: found.isEmpty
            ? 'That course was not found. Show courses to choose its title or ID.'
            : 'Several courses use that title. Include the ID:\n${found.take(3).map((c) => '${c.title} (${c.id})').join('\n')}',
      );
    }
    return RiyaResolution(
      command: RiyaCommand('learning.modules', {'courseId': found.single.id}),
    );
  }
}
