import '../../../core/services/note_draft_binding.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/activity_entry_service.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';

final firstMomentPendingProvider = NotifierProvider<FirstMomentPending, bool>(
  FirstMomentPending.new,
);

class FirstMomentPending extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .read(sharedPreferencesProvider)
          .getBool('ascent_first_moment_pending_v1') ??
      false;
  Future<void> finish() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool('ascent_first_moment_pending_v1', false);
    state = false;
  }
}

/// One genuine first capture; examples never become personal records.
class HomeFirstMoment extends ConsumerStatefulWidget {
  const HomeFirstMoment({super.key});
  @override
  ConsumerState<HomeFirstMoment> createState() => _HomeFirstMomentState();
}

class _HomeFirstMomentState extends ConsumerState<HomeFirstMoment> {
  final _text = TextEditingController();
  NoteDraftBinding? _draft;
  @override
  void initState() {
    super.initState();
    _draft = NoteDraftBinding(
      _text,
      ref.read(sharedPreferencesProvider),
      'first_moment',
    );
  }

  String _kind = 'task';
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _draft?.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _text.text.trim();
    if (_saving || value.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      final db = ref.read(databaseProvider);
      if (_kind == 'task') {
        await ActivityEntryService(db).save(title: value, date: DateTime.now());
      } else {
        await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: value,
            mood: const Value('thought'),
          ),
        );
      }
      saved = true;
      _text.clear();
      await _draft?.flush();
      await ref.read(firstMomentPendingProvider.notifier).finish();
      if (mounted) {
        HapticFeedback.lightImpact();
        FocusScope.of(context).unfocus();
      }
    } catch (_) {
      if (saved) {
        // Creation succeeded; never offer a retry that would duplicate it.
        ref.invalidate(firstMomentPendingProvider);
        if (mounted) _text.clear();
      }
      if (mounted) {
        setState(
          () => _error = saved
              ? 'Saved. You can continue below.'
              : 'Could not save. Your text is still here—try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Container(
      key: const ValueKey('home_first_moment'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? g.fill
            : const Color(0xFFFFF6E9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: g.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Begin with one thing',
            style: AscentTextStyles.sectionHeading.copyWith(color: g.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'What would make today feel good?',
            style: AscentTextStyles.bodySmall.copyWith(color: g.inkSecondary),
          ),
          const SizedBox(height: 16),
          AscentSegmentedControl<String>(
            segments: const [
              AscentSegment(value: 'task', label: 'Task'),
              AscentSegment(value: 'thought', label: 'Thought'),
            ],
            selected: _kind,
            enabled: !_saving,
            onChanged: (value) => setState(() {
              _kind = value;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('first_moment_input'),
            controller: _text,
            enabled: !_saving,
            minLines: 1,
            maxLines: 3,
            maxLength: _kind == 'task' ? 300 : 2000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _kind == 'task'
                  ? 'One thing you want to do…'
                  : 'Catch a thought…',
              counterText: '',
              suffixIcon: IconButton.outlined(
                key: const ValueKey('first_moment_send'),
                tooltip: 'Save ${_kind == 'task' ? 'task' : 'thought'}',
                onPressed: _saving || _text.text.trim().isEmpty ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _saving
                  ? null
                  : () =>
                        ref.read(firstMomentPendingProvider.notifier).finish(),
              child: const Text('Explore first'),
            ),
          ),
        ],
      ),
    );
  }
}
