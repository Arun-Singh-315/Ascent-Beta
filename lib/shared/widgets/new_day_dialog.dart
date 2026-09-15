import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';

/// Show the new-day morning dialog over [context].
/// Call once per calendar day from HomeScreen's initState.
Future<void> showNewDayDialog(BuildContext context, WidgetRef ref) async {
  // Fetch yesterday's task summary before showing
  final taskDao = ref.read(taskDaoProvider);
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final yesterdayTasks = await taskDao
      .watchTasksByDate(yesterday)
      .first
      .timeout(const Duration(seconds: 2), onTimeout: () => []);

  final completed = yesterdayTasks.where((t) => t.actualCompletedDate != null).length;
  final carriedOver = yesterdayTasks.where((t) => t.actualCompletedDate == null).length;

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _NewDaySheet(
      completed: completed,
      carriedOver: carriedOver,
      ref: ref,
    ),
  );
}

class _NewDaySheet extends StatefulWidget {
  final int completed;
  final int carriedOver;
  final WidgetRef ref;

  const _NewDaySheet({
    required this.completed,
    required this.carriedOver,
    required this.ref,
  });

  @override
  State<_NewDaySheet> createState() => _NewDaySheetState();
}

class _NewDaySheetState extends State<_NewDaySheet> {
  final List<TextEditingController> _taskControllers = [TextEditingController()];
  bool _isSaving = false;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _saveAndClose() async {
    setState(() => _isSaving = true);
    try {
      final taskDao = widget.ref.read(taskDaoProvider);
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      for (final ctrl in _taskControllers) {
        final title = ctrl.text.trim();
        if (title.isEmpty) continue;
        await taskDao.insertTask(
          TaskTableCompanion.insert(
            title: title,
            plannedDate: drift.Value(today),
            priority: const drift.Value('normal'),
          ),
        );
      }

      widget.ref.invalidate(todayFocusTaskProvider);
    } finally {
      setState(() => _isSaving = false);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final c in _taskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final profileAsync = widget.ref.watch(userProfileStreamProvider);
    final name = profileAsync.value?.name ?? 'there';

    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Greeting
            Row(
              children: [
                Text('🌅 ', style: const TextStyle(fontSize: 24)),
                Expanded(
                  child: Text(
                    '${_greeting()}, $name!',
                    style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "It's a new day — $dateStr",
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
            ),

            if (widget.completed > 0 || widget.carriedOver > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.bgSurfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Yesterday's wrap:",
                      style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                    ),
                    const SizedBox(height: 8),
                    if (widget.completed > 0)
                      _WrapRow(
                        icon: '✅',
                        text: '${widget.completed} task${widget.completed == 1 ? '' : 's'} completed',
                      ),
                    if (widget.carriedOver > 0) ...[
                      const SizedBox(height: 4),
                      _WrapRow(
                        icon: '⚠️',
                        text: '${widget.carriedOver} task${widget.carriedOver == 1 ? '' : 's'} carried over',
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            Text(
              "Today I'll work on:",
              style: AscentTextStyles.labelLarge.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 12),

            // Task input fields
            ..._taskControllers.asMap().entries.map((entry) {
              final i = entry.key;
              final ctrl = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: ctrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'e.g. Review system design notes',
                    prefixIcon: Icon(Icons.add_circle_outline_rounded, color: context.accentPrimary, size: 20),
                    suffixIcon: _taskControllers.length > 1
                        ? IconButton(
                            icon: Icon(Icons.remove_circle_outline_rounded, color: context.stateDanger, size: 18),
                            onPressed: () {
                              setState(() {
                                _taskControllers[i].dispose();
                                _taskControllers.removeAt(i);
                              });
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) {
                    setState(() => _taskControllers.add(TextEditingController()));
                  },
                ),
              );
            }),

            // Add another task
            TextButton.icon(
              onPressed: () => setState(() => _taskControllers.add(TextEditingController())),
              icon: Icon(Icons.add_rounded, size: 18, color: context.accentPrimary),
              label: Text(
                'Add another task...',
                style: AscentTextStyles.bodyMedium.copyWith(color: context.accentPrimary),
              ),
            ),

            const SizedBox(height: 20),
            AscentButton.primary(
              label: _isSaving ? 'Saving...' : 'Let\'s Go! 🚀',
              onPressed: _isSaving ? null : _saveAndClose,
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _WrapRow extends StatelessWidget {
  final String icon;
  final String text;

  const _WrapRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(
          text,
          style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
        ),
      ],
    );
  }
}
