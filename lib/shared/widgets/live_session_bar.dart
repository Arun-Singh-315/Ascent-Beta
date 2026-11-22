import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/time_tracking_provider.dart';
import 'app_chip.dart';
import 'app_text_field.dart';
import 'ascent_action_menu.dart';
import 'ascent_button.dart';
import 'ascent_dialog.dart';
import 'ascent_sheet.dart';
import 'ascent_snack_bar.dart';
import 'glass_chrome.dart';

Color parseHexColor(String? hex, {Color fallback = AppPalette.colorFF5FA070}) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
  } catch (_) {}
  return fallback;
}

Color _tintFor(BuildContext context, TimeTrackingState s) =>
    s.activeCategory != null
    ? parseHexColor(s.activeCategory!.colorHex)
    : context.glass.actionInk;

/// The running timer, pinned above the tab bar on every tab (CLAUDE.md
/// §5.2, §3.4 glass chrome), so a session never runs out of sight.
///
/// Shows the label, the ticking time, Pause/Resume and Done; tapping opens
/// the session sheet. Swipe sideways to hide it until the next session.
/// Nothing animates on its own, so it costs nothing while it sits there.
class LiveSessionBar extends ConsumerWidget {
  const LiveSessionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(timeTrackingProvider);
    final session = s.activeSession;
    if (session == null || s.isFloatingDismissed) {
      return const SizedBox.shrink();
    }
    final g = context.glass;
    final tint = _tintFor(context, s);
    final label = session.label.isNotEmpty ? session.label : 'Focus session';
    final notifier = ref.read(timeTrackingProvider.notifier);

