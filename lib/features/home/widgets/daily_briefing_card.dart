import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/merlot_palette.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/daily_briefing_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/streak/study_streak_provider.dart';
import '../../../shared/widgets/ascent_card.dart';
import '../../today/add_activity_sheet.dart';

class DailyBriefingCard extends ConsumerWidget {
  const DailyBriefingCard({super.key, required this.day});
  final DateTime day;

  static Future<void> show(BuildContext context, DateTime day) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? context.bgBase
            : (context.glass.merlot
                ? MerlotPalette.canvas
                : (context.glass.frozen ? FrozenPalette.canvas : context.bgBase)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: _DailyLaunchpadFlow(day: day, inSheet: true),
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: AscentCard(child: _DailyLaunchpadFlow(day: day)),
  );
}

class _DailyLaunchpadFlow extends ConsumerStatefulWidget {
  const _DailyLaunchpadFlow({required this.day, this.inSheet = false});
  final DateTime day;
  final bool inSheet;

  @override
  ConsumerState<_DailyLaunchpadFlow> createState() => _DailyLaunchpadFlowState();
}

class _DailyLaunchpadFlowState extends ConsumerState<_DailyLaunchpadFlow> {
  int _currentStep = 0; // 0: Yesterday & Welcome, 1: One-Stop Data Feeder, 2: Launch
  final _taskTitleController = TextEditingController();
  ActivityKind _selectedKind = ActivityKind.todo;
  int _durationMinutes = 25;
  bool _taskSaved = false;
  bool _waterLogged = false;
  bool _thoughtSaved = false;
  final _thoughtController = TextEditingController();
  bool _showThoughtField = false;

  Timer? _feedbackTimer;

