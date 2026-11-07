import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/activity_entry_service.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_dialog.dart';

/// Retained for callers that embed the welcome in a page.
class DayOneTutorialCard extends ConsumerWidget {
  const DayOneTutorialCard({super.key, required this.userName});
  final String userName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref
            .read(sharedPreferencesProvider)
            .getBool(DayOneTutorialDialog.prefKey) ??
        false) {
      return const SizedBox.shrink();
    }
    return AscentButton.tonal(
      label: 'Choose your first small step',
      icon: Icons.add_rounded,
      onPressed: () => DayOneTutorialDialog.show(context, userName: userName),
    );
  }
}

/// An optional, immediately useful first step. Ideas are never saved as records
/// until the person edits or chooses one and taps Add to today.
class DayOneTutorialDialog extends ConsumerStatefulWidget {
  const DayOneTutorialDialog({super.key, required this.userName});
  final String userName;
  static const prefKey = 'ascent_day_one_tutorial_v2_dismissed';

  static Future<void> show(BuildContext context, {required String userName}) =>
      showAscentFrostedDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss welcome',
        barrierColor: Colors.black.withValues(alpha: .12),
        blurSigma: 8,
        transitionDuration: const Duration(milliseconds: 240),
        builder: (_) => DayOneTutorialDialog(userName: userName),
      );

  @override
  ConsumerState<DayOneTutorialDialog> createState() =>
      _DayOneTutorialDialogState();
}

class _DayOneTutorialDialogState extends ConsumerState<DayOneTutorialDialog> {
  final _title = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;
  bool _closing = false;
  String? _error;
  static const ink = Color(0xFF202D3F);
  static const muted = Color(0xFF607087);

  @override
  void dispose() {
    _title.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _markSeen() async {
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setBool(DayOneTutorialDialog.prefKey, true);
    } catch (_) {
      // A guide preference must never block leaving or retry a saved task.
    }
  }

  Future<void> _dismiss() async {
    if (_saving || _closing) return;
    _closing = true;
    final route = ModalRoute.of(context);
    await _markSeen();
    if (mounted && route?.isCurrent == true) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ActivityEntryService(
        ref.read(databaseProvider),
      ).save(title: title, date: DateTime.now());
      if (!mounted) return;
      await _markSeen();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Your first thing is ready on Home.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Your words are still here.';
        });
      }
    }
  }

  void _tryIdea(String idea) {
    _title.text = idea;
    _title.selection = TextSelection.collapsed(offset: idea.length);
    setState(() => _error = null);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AscentTheme.light(preset: DayThemePreset.nordicSky),
    child: Builder(builder: _buildCard),
  );

  Widget _buildCard(BuildContext context) {
    final media = MediaQuery.of(context);
    final name = widget.userName.trim().split(RegExp(r'\s+')).first;
    final height = math.max(
      180.0,
      math.min(
        560.0,
        media.size.height -
            media.viewInsets.bottom -
            media.padding.vertical -
            48,
      ),
    );
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        backgroundColor: const Color(0xFFFBFCFF),
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Colors.white),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420, maxHeight: height),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d MMM').format(DateTime.now()),
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Explore on my own',
                      onPressed: _saving ? null : _dismiss,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: muted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 58,
                        width: 58,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFE3ECFE), Color(0xFFE6F2EA)],
                          ),
                        ),
                        child: const Icon(
                          Icons.wb_twilight_outlined,
                          color: SharedControlColors.actionBlue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name.isEmpty
                            ? 'A fresh page.\nOne small step.'
                            : 'You’re home, $name.',
                        style: AscentTextStyles.homeTitle.copyWith(
                          color: ink,
                          fontSize: 26,
                          letterSpacing: -.6,
                          height: 1.16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'What would make today feel worthwhile?',
                        style: AscentTextStyles.body.copyWith(
                          color: muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        key: const ValueKey('first_step_input'),
                        controller: _title,
                        focusNode: _focus,
                        enabled: !_saving,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 300,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() => _error = null),
                        decoration: InputDecoration(
                          hintText: 'One thing I’d like to do…',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE5F3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'A little inspiration · tap to edit',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final idea in [
                            'Read a few pages',
                            'Go for a short walk',
                          ])
                            ActionChip(
                              label: Text(idea),
                              onPressed: _saving ? null : () => _tryIdea(idea),
                              backgroundColor: const Color(0xFFF0F4FB),
                              side: BorderSide.none,
                              labelStyle: AscentTextStyles.labelSmall.copyWith(
                                color: SharedControlColors.actionBlue,
                              ),
                            ),
                        ],
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: SharedControlColors.dueRed,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AscentButton.primary(
                    key: const ValueKey('first_step_save'),
                    label: 'Add to today',
                    icon: Icons.add_rounded,
                    compact: true,
                    expanded: false,
                    loading: _saving,
                    onPressed: _saving || _title.text.trim().isEmpty
                        ? null
                        : _save,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
