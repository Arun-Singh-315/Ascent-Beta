import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/learning_hub/learning_hub_models.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../study_plan/add_course_sheet.dart';
import '../study_plan/module_lecture_editor_sheets.dart';

class AddLectureActivitySheet extends ConsumerStatefulWidget {
  const AddLectureActivitySheet({
    super.key,
    this.task,
    this.title,
    this.minutes,
  });
  final Task? task;
  final String? title;
  final int? minutes;
  static Future<bool> show(
    BuildContext context, {
    Task? task,
    String? title,
    int? minutes,
  }) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) =>
            AddLectureActivitySheet(task: task, title: title, minutes: minutes),
      ) ??
      false;
  @override
  ConsumerState<AddLectureActivitySheet> createState() =>
      _AddLectureActivitySheetState();
}

class _AddLectureActivitySheetState
    extends ConsumerState<AddLectureActivitySheet> {
  late final _title = TextEditingController(
    text: widget.title ?? widget.task?.title ?? '',
  );
  late final _minutes = TextEditingController(
    text: '${widget.minutes ?? widget.task?.estimatedMinutes ?? 30}',
  );
  final _requestId =
      'lecture-activity:${DateTime.now().microsecondsSinceEpoch}';
  String? _courseId;
  int? _moduleId, _lectureId;
  bool _existing = false, _saving = false;
  int _threshold = 100;
  late DateTime _date = widget.task?.plannedDate ?? DateTime.now();
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _save(Course? course, CourseModule? module) async {
    if (_saving) return;
    if (course == null || module == null || (_existing && _lectureId == null)) {
      setState(() => _error = 'Choose a course, module, and lecture.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final tracking = ref.read(timeTrackingProvider);
      if (widget.task != null &&
          tracking.activeSession?.linkedTaskId == widget.task!.id &&
          tracking.isRunning) {
        await ref.read(timeTrackingProvider.notifier).pauseSession();
      }
      await ref
          .read(learningHubProvider.notifier)
          .saveLectureActivity(
            requestId: _requestId,
            courseId: course.id,
            moduleId: module.id,
            plannedDate: _date,
            existingLectureId: _existing ? _lectureId : null,
            taskId: widget.task?.id,
            title: _title.text,
            durationSeconds: (int.tryParse(_minutes.text) ?? 0) * 60,
            thresholdPercent: _threshold,
          );
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is StateError
              ? error.message.toString()
              : error is ArgumentError
              ? error.message.toString()
              : 'Could not save the lecture. Your choices are still here.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = ref.watch(learningHubProvider);
    final course = hub.courses.where((c) => c.id == _courseId).firstOrNull;
    final module = course?.modules.where((m) => m.id == _moduleId).firstOrNull;
    final lectures = module?.lectures ?? <Lecture>[];
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.task == null
                    ? 'Plan a lecture'
                    : 'Make this activity a lecture',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose where it belongs. Learning and Today share one lecture and one completion policy.',
              ),
              if (widget.task != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Existing timer history is kept as engagement. Completion requires new lecture study time.',
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('course:$_courseId'),
                initialValue: course?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Course'),
                items: hub.courses
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.title, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (id) => setState(() {
                        _courseId = id;
                        _moduleId = null;
                        _lectureId = null;
                      }),
              ),
              TextButton.icon(
                onPressed: _saving ? null : () => AddCourseSheet.show(context),
                icon: const Icon(Icons.add),
                label: const Text('Add course'),
              ),
              if (course != null) ...[
                DropdownButtonFormField<int>(
                  key: ValueKey('module:${course.id}:$_moduleId'),
                  initialValue: module?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Module'),
                  items: course.modules
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.title, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (id) => setState(() {
                          _moduleId = id;
                          _lectureId = null;
                        }),
                ),
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => showAddModuleSheet(
                          context,
                          ref,
                          course.id,
                          nextModuleId:
                              course.modules.fold<int>(
                                0,
                                (n, m) => m.id > n ? m.id : n,
                              ) +
                              1,
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add module'),
                ),
              ],
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Create lecture'),
                    selected: !_existing,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _existing = false),
                  ),
                  ChoiceChip(
                    label: const Text('Link existing'),
                    selected: _existing,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _existing = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_existing)
                DropdownButtonFormField<int>(
                  key: ValueKey(
                    'lecture:${course?.id}:${module?.id}:$_lectureId',
                  ),
                  initialValue: lectures.any((l) => l.id == _lectureId)
                      ? _lectureId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lecture'),
                  items: lectures
                      .map(
                        (l) => DropdownMenuItem(
                          value: l.id,
                          child: Text(l.title, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (id) => setState(() => _lectureId = id),
                ),
              if (!_existing) ...[
                TextField(
                  controller: _title,
                  enabled: !_saving,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: 'Lecture title'),
                ),
                TextField(
                  controller: _minutes,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration · minutes',
                    helperText: '1–1440 minutes',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final percent in [100, 50])
                      ChoiceChip(
                        label: Text(
                          percent == 100 ? 'Full study time' : 'At least half',
                        ),
                        selected: _threshold == percent,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _threshold = percent),
                      ),
                  ],
                ),
              ],
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final day = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (day != null && mounted) setState(() => _date = day);
                      },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  'Planned · ${_date.day}/${_date.month}/${_date.year}',
                ),
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: context.glass.coral)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : () => _save(course, module),
                  child: Text(_saving ? 'Saving…' : 'Save lecture activity'),
                ),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