    return Dismissible(
      key: ValueKey('live_session_bar_${session.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        notifier.dismissFloatingBar();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s12,
          0,
          AppSpace.s12,
          AppSpace.s8,
        ),
        child: GlassChrome(
          key: const ValueKey('live_session_bar'),
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s12,
            AppSpace.s4,
            AppSpace.s4,
            AppSpace.s4,
          ),
          child: Semantics(
            container: true,
            label:
                '$label, ${s.isRunning ? 'running' : 'paused'}, ${s.formattedTime}',
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => showActiveSessionSheet(context, ref),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.isRunning ? tint : g.inkMuted,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AscentTextStyles.listRowTitle.copyWith(
                              color: g.ink,
                            ),
                          ),
                          Text(
                            '${s.formattedTime} · ${s.isRunning ? 'Running' : 'Paused'}',
                            style:
                                AscentTextStyles.tabular(
                                  AscentTextStyles.caption,
                                ).copyWith(
                                  color: s.isRunning ? tint : g.inkMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('live_session_toggle'),
                    tooltip: s.isRunning ? 'Pause' : 'Resume',
                    icon: Icon(
                      s.isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: g.ink,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      s.isRunning
                          ? notifier.pauseSession()
                          : notifier.resumeSession();
                    },
                  ),
                  IconButton(
                    key: const ValueKey('live_session_done'),
                    tooltip: 'Finish session',
                    icon: Icon(Icons.check_rounded, color: g.successInk),
                    onPressed: () => _confirmComplete(context, ref, label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmComplete(
  BuildContext context,
  WidgetRef ref,
  String label,
) async {
  final ok = await AscentDialog.confirm(
    context: context,
    title: 'Finish this session?',
    content: '“$label” is saved with the time so far.',
    confirmLabel: 'Finish',
    icon: Icons.check_circle_outline_rounded,
  );
  if (ok != true) return;
  HapticFeedback.lightImpact();
  await ref.read(timeTrackingProvider.notifier).completeSession();
  if (context.mounted) {
    AscentSnackBar.show(context, message: 'Session saved');
  }
}

/// The session sheet: time, Pause/Resume, Finish and Abandon.
Future<void> showActiveSessionSheet(BuildContext context, WidgetRef ref) =>
    showAscentSheet<void>(
      context: context,
      builder: (_) => const _ActiveSessionSheet(),
    );

class _ActiveSessionSheet extends ConsumerWidget {
  const _ActiveSessionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(timeTrackingProvider);
    final session = s.activeSession;
    final g = context.glass;
    if (session == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.s24),
        child: Text(
          'No session running.',
          style: AscentTextStyles.body.copyWith(color: g.inkSecondary),
        ),
      );
    }
    final notifier = ref.read(timeTrackingProvider.notifier);
    final label = session.label.isNotEmpty ? session.label : 'Focus session';
    return Padding(
      key: const ValueKey('live_session_sheet'),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s20,
        AppSpace.s8,
        AppSpace.s20,
        AppSpace.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AscentTextStyles.homeTitle.copyWith(color: g.ink)),
          const SizedBox(height: AppSpace.s8),
          Text(
            s.formattedTime,
            style: AscentTextStyles.tabular(
              AscentTextStyles.displayMedium,
            ).copyWith(color: s.isRunning ? _tintFor(context, s) : g.inkMuted),
          ),
          Text(
            s.isRunning ? 'Running' : 'Paused',
            style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
          ),
          const SizedBox(height: AppSpace.s20),
          Row(
            children: [
              Expanded(
                child: AscentButton.secondary(
                  label: s.isRunning ? 'Pause' : 'Resume',
                  icon: s.isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onPressed: () => s.isRunning
                      ? notifier.pauseSession()
                      : notifier.resumeSession(),
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: AscentButton.primary(
                  key: const ValueKey('live_session_sheet_finish'),
                  label: 'Finish',
                  icon: Icons.check_rounded,
                  onPressed: () async {
                    Navigator.pop(context);
                    await notifier.completeSession();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          AscentButton.destructive(
            label: 'Abandon session',
            icon: Icons.delete_outline_rounded,
            expanded: true,
            onPressed: () async {
              final ok = await AscentDialog.confirm(
                context: context,
                title: 'Abandon this session?',
                content: 'The time is not saved. This cannot be undone.',
                confirmLabel: 'Abandon',
                isDestructive: true,
              );
              if (ok != true || !context.mounted) return;
              Navigator.pop(context);
              await notifier.abandonSession();
            },
          ),
        ],
      ),
    );
  }
}

/// Starts a focus session. If one is already running, asks whether to pause
/// or finish it first.
Future<void> showStartSessionSheet(
  BuildContext context,
  WidgetRef ref, {
  String? defaultLabel,
  int? defaultTaskId,
  String defaultActivityType = 'study',
}) async {
  final current = ref.read(timeTrackingProvider);
  if (current.activeSession != null) {
    final action = await showAscentActionMenu<String>(
      context: context,
      title: '“${current.activeSession!.label}” is running',
      actions: const [
        AscentAction('pause', 'Pause it and start new', Icons.pause_rounded),
        AscentAction('stop', 'Finish it and start new', Icons.check_rounded),
      ],
    );
    if (action == null) return;
    if (action == 'pause') {
      await ref.read(timeTrackingProvider.notifier).pauseSession();
    } else {
      await ref.read(timeTrackingProvider.notifier).completeSession();
    }
  }
  if (!context.mounted) return;
  await showAscentSheet<void>(
    context: context,
    builder: (_) => _StartSessionSheet(
      defaultLabel: defaultLabel,
      defaultTaskId: defaultTaskId,
      defaultActivityType: defaultActivityType,
    ),
  );
}

class _StartSessionSheet extends ConsumerStatefulWidget {
  const _StartSessionSheet({
    this.defaultLabel,
    this.defaultTaskId,
    required this.defaultActivityType,
  });
  final String? defaultLabel;
  final int? defaultTaskId;
  final String defaultActivityType;

  @override
  ConsumerState<_StartSessionSheet> createState() => _StartSessionSheetState();
}

class _StartSessionSheetState extends ConsumerState<_StartSessionSheet> {
  late final _label = TextEditingController(text: widget.defaultLabel ?? '');
  int? _categoryId;
  bool _starting = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _start(List<SessionCategory> categories) async {
    final label = _label.text.trim();
    if (label.isEmpty || _starting) return;
    setState(() => _starting = true);
    final catId =
        _categoryId ?? (categories.isNotEmpty ? categories.first.id : 1);
    final cat = categories.where((c) => c.id == catId).firstOrNull;
    Navigator.pop(context);
    await ref
        .read(timeTrackingProvider.notifier)
        .startSession(
          label: label,
          categoryId: catId,
          activityType: cat?.name.toLowerCase() ?? widget.defaultActivityType,
          linkedTaskId: widget.defaultTaskId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final categories =
        ref.watch(activeSessionCategoriesProvider).value ?? const [];
    _categoryId ??= categories
        .where(
          (c) =>
              c.name.toLowerCase() == widget.defaultActivityType.toLowerCase(),
        )
        .firstOrNull
        ?.id;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s20,
        AppSpace.s8,
        AppSpace.s20,
        AppSpace.s24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Start a focus session',
            style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
          ),
          const SizedBox(height: AppSpace.s16),
          AppTextField(
            key: const ValueKey('start_session_label'),
            controller: _label,
            autofocus: true,
            hintText: 'e.g. Pitch deck, DSA practice',
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _start(categories),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final c in categories)
                  AppChip(
                    key: ValueKey('start_session_category_${c.id}'),
                    label: c.name,
                    icon: Icons.circle,
                    iconColor: parseHexColor(c.colorHex),
                    isSelected: _categoryId == c.id,
                    onTap: () => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.s20),
          AscentButton.primary(
            key: const ValueKey('start_session_go'),
            label: 'Start',
            icon: Icons.play_arrow_rounded,
            expanded: true,
            loading: _starting,
            onPressed: _label.text.trim().isEmpty || _starting
                ? null
                : () => _start(categories),
          ),
        ],
      ),
    );
  }
}
