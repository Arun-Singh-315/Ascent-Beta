import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/learning_hub/learning_hub_models.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../shared/widgets/ascent_button.dart';

class AddCourseSheet extends ConsumerStatefulWidget {
  const AddCourseSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddCourseSheet(),
    );
  }

  @override
  ConsumerState<AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends ConsumerState<AddCourseSheet> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descController = TextEditingController();
  final _categoryController = TextEditingController();
  final _moduleTitleController = TextEditingController();
  final _bulkLecturesController = TextEditingController();

  int _currentStep = 0; // 0: Details, 1: Modules & Lectures, 2: Review
  final List<CourseModule> _modules = [];
  bool _useBulkLectureEntry = false;
  int _defaultLectureDurationMins = 15;

  @override
  void initState() {
    super.initState();
    _authorController.text = 'Self-Paced / Instructor';
    _categoryController.text = 'Software Engineering';
    _moduleTitleController.text = 'Module 1: Foundations';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _moduleTitleController.dispose();
    _bulkLecturesController.dispose();
    super.dispose();
  }

  void _addModuleWithLectures() {
    final modTitle = _moduleTitleController.text.trim().isEmpty
        ? 'Module ${_modules.length + 1}'
        : _moduleTitleController.text.trim();

    List<Lecture> lectures = [];
    final modId = _modules.length + 1;

    if (_useBulkLectureEntry && _bulkLecturesController.text.trim().isNotEmpty) {
      final lines = _bulkLecturesController.text.split('\n');
      int lecIdx = 1;
      for (final line in lines) {
        final clean = line.replaceAll(RegExp(r'^\s*[\d\.\-\*]+\s*'), '').trim();
        if (clean.isNotEmpty) {
          lectures.add(Lecture(
            id: DateTime.now().millisecondsSinceEpoch % 100000 + lecIdx,
            moduleId: modId,
            moduleTitle: modTitle,
            title: clean,
            author: _authorController.text.trim(),
            durationSeconds: _defaultLectureDurationMins * 60,
          ));
          lecIdx++;
        }
      }
    } else {
      // Create a default starter lecture for the module
      lectures.add(Lecture(
        id: DateTime.now().millisecondsSinceEpoch % 100000 + 1,
        moduleId: modId,
        moduleTitle: modTitle,
        title: 'Lecture 1: Introduction to $modTitle',
        author: _authorController.text.trim(),
        durationSeconds: _defaultLectureDurationMins * 60,
      ));
    }

    final newModule = CourseModule(
      id: modId,
      title: modTitle,
      description: '',
      durationHours: (lectures.length * _defaultLectureDurationMins) / 60.0,
      lectures: lectures,
    );

    setState(() {
      _modules.add(newModule);
      _moduleTitleController.text = 'Module ${_modules.length + 1}';
      _bulkLecturesController.clear();
    });
  }

  void _saveCourse() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    List<CourseModule> finalModules = List.from(_modules);
    if (finalModules.isEmpty) {
      // Add a starter module if none was created
      finalModules.add(CourseModule(
        id: 1,
        title: 'Module 1: Getting Started',
        description: '',
        durationHours: 0.5,
        lectures: [
          Lecture(
            id: DateTime.now().millisecondsSinceEpoch % 100000 + 1,
            moduleId: 1,
            moduleTitle: 'Module 1: Getting Started',
            title: 'Overview & Objectives',
            author: _authorController.text.trim(),
            durationSeconds: 900,
          ),
        ],
      ));
    }

    final newCourse = Course(
      id: 'course_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _descController.text.trim(),
      author: _authorController.text.trim(),
      category: _categoryController.text.trim(),
      modules: finalModules,
      daysLeft: 30,
      targetMinutesPerDay: 45,
    );

    ref.read(learningHubProvider.notifier).addCourse(newCourse);
    HapticFeedback.mediumImpact();

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Course "$title" created! Switched as active course.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: context.divider.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school_rounded, color: context.accentPrimary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Create Course',
                        style: AscentTextStyles.displaySmall.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: context.textMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Step Indicator Pills
              Row(
                children: [
                  _StepPill(
                    index: 0,
                    label: 'Course Info',
                    isActive: _currentStep == 0,
                    onTap: () => setState(() => _currentStep = 0),
                  ),
                  const SizedBox(width: 6),
                  _StepPill(
                    index: 1,
                    label: 'Modules & Lectures',
                    isActive: _currentStep == 1,
                    onTap: () => setState(() => _currentStep = 1),
                  ),
                  const SizedBox(width: 6),
                  _StepPill(
                    index: 2,
                    label: 'Review',
                    isActive: _currentStep == 2,
                    onTap: () => setState(() => _currentStep = 2),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Step Content
              Expanded(
                child: SingleChildScrollView(
                  child: _currentStep == 0
                      ? _buildStep0Details(isDark)
                      : _currentStep == 1
                          ? _buildStep1Modules(isDark)
                          : _buildStep2Review(),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom Actions
              Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: AscentButton.outlined(
                        label: 'Back',
                        onPressed: () => setState(() => _currentStep--),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 10),
                  Expanded(
                    child: AscentButton.primary(
                      label: _currentStep < 2 ? 'Next Step' : 'Save Course',
                      icon: _currentStep < 2 ? Icons.arrow_forward_rounded : Icons.check_circle_outline_rounded,
                      onPressed: () {
                        if (_currentStep == 0) {
                          if (_titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a course name')),
                            );
                            return;
                          }
                          setState(() => _currentStep = 1);
                        } else if (_currentStep == 1) {
                          setState(() => _currentStep = 2);
                        } else {
                          _saveCourse();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0Details(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Course Name *', style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g., Spring Boot Masterclass, Java Fundamentals, DSA',
            hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
            filled: true,
            fillColor: isDark ? const Color(0xFF141720) : const Color(0xFFF7F6F2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        Text('Category or Subject', style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _categoryController,
          decoration: InputDecoration(
            hintText: 'e.g., Backend Engineering, Algorithms, Mobile',
            filled: true,
            fillColor: isDark ? const Color(0xFF141720) : const Color(0xFFF7F6F2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        Text('Instructor / Author', style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _authorController,
          decoration: InputDecoration(
            hintText: 'e.g., Engineering Digest, Kunal Kushwaha, Self-Study',
            filled: true,
            fillColor: isDark ? const Color(0xFF141720) : const Color(0xFFF7F6F2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        Text('Description (Optional)', style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: _descController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Key topics, syllabus, or learning goals...',
            filled: true,
            fillColor: isDark ? const Color(0xFF141720) : const Color(0xFFF7F6F2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Modules(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Add Modules & Lectures',
              style: AscentTextStyles.labelMedium.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Text('Bulk paste:', style: TextStyle(fontSize: 11, color: context.textMuted)),
                Switch(
                  value: _useBulkLectureEntry,
                  activeTrackColor: context.accentPrimary,
                  onChanged: (v) => setState(() => _useBulkLectureEntry = v),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Module Input Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141720) : const Color(0xFFF7F6F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.divider.withValues(alpha: 0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Module Title:', style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted)),
              const SizedBox(height: 4),
              TextField(
                controller: _moduleTitleController,
                decoration: InputDecoration(
                  hintText: 'e.g. Module 1: Core Principles',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              if (_useBulkLectureEntry) ...[
                Text(
                  'Paste lecture titles (one per line):',
                  style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _bulkLecturesController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "1. Introduction\n2. Architecture Overview\n3. Setting up Environment\n4. First Application",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Default lecture duration: ', style: TextStyle(fontSize: 11, color: context.textMuted)),
                  DropdownButton<int>(
                    value: _defaultLectureDurationMins,
                    underline: const SizedBox.shrink(),
                    items: [10, 15, 20, 30, 45, 60].map((m) {
                      return DropdownMenuItem(value: m, child: Text('$m mins', style: const TextStyle(fontSize: 12)));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _defaultLectureDurationMins = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: AscentButton.primary(
                  label: '+ Add Module',
                  compact: true,
                  onPressed: _addModuleWithLectures,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Text(
          'Configured Modules (${_modules.length})',
          style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),

        if (_modules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No modules added yet. You can add them above or save an empty course and add modules later.',
              style: TextStyle(fontSize: 12, color: context.textMuted),
            ),
          )
        else
          for (int i = 0; i < _modules.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.bgBase,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.divider.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: context.accentPrimary.withValues(alpha: 0.15),
                    child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: context.accentPrimary)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_modules[i].title, style: AscentTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                        Text('${_modules[i].lectures.length} lectures • ${_modules[i].durationHours.toStringAsFixed(1)}h',
                            style: TextStyle(fontSize: 11, color: context.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    color: context.stateDanger,
                    onPressed: () => setState(() => _modules.removeAt(i)),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildStep2Review() {
    int totalLectures = _modules.fold(0, (sum, m) => sum + m.lectures.length);
    int totalSecs = _modules.fold(0, (sum, m) => sum + m.totalDurationSeconds);
    final hours = (totalSecs / 3600).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.accentPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.accentPrimary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleController.text.trim().isEmpty ? 'Untitled Course' : _titleController.text.trim(),
                style: AscentTextStyles.displaySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_categoryController.text.trim()} • Instructor: ${_authorController.text.trim()}',
                style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MetricItem(label: 'Modules', value: '${_modules.length}'),
                  _MetricItem(label: 'Lectures', value: '$totalLectures'),
                  _MetricItem(label: 'Est. Duration', value: '${hours}h'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Curriculum Outline:', style: AscentTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final m in _modules)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.folder_open_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${m.title} (${m.lectures.length} lectures)',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  final int index;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _StepPill({
    required this.index,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? context.accentPrimary : context.bgBase,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? context.accentPrimary : context.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : context.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetricItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AscentTextStyles.displaySmall.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
