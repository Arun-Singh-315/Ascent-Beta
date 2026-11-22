import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/services/activity_entry_service.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_sheet.dart';
import '../../shared/widgets/ascent_snack_bar.dart';

/// Thoughts that belong on a calendar day: the day they were written, or
/// the day they were carried on to.
final calendarThoughtsProvider = StreamProvider<List<Thought>>(
  (ref) => ref.watch(thoughtDaoProvider).watchActiveThoughts(),
);

DateTime calendarDayOf(Thought t) {
  final d = t.carriedOn ?? t.createdAt;
  return DateTime(d.year, d.month, d.day);
}

/// Saves one to-do on every day in [days]; returns the new task ids.
Future<List<int>> saveTodoOnDays(
  AppDatabase db,
  String title,
  Iterable<DateTime> days,
) => db.transaction(() async {
  final service = ActivityEntryService(db);
  final ids = <int>[];
  for (final d in days) {
    final saved = await service.save(
      title: title.trim(),
      date: DateTime(d.year, d.month, d.day),
    );
    ids.add(saved.taskId);
  }
  return ids;
});

/// One title, many days: "Gym" on Mon, Wed and Fri in one go.
Future<bool?> showMultiDayTodoSheet(
  BuildContext context,
  List<DateTime> days,
) => showAscentSheet<bool>(
  context: context,
  builder: (_) => MultiDayTodoSheet(days: days),
);

class MultiDayTodoSheet extends ConsumerStatefulWidget {
  const MultiDayTodoSheet({super.key, required this.days});
  final List<DateTime> days;

  @override
  ConsumerState<MultiDayTodoSheet> createState() => _MultiDayTodoSheetState();
}

class _MultiDayTodoSheetState extends ConsumerState<MultiDayTodoSheet> {
  final _title = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final List<int> ids;
    try {
      ids = await saveTodoOnDays(db, title, widget.days);
    } on StateError catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message == 'Choose today or a future date.'
              ? 'Past days can’t take new to-dos. Pick today or later.'
              : e.message;
        });
      }
      return;
    }
    HapticFeedback.lightImpact();
    if (!mounted) return;
    final root = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop(true);
    if (root.mounted) {
      AscentSnackBar.undo(
        root,
        message: ids.length == 1
            ? 'Added to 1 day'
            : 'Added to ${ids.length} days',
        onUndo: () async {
          for (final id in ids) {
            await db.taskDao.deleteTask(id, bypassProtection: true);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final days = [...widget.days]..sort();
    final fmt = DateFormat('EEE d MMM');
    return SingleChildScrollView(
      primary: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AscentButton.ghost(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  days.length == 1
                      ? 'Add to 1 day'
                      : 'Add to ${days.length} days',
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.cardTitle.copyWith(color: g.ink),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _title,
                builder: (context, v, _) => AscentButton.ghost(
                  key: const ValueKey('multi_day_save'),
                  label: 'Add',
                  onPressed: v.text.trim().isEmpty || _saving ? null : _save,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            key: const ValueKey('multi_day_title'),
            controller: _title,
            autofocus: true,
            hintText: 'e.g. Gym 45 min',
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              _error!,
              key: const ValueKey('multi_day_error'),
              style: AscentTextStyles.caption.copyWith(color: g.errorInk),
            ),
          ],
          const SizedBox(height: AppSpace.s12),
          Text(
            days.map(fmt.format).join(' · '),
            style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
          ),
        ],
      ),
    );
  }
}
