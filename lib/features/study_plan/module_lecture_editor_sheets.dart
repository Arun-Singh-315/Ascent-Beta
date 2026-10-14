import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/color_tokens.dart';
import '../../core/learning_hub/learning_hub_models.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../shared/widgets/ascent_button.dart';

/// Bottom sheet dialog to add a new module to a course.
Future<void> showAddModuleSheet(
  BuildContext context,
  WidgetRef ref,
  String courseId, {
  required int nextModuleId,
}) async {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final durationController = TextEditingController(text: '1.5');

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppGeometry.radiusr24),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.s20,
          AppSpace.s20,
          AppSpace.s20,
          AppSpace.s20 + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add New Module',
                    style: AppTypography.plusJakartaSans18W70045(
                      color: context.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Module Title',
                  hintText: 'e.g. Module 3: Advanced Microservices',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Key concepts covered in this chapter/module...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Estimated Duration (Hours)',
                  hintText: '1.5',
                ),
              ),
              const SizedBox(height: 20),
              AscentButton.primary(
                label: 'Create Module',
                icon: Icons.add_rounded,
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;
                  HapticFeedback.mediumImpact();

                  final hours =
                      double.tryParse(durationController.text.trim()) ?? 1.0;
                  final newModule = CourseModule(
                    id: nextModuleId,
                    title: title,
                    description: descController.text.trim(),
                    durationHours: hours,
                    lectures: [
                      Lecture(
                        id: DateTime.now().millisecondsSinceEpoch % 100000 + 1,
                        moduleId: nextModuleId,
                        moduleTitle: title,
                        title: 'Lecture 1: Introduction to $title',
                        durationSeconds: 900,
                      ),
                    ],
                  );

                  final saved = await _saveLearningEditor(
                    ctx,
                    () => ref
                        .read(learningHubProvider.notifier)
                        .addModule(courseId, newModule),
                  );
                  if (!saved || !ctx.mounted || !context.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Module "$title" added successfully!'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Bottom sheet dialog to edit or delete an existing module.
Future<void> showEditModuleSheet(
  BuildContext context,
  WidgetRef ref,
  String courseId,
  CourseModule module,
) async {
  final titleController = TextEditingController(text: module.title);
  final descController = TextEditingController(text: module.description);
  final durationController = TextEditingController(
    text: module.durationHours.toString(),
  );

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppGeometry.radiusr24),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.s20,
          AppSpace.s20,
          AppSpace.s20,
          AppSpace.s20 + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Module ${module.id}',
                    style: AppTypography.plusJakartaSans18W70045(
                      color: context.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Module Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Estimated Duration (Hours)',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AscentButton.destructive(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        final saved = await _saveLearningEditor(
                          ctx,
                          () => ref
                              .read(learningHubProvider.notifier)
                              .deleteModule(courseId, module.id),
                        );
                        if (!saved || !ctx.mounted || !context.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Module "${module.title}" deleted'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AscentButton.primary(
                      label: 'Save Changes',
                      icon: Icons.check_rounded,
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;
                        HapticFeedback.lightImpact();

                        final hours =
                            double.tryParse(durationController.text.trim()) ??
                            module.durationHours;
                        final updated = module.copyWith(
                          title: title,
                          description: descController.text.trim(),
                          durationHours: hours,
                        );

                        final saved = await _saveLearningEditor(
                          ctx,
                          () => ref
                              .read(learningHubProvider.notifier)
                              .updateModule(courseId, updated),
                        );
                        if (!saved || !ctx.mounted || !context.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Module updated!'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Bottom sheet dialog to add a new lecture/chapter to a course.
Future<void> showAddLectureSheet(
  BuildContext context,
  WidgetRef ref,
  String courseId,
  List<CourseModule> modules, {
  int? defaultModuleId,
}) async {
  if (modules.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Please add a module first')));
    return;
  }

  int selectedModuleId = defaultModuleId ?? modules.first.id;
  final titleController = TextEditingController();
  final authorController = TextEditingController(text: 'Instructor');
  final durationMinsController = TextEditingController(text: '20');

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppGeometry.radiusr24),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.s20,
              AppSpace.s20,
              AppSpace.s20,
              AppSpace.s20 + bottomInset,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Lecture / Chapter',
                        style: AppTypography.plusJakartaSans18W70045(
                          color: context.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Module selector
                  Text(
                    'Assign to Module:',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: context.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s12,
                    ),
                    nightDecoration: BoxDecoration(
                      color: context.bgBase,
                      borderRadius: AppGeometry.roundedr12,
                      border: Border.all(color: context.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedModuleId,
                        isExpanded: true,
                        items: modules.map((m) {
                          return DropdownMenuItem<int>(
                            value: m.id,
                            child: Text(
                              'Module ${m.id}: ${m.title}',
                              style: AscentTextStyles.bodyMedium.copyWith(
                                color: context.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedModuleId = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Lecture Title',
                      hintText:
                          'e.g. Dependency Injection & Inversion of Control',
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: durationMinsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Duration (Minutes)',
                            hintText: '20',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: authorController,
                          decoration: const InputDecoration(
                            labelText: 'Author / Channel',
                            hintText: 'Instructor',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  AscentButton.primary(
                    label: 'Add Lecture',
                    icon: Icons.add_rounded,
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      HapticFeedback.mediumImpact();

                      final mins =
                          int.tryParse(durationMinsController.text.trim()) ??
                          20;
                      final mod = modules.firstWhere(
                        (m) => m.id == selectedModuleId,
                        orElse: () => modules.first,
                      );

                      final newLecture = Lecture(
                        id: DateTime.now().millisecondsSinceEpoch % 100000 + 1,
                        moduleId: selectedModuleId,
                        moduleTitle: mod.title,
                        title: title,
                        author: authorController.text.trim().isEmpty
                            ? 'Instructor'
                            : authorController.text.trim(),
                        durationSeconds: mins * 60,
                      );

                      final saved = await _saveLearningEditor(
                        ctx,
                        () => ref
                            .read(learningHubProvider.notifier)
                            .addLecture(courseId, selectedModuleId, newLecture),
                      );
                      if (!saved || !ctx.mounted || !context.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lecture "$title" added ($mins mins)'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Bottom sheet dialog to edit or delete a lecture.
Future<void> showEditLectureSheet(
  BuildContext context,
  WidgetRef ref,
  String courseId,
  Lecture lecture,
) async {
  final titleController = TextEditingController(text: lecture.title);
  final authorController = TextEditingController(text: lecture.author);
  final durationMinsController = TextEditingController(
    text: (lecture.durationSeconds ~/ 60).toString(),
  );
  int completionThreshold = lecture.completionThresholdPercent;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppGeometry.radiusr24),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.s20,
              AppSpace.s20,
              AppSpace.s20,
              AppSpace.s20 + bottomInset,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Lecture ${lecture.id}',
                        style: AppTypography.plusJakartaSans18W70045(
                          color: context.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Lecture Title',
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: durationMinsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Duration (Minutes)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: authorController,
                          decoration: const InputDecoration(
                            labelText: 'Author / Channel',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Completion requires study time',
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 100, label: Text('Full duration')),
                      ButtonSegment(value: 50, label: Text('At least half')),
                    ],
                    selected: {completionThreshold},
                    onSelectionChanged: (values) => setModalState(
                      () => completionThreshold = values.single,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The player unlocks completion after the selected study target. Seeking does not earn credit.',
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: context.textMuted,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AscentButton.destructive(
                          label: 'Delete',
                          icon: Icons.delete_outline_rounded,
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final saved = await _saveLearningEditor(
                              ctx,
                              () => ref
                                  .read(learningHubProvider.notifier)
                                  .deleteLecture(courseId, lecture.id),
                            );
                            if (!saved || !ctx.mounted || !context.mounted) {
                              return;
                            }
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Lecture "${lecture.title}" deleted',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AscentButton.primary(
                          label: 'Save Changes',
                          icon: Icons.check_rounded,
                          onPressed: () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) return;
                            HapticFeedback.lightImpact();

                            final mins =
                                int.tryParse(
                                  durationMinsController.text.trim(),
                                ) ??
                                (lecture.durationSeconds ~/ 60);
                            final updated = lecture.copyWith(
                              title: title,
                              author: authorController.text.trim(),
                              durationSeconds: mins * 60,
                              completionThresholdPercent: completionThreshold,
                            );

                            final saved = await _saveLearningEditor(
                              ctx,
                              () => ref
                                  .read(learningHubProvider.notifier)
                                  .updateLecture(courseId, updated),
                            );
                            if (!saved || !ctx.mounted || !context.mounted) {
                              return;
                            }
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lecture updated!'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<bool> _saveLearningEditor(
  BuildContext context,
  Future<void> Function() save,
) async {
  try {
    await save();
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'Could not save. Your changes are still here.',
          ),
        ),
      );
    }
    return false;
  }
}