  static const Color _fireSpark = Color(0xFFFBBF24); // Flame yellow/amber

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _taskTitleController.dispose();
    _thoughtController.dispose();
    super.dispose();
  }

  void _navigate(String route) {
    final router = GoRouter.of(context);
    if (widget.inSheet) Navigator.pop(context);
    router.push(route);
  }

  Future<void> _saveQuickTask() async {
    final title = _taskTitleController.text.trim();
    if (title.isEmpty) return;

    HapticFeedback.mediumImpact();
    final db = ref.read(databaseProvider);
    final isDuration = _selectedKind == ActivityKind.duration;
    final isFlexible = _selectedKind == ActivityKind.flexible;

    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: title,
        plannedDate: drift.Value(widget.day),
        estimatedMinutes: drift.Value(
          isDuration ? _durationMinutes : (isFlexible ? -1 : 0),
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _taskSaved = true;
        _taskTitleController.clear();
      });
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _taskSaved = false);
      });
    }
  }

  Future<void> _logQuickWater() async {
    HapticFeedback.lightImpact();
    final db = ref.read(databaseProvider);
    await db.waterDao.addWater(250);
    if (mounted) {
      setState(() => _waterLogged = true);
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _waterLogged = false);
      });
    }
  }

  Future<void> _saveQuickThought() async {
    final thought = _thoughtController.text.trim();
    if (thought.isEmpty) return;

    HapticFeedback.lightImpact();
    final db = ref.read(databaseProvider);
    await db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(content: thought),
    );
    if (mounted) {
      setState(() {
        _thoughtSaved = true;
        _thoughtController.clear();
        _showThoughtField = false;
      });
      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _thoughtSaved = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final briefing = ref.watch(dailyBriefingProvider(widget.day));
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streak = ref.watch(studyStreakProvider).currentStreakDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header & Step Bar ──────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _fireSpark.withValues(alpha: 0.18),
                border: Border.all(
                  color: _fireSpark.withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: _fireSpark,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Launchpad',
                    style: (widget.inSheet
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.titleMedium)
                        ?.copyWith(
                          color: g.ink,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                  ),
                  Text(
                    'Step ${_currentStep + 1} of 3 · ${switch (_currentStep) {
                      0 => 'Yesterday & Welcome',
                      1 => 'Feed Today’s Focus',
                      _ => 'Ready to Ascend',
                    }}',
                    style: TextStyle(
                      fontSize: 11,
                      color: g.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.inSheet)
              IconButton(
                tooltip: 'Dismiss daily briefing',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // Micro Progress Indicator Pills
        Row(
          children: List.generate(3, (index) {
            final active = index <= _currentStep;
            return Expanded(
              child: Container(
                height: 3.5,
                margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: active
                      ? _fireSpark
                      : g.edge.withValues(alpha: isDark ? 0.25 : 0.4),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 14),

        // ── Main Body with Stepper Content ──────────────────────────────────
        if (briefing.value != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey('step_$_currentStep'),
              child: _buildStepContent(briefing.value!, g, isDark, streak),
            ),
          )
        else if (briefing.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Gathering your recorded activity…'),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your summary could not load. You can still take a next step below.',
              ),
              TextButton(
                onPressed: () => ref.invalidate(dailyBriefingProvider(widget.day)),
                child: const Text('Try again'),
              ),
            ],
          ),

        if (widget.inSheet) ...[
          const SizedBox(height: 16),
          Divider(color: g.line),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Welcome me each new day'),
            subtitle: const Text(
              'Open this check-in automatically. You can always find it on Home.',
            ),
            value: ref.watch(dailyBriefingAutoOpenProvider),
            onChanged: (enabled) async {
              try {
                await ref
                    .read(dailyBriefingAutoOpenProvider.notifier)
                    .setEnabled(enabled);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not save. Please try again.'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStepContent(DailyBriefing data, AscentGlass g, bool isDark, int streak) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Welcome(data, g, isDark, streak);
      case 1:
        return _buildStep2DataFeeder(data, g, isDark);
      case 2:
      default:
        return _buildStep3Launch(data, g, isDark);
    }
  }

  // ── Step 1: Yesterday Review & Welcome ─────────────────────────────────────
  Widget _buildStep1Welcome(DailyBriefing data, AscentGlass g, bool isDark, int streak) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Yesterday Review Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? g.fill : (g.merlot ? MerlotPalette.surface : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: g.edge.withValues(alpha: isDark ? 0.35 : 0.65),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 16, color: g.clay),
                  const SizedBox(width: 6),
                  Text(
                    'Yesterday in Review',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: g.clay,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data.yesterdaySummary,
                style: TextStyle(
                  fontSize: 13.5,
                  color: g.ink,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.encouragement,
                style: TextStyle(
                  fontSize: 12,
                  color: g.inkMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Streak & Momentum Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _fireSpark.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _fireSpark.withValues(alpha: 0.3),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, size: 18, color: _fireSpark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  streak == 0
                      ? 'Ignite your streak today with 1 focused activity!'
                      : '$streak day active streak! Keep the flame alive.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Quick Primary Actions
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => setState(() => _currentStep = 1),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Glide to Today’s Plan'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final rootContext = navigator.context;
                if (widget.inSheet) navigator.pop();
                await AddActivitySheet.show(widget.inSheet ? rootContext : context);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Plan one small task'),
            ),
            TextButton.icon(
              onPressed: () => _navigate('/thought-wall'),
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: const Text('Capture a thought'),
            ),
            TextButton.icon(
              onPressed: () => _navigate('/ai-assistant'),
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: Text('Ask ${ref.watch(assistantNameProvider)}'),
            ),
            if (!widget.inSheet)
              TextButton(
                onPressed: () => DailyBriefingCard.show(context, widget.day),
                child: const Text('Open daily check-in'),
              )
            else
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('I’ll explore on my own'),
              ),
          ],
        ),
      ],
    );
  }

  // ── Step 2: One-Stop Data Feeder ──────────────────────────────────────────
  Widget _buildStep2DataFeeder(DailyBriefing data, AscentGlass g, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Feed Today’s Focus',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: g.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Queue your main task, hydrate, or capture an intention in one place.',
          style: TextStyle(fontSize: 12, color: g.inkMuted),
        ),
        const SizedBox(height: 12),

        // Inline Priority Task Input
        TextField(
          controller: _taskTitleController,
          decoration: InputDecoration(
            hintText: 'e.g., Complete System Design, Study Trees',
            hintStyle: TextStyle(color: g.inkMuted.withValues(alpha: 0.6), fontSize: 13),
            filled: true,
            fillColor: isDark ? g.fill : (g.merlot ? MerlotPalette.surface : Colors.white),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: g.edge.withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: g.edge.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _fireSpark, width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Activity Kind Chips (Equal Sized & Fire-accented)
        Row(
          children: [
            _buildTypeChip(
              icon: Icons.check_circle_outline_rounded,
              label: 'To-do',
              subtitle: 'Simple task',
              isSelected: _selectedKind == ActivityKind.todo,
              onTap: () => setState(() => _selectedKind = ActivityKind.todo),
              g: g,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildTypeChip(
              icon: Icons.timer_outlined,
              label: 'Timed',
              subtitle: 'Track duration',
              isSelected: _selectedKind == ActivityKind.duration,
              onTap: () => setState(() => _selectedKind = ActivityKind.duration),
              g: g,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildTypeChip(
              icon: Icons.all_inclusive_rounded,
              label: 'Flexible',
              subtitle: 'Track as you go',
              isSelected: _selectedKind == ActivityKind.flexible,
              onTap: () => setState(() => _selectedKind = ActivityKind.flexible),
              g: g,
              isDark: isDark,
            ),
          ],
        ),

        // Target Duration selection if Timed
        if (_selectedKind == ActivityKind.duration) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [15, 25, 45, 60, 90].map((mins) {
              final isSel = _durationMinutes == mins;
              return ChoiceChip(
                label: Text('$mins min'),
                selected: isSel,
                selectedColor: _fireSpark.withValues(alpha: 0.25),
                backgroundColor: isDark ? g.fill : Colors.white,
                side: BorderSide(
                  color: isSel ? _fireSpark : g.edge.withValues(alpha: 0.4),
                ),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? (isDark ? Colors.white : const Color(0xFFB45309)) : g.ink,
                ),
                onSelected: (_) => setState(() => _durationMinutes = mins),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 12),

        // Action to save quick task (Retains 'Plan one small task' for test compatibility)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              if (_taskTitleController.text.trim().isNotEmpty) {
                await _saveQuickTask();
              } else {
                // If text empty, open full activity composer
                final navigator = Navigator.of(context);
                final rootContext = navigator.context;
                if (widget.inSheet) navigator.pop();
                await AddActivitySheet.show(widget.inSheet ? rootContext : context);
              }
            },
            icon: Icon(_taskSaved ? Icons.check_circle_rounded : Icons.add, size: 16),
            label: Text(_taskSaved ? 'Task added to today!' : 'Plan one small task'),
          ),
        ),

        const SizedBox(height: 12),

        // One-Tap Quick Feeders (Hydration + Thought)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _logQuickWater,
                icon: Icon(
                  _waterLogged ? Icons.check_circle_rounded : Icons.water_drop_outlined,
                  size: 15,
                  color: Colors.blueAccent,
                ),
                label: Text(
                  _waterLogged ? '+250ml logged!' : '+250ml water',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  if (widget.inSheet) {
                    setState(() => _showThoughtField = !_showThoughtField);
                  } else {
                    _navigate('/thought-wall');
                  }
                },
                icon: const Icon(Icons.edit_note_rounded, size: 15),
                label: const Text('Capture a thought', style: TextStyle(fontSize: 11.5)),
              ),
            ),
          ],
        ),

        if (_showThoughtField) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _thoughtController,
                  decoration: InputDecoration(
                    hintText: 'Note or reflection...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _saveQuickThought,
                child: Text(_thoughtSaved ? 'Saved!' : 'Save'),
              ),
            ],
          ),
        ],

        const SizedBox(height: 14),

        // Stepper Navigation
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('← Back'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => setState(() => _currentStep = 2),
                child: const Text('Next: Launch Day →'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 3: Launch Day & Overview ─────────────────────────────────────────
  Widget _buildStep3Launch(DailyBriefing data, AscentGlass g, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? g.fill : (g.merlot ? MerlotPalette.surface : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: g.edge.withValues(alpha: isDark ? 0.35 : 0.65),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rocket_launch_rounded, size: 16, color: _fireSpark),
                  const SizedBox(width: 6),
                  Text(
                    'All Set for Today',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: g.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${data.dueToday} due today · ${data.overdue} overdue · ${data.unscheduled} unscheduled',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: g.clay,
                ),
              ),
              if (data.nextTask != null) ...[
                const SizedBox(height: 6),
                Text(
                  'A place to start: ${data.nextTask}',
                  style: TextStyle(fontSize: 12.5, color: g.ink),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _navigate('/today'),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Take me to my tasks'),
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text('← Edit Focus'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: widget.inSheet
                  ? TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('I’ll explore on my own'),
                    )
                  : TextButton(
                      onPressed: () => DailyBriefingCard.show(context, widget.day),
                      child: const Text('Open daily check-in'),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required AscentGlass g,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? context.accentPrimary.withValues(alpha: 0.85) : context.accentPrimary)
                : (isDark ? g.fill : (g.merlot ? MerlotPalette.surface : Colors.white)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? _fireSpark
                  : g.edge.withValues(alpha: isDark ? 0.35 : 0.65),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _fireSpark.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? _fireSpark.withValues(alpha: 0.22)
                        : g.edge.withValues(alpha: isDark ? 0.2 : 0.1),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 14,
                      color: isSelected ? _fireSpark : context.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : context.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isSelected ? Colors.white.withValues(alpha: 0.85) : context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
