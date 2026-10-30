import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/date_range_calendar.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/learning_hub/learning_hub_models.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../challenge_providers.dart';

class ChallengeCreateSheet extends ConsumerStatefulWidget {
  const ChallengeCreateSheet({super.key, this.linkedPromise});

  final Thought? linkedPromise;

  static Future<void> show(BuildContext context, {Thought? linkedPromise}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppPalette.transparent,
        builder: (_) => ChallengeCreateSheet(linkedPromise: linkedPromise),
      );

  @override
  ConsumerState<ChallengeCreateSheet> createState() =>
      _ChallengeCreateSheetState();
}

class _ChallengeCreateSheetState extends ConsumerState<ChallengeCreateSheet> {
  final _titleController = TextEditingController();
  final _daysController = TextEditingController(text: '20');
  final _dailyMinutesController = TextEditingController(text: '45');
  String _type = 'learning';
  String? _sourceId;
  List<Task> _tasks = const [];
  bool _tasksLoaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.linkedPromise != null) {
      final content = widget.linkedPromise!.content;
      _titleController.text = content.length > 200
          ? content.substring(0, 200)
          : content;
      _loadPromiseDuration();
    }
    _loadTasks();
  }

  Future<void> _loadPromiseDuration() async {
    final task = await ref
        .read(taskDaoProvider)
        .getTaskLinkedToThought(widget.linkedPromise!.id);
    final match = RegExp(
      r'promise_duration_days:(\d+)',
    ).firstMatch(task?.notes ?? '');
    final duration = int.tryParse(match?.group(1) ?? '');
    if (mounted && duration != null) {
      setState(() => _daysController.text = duration.toString());
    }
  }

  Future<void> _loadTasks() async {
    final tasks = await ref.read(taskDaoProvider).watchAllTasks().first;
    if (!mounted) return;
    setState(() {
      _tasks = tasks
          .where(
            (task) =>
                task.estimatedMinutes != null &&
                task.estimatedMinutes! > 0 &&
                task.actualCompletedDate == null,
          )
          .toList(growable: false);
      _tasksLoaded = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _daysController.dispose();
    _dailyMinutesController.dispose();
    super.dispose();
  }

  String _sourceTitle(String id, List<Course> courses) {
    if (_type == 'activity') {
      for (final task in _tasks) {
        if (task.id.toString() == id) return task.title;
      }
    } else {
      for (final course in courses) {
        if (course.id == id) return course.title;
      }
    }
    return '';
  }

  double _learningTarget(Course? course) {
    if (course == null) return 0;
    var seconds = 0.0;
    for (final module in course.modules) {
      for (final lecture in module.lectures.where(
        (item) => !item.isCompleted,
      )) {
        seconds += lecture.durationSeconds.toDouble();
      }
    }
    return seconds / 60;
  }

  Future<void> _create(Course? selectedCourse, String? selectedSourceId) async {
    if (_saving) return;
    final days = int.tryParse(_daysController.text.trim());
    final dailyMinutes = int.tryParse(_dailyMinutesController.text.trim());
    final courses = ref.read(learningHubProvider).courses;
    if (days == null || days < 1 || days > 365) {
      setState(() => _error = 'Choose a duration from 1 to 365 days.');
      return;
    }
    if (selectedSourceId == null) {
      setState(() => _error = 'Choose a source to track.');
      return;
    }
    final title = _titleController.text.trim().isEmpty
        ? _sourceTitle(selectedSourceId, courses)
        : _titleController.text.trim();
    final learningTarget = _type == 'learning'
        ? _learningTarget(selectedCourse)
        : 0.0;
    if (_type == 'learning' &&
        (learningTarget <= 0 || selectedCourse == null)) {
      setState(
        () => _error = 'This course has no remaining lecture time to track.',
      );
      return;
    }
    if (_type == 'activity' &&
        (dailyMinutes == null || dailyMinutes < 1 || dailyMinutes > 1440)) {
      setState(() => _error = 'Choose a daily target from 1 to 1,440 minutes.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(challengeServiceProvider)
          .create(
            type: _type,
            title: title,
            sourceType: _type == 'learning' ? 'learning_course' : 'task',
            sourceId: selectedSourceId,
            targetTotal: _type == 'learning'
                ? learningTarget
                : (dailyMinutes! * days).toDouble(),
            dailyMinimum: _type == 'learning'
                ? learningTarget / days
                : dailyMinutes!.toDouble(),
            durationDays: days,
            linkedPromiseThoughtId: widget.linkedPromise?.id,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Challenge locked. Progress will use completed Learning or Focus records.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is StateError
              ? error.message
              : 'Could not create this challenge. Check the details and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final learning = ref.watch(learningHubProvider);
    final courses = learning.courses
        .where((course) => _learningTarget(course) > 0)
        .toList();
    final sources = _type == 'learning'
        ? courses.map((course) => course.id).toList()
        : _tasks.map((task) => task.id.toString()).toList();
    final selectedSourceId = sources.contains(_sourceId)
        ? _sourceId
        : (sources.isEmpty ? null : sources.first);
    final selectedCourse = courses
        .where((course) => course.id == selectedSourceId)
        .firstOrNull;
    final g = context.glass;
    final sourceMissing = _type == 'learning'
        ? courses.isEmpty
        : !_tasksLoaded || _tasks.isEmpty;
    final learningTarget = _learningTarget(selectedCourse);
    final durationDays = int.tryParse(_daysController.text.trim()) ?? 0;
    final startDay = DateUtils.dateOnly(DateTime.now());
    final daily = _type == 'activity'
        ? (int.tryParse(_dailyMinutesController.text.trim()) ?? 0).toDouble()
        : (durationDays > 0 ? learningTarget / durationDays : 0);

    return SafeArea(
      child: AppCard(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpace.s20,
          AppSpace.s16,
          AppSpace.s20,
          MediaQuery.viewInsetsOf(context).bottom + AppSpace.s24,
        ),
        nightDecoration: BoxDecoration(
          color: context.bgSurface,
          borderRadius: const BorderRadius.vertical(top: AppGeometry.radiusr26),
          border: Border.all(color: g.line),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: g.line,
                    borderRadius: AppGeometry.roundedr5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Set a challenge',
                style: AscentTextStyles.displaySmall.copyWith(color: g.ink),
              ),
              const SizedBox(height: 5),
              Text(
                'Choose work Ascent can verify. A checkbox alone never adds progress.',
                style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
              ),
              if (widget.linkedPromise != null) ...[
                const SizedBox(height: 12),
                AppCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.s12),
                  nightDecoration: BoxDecoration(
                    color: AppPalette.colorFFB46824.withValues(alpha: 0.1),
                    borderRadius: AppGeometry.roundedr14,
                    border: Border.all(
                      color: AppPalette.colorFFB46824.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.handshake_rounded,
                        color: AppPalette.colorFFB46824,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Linked Promise: ${widget.linkedPromise!.content}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AscentTextStyles.bodySmall.copyWith(
                            color: g.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              AscentSegmentedControl<String>(
                segments: const [
                  AscentSegment(value: 'learning', label: 'Learning'),
                  AscentSegment(value: 'activity', label: 'Activity'),
                ],
                selected: _type,
                onChanged: (value) => setState(() {
                  _type = value;
                  _sourceId = null;
                  _titleController.clear();
                }),
              ),
              const SizedBox(height: 14),
              if (sourceMissing)
                AppCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.s14),
                  nightDecoration: BoxDecoration(
                    color: g.fill,
                    borderRadius: AppGeometry.roundedr14,
                  ),
                  child: Text(
                    _type == 'learning'
                        ? 'Add a course with unfinished lectures in Learning Hub first.'
                        : _tasksLoaded
                        ? 'Add a time-bound Todo in Today first. Activity proof comes from completed Focus sessions.'
                        : 'Loading your activities…',
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: g.inkMuted,
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('challenge_source_$_type'),
                  initialValue: selectedSourceId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _type == 'learning'
                        ? 'Learning Hub course'
                        : 'Timed Todo activity',
                    border: OutlineInputBorder(
                      borderRadius: AppGeometry.roundedr12,
                    ),
                  ),
                  items: sources
                      .map(
                        (id) => DropdownMenuItem(
                          value: id,
                          child: Text(
                            _sourceTitle(id, courses),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) => setState(() {
                    _sourceId = id;
                    if (id != null) {
                      _titleController.text = _sourceTitle(id, courses);
                    }
                  }),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Challenge name',
                  border: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                  ),
                ),
              ),
              TextField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Duration',
                  suffixText: 'days',
                  border: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                  ),
                ),
              ),
              if (_type == 'activity') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _dailyMinutesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Daily verified Focus target',
                    suffixText: 'minutes',
                    border: OutlineInputBorder(
                      borderRadius: AppGeometry.roundedr12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              AppCard(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.s14),
                nightDecoration: BoxDecoration(
                  color: g.fill,
                  borderRadius: AppGeometry.roundedr14,
                  border: Border.all(color: g.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR PLAN',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: g.inkMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _type == 'learning'
                          ? '${learningTarget.ceil()} min across $durationDays days · about ${daily.ceil()} min/day'
                          : '${daily * durationDays.toDouble()} min total · $daily min/day',
                      style: AscentTextStyles.labelMedium
                          .copyWith(color: g.ink)
                          .merge(AppTypeRoles.typeRole2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Only completed lectures or completed Focus sessions count.',
                      style: AscentTextStyles.captionMedium.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (durationDays >= 1 && durationDays <= 365) ...[
                const SizedBox(height: 14),
                DateRangeCalendar(
                  start: startDay,
                  end: DateTime(
                    startDay.year,
                    startDay.month,
                    startDay.day + durationDays - 1,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: AppPalette.redAccent,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || sourceMissing
                      ? null
                      : () => _create(selectedCourse, selectedSourceId),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline_rounded),
                  label: Text(_saving ? 'Saving…' : 'Lock challenge'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
