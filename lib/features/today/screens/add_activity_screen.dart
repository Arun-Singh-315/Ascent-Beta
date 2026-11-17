import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart' show ActivityKind, databaseProvider;
import '../../../core/services/activity_entry_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';

/// The dedicated full-screen creator/editor for activities and tasks.
///
/// Follows the Single Source of Truth architecture:
/// - Screen-based (NO popups or sheets that fight keyboard viewport).
/// - Instant auto-focus (`autofocus: true`) on the title field.
/// - Single-enclosure [AppTextField] inputs.
/// - Activity Classification Integrity: Tasks (no duration) vs Timed Activities.
/// - User-selected Star for priority.
class AddActivityScreen extends ConsumerStatefulWidget {
  const AddActivityScreen({
    super.key,
    this.existingTask,
    this.initialDate,
    this.initialTitle,
    this.initialKind,
    this.initialDurationMinutes,
    this.parentTaskId,
    this.prefilledApplicationId,
  });

  final Task? existingTask;
  final DateTime? initialDate;
  final String? initialTitle;
  final ActivityKind? initialKind;
  final int? initialDurationMinutes;
  final int? parentTaskId;
  final int? prefilledApplicationId;

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
  late final TextEditingController _titleController;
  late final FocusNode _titleFocus;
  late final TextEditingController _notesController;

  late DateTime _selectedDate;
  ActivityKind _kind = ActivityKind.todo;
  int _targetMinutes = 30;
  bool _isImportant = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _titleController = TextEditingController(
      text: task?.title ?? widget.initialTitle ?? '',
    );
    _titleFocus = FocusNode();
    _notesController = TextEditingController(text: task?.notes ?? '');

    _selectedDate = task?.plannedDate ?? widget.initialDate ?? DateTime.now();

    if (task != null) {
      if (task.estimatedMinutes != null && task.estimatedMinutes! > 0) {
        _kind = ActivityKind.duration;
        _targetMinutes = task.estimatedMinutes!;
      } else {
        _kind = ActivityKind.todo;
      }
      _isImportant = task.priority.toLowerCase() == 'high';
    } else {
      _kind = widget.initialKind ??
          (widget.initialDurationMinutes != null
              ? ActivityKind.duration
              : ActivityKind.todo);
      if (widget.initialDurationMinutes != null) {
        _targetMinutes = widget.initialDurationMinutes!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocus.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _errorMessage = 'Please enter a title');
      _titleFocus.requestFocus();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final minutes = _kind == ActivityKind.duration ? _targetMinutes : null;

      await ActivityEntryService(db).save(
        title: title,
        date: _selectedDate,
        estimatedMinutes: minutes,
        notes: _notesController.text.trim(),
        priority: _isImportant ? 'high' : 'normal',
        taskId: widget.existingTask?.id,
        parentTaskId: widget.parentTaskId,
        applicationId: widget.prefilledApplicationId,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    if (widget.existingTask == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text(
          'Are you sure you want to delete this activity? All associated reminders and timers will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      HapticFeedback.mediumImpact();
      final db = ref.read(databaseProvider);
      await db.taskDao.deleteTask(widget.existingTask!.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingTask != null;

    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = _selectedDate.year == tomorrow.year &&
        _selectedDate.month == tomorrow.month &&
        _selectedDate.day == tomorrow.day;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.surfaceAlt,
                        border: Border.all(color: c.border, width: 1.0),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Activity' : 'New Activity',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.red),
                      onPressed: _handleDelete,
                    )
                  else
                    const SizedBox(width: 38),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Title Input Field with Auto-Focus
                  AppTextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    autofocus: true,
                    hintText: 'What needs to be done?',
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleSave(),
                    prefixIcon: Icon(
                      _kind == ActivityKind.duration
                          ? Icons.timer_outlined
                          : Icons.check_circle_outline_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isImportant
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: _isImportant
                            ? const Color(0xFFC99A3C) // soft gold
                            : c.textTertiary,
                        size: 24,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isImportant = !_isImportant);
                      },
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Kind / Duration Selection
                  Text(
                    'Activity Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(
                        label: 'Task',
                        icon: Icons.check_rounded,
                        isSelected: _kind == ActivityKind.todo,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _kind = ActivityKind.todo);
                        },
                        c: c,
                        colorScheme: colorScheme,
                        isDark: isDark,
                      ),
                      _buildChip(
                        label: '15m Focus',
                        icon: Icons.timer_outlined,
                        isSelected: _kind == ActivityKind.duration &&
                            _targetMinutes == 15,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _kind = ActivityKind.duration;
                            _targetMinutes = 15;
                          });
                        },
                        c: c,
                        colorScheme: colorScheme,
                        isDark: isDark,
                      ),
                      _buildChip(
                        label: '30m Focus',
                        icon: Icons.timer_outlined,
                        isSelected: _kind == ActivityKind.duration &&
                            _targetMinutes == 30,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _kind = ActivityKind.duration;
                            _targetMinutes = 30;
                          });
                        },
                        c: c,
                        colorScheme: colorScheme,
                        isDark: isDark,
                      ),
                      _buildChip(
                        label: '45m Focus',
                        icon: Icons.timer_outlined,
                        isSelected: _kind == ActivityKind.duration &&
                            _targetMinutes == 45,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _kind = ActivityKind.duration;
                            _targetMinutes = 45;
                          });
                        },
                        c: c,
                        colorScheme: colorScheme,
                        isDark: isDark,
                      ),
                      _buildChip(
                        label: '60m Focus',
                        icon: Icons.timer_outlined,
                        isSelected: _kind == ActivityKind.duration &&
                            _targetMinutes == 60,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _kind = ActivityKind.duration;
                            _targetMinutes = 60;
                          });
                        },
                        c: c,
                        colorScheme: colorScheme,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Date Selection
                  Text(
                    'Scheduled Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip(
                        label: 'Today',
                        isSelected: isToday,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedDate = DateTime.now());
                        },
                        c: c,
                        colorScheme: colorScheme,
                        isDark: isDark,
                      ),
                      _buildChip(
                        label: 'Tomorrow',
                        isSelected: isTomorrow,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() =>
                              _selectedDate = now.add(const Duration(days: 1)));
                        },
                        c: c,
                        colorScheme: colorScheme,
                        isDark: isDark,
                      ),
                      _buildChip(
                        label: (!isToday && !isTomorrow)
                            ? DateFormat('EEE, d MMM').format(_selectedDate)
                            : 'Pick date',
                        icon: Icons.calendar_today_rounded,
                        isSelected: !isToday && !isTomorrow,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: now.subtract(const Duration(days: 30)),
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        c: c,
                        colorScheme: colorScheme,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Notes Input
                  Text(
                    'Notes (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  AppTextField(
                    controller: _notesController,
                    hintText: 'Add details, links, or notes...',
                    maxLines: 4,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(top: BorderSide(color: c.border, width: 1.0)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          isEditing ? 'Save Changes' : 'Create Activity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColors c,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : (isDark ? const Color(0x302A2E3B) : c.surfaceAlt),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colorScheme.primary : c.border,
            width: 1.0,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? colorScheme.onPrimary : c.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? colorScheme.onPrimary : c.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
