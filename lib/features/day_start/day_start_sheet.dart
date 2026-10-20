import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/glass_theme.dart';
import '../../core/copy/app_copy.dart';
import '../../core/providers/daily_briefing_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/activity_entry_service.dart';
import '../../core/services/plan_collection_service.dart';
import '../../core/streak/study_streak_provider.dart';
import '../../shared/widgets/ascent_option_tile.dart';
import '../money/add_transaction_sheet.dart';

/// One skippable popup that walks through the start of the day:
/// recap -> energy -> top things -> study target -> extras -> done.
///
/// Every step saves as soon as the user moves on, so closing at any point
/// never loses work. Nothing here is shown inline on Home.
class DayStartSheet extends ConsumerStatefulWidget {
  const DayStartSheet({super.key, required this.day});
  final DateTime day;

  static Future<void> show(BuildContext context, DateTime day) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => DayStartSheet(day: day),
      );

  static String energyKey(DateTime day) =>
      'ascent_day_start_energy_${briefingDay(day).toIso8601String()}';

  @override
  ConsumerState<DayStartSheet> createState() => _DayStartSheetState();
}

class _DayStartSheetState extends ConsumerState<DayStartSheet> {
  static const _pageCount = 6;
  static const _energyLabels = ['Low', 'Meh', 'Okay', 'Good', 'Great'];
  static const _energyIcons = [
    Icons.sentiment_very_dissatisfied_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_satisfied_rounded,
    Icons.sentiment_very_satisfied_rounded,
  ];

  final _pages = PageController();
  final _items = TextEditingController();
  int _page = 0;
  int? _energy;
  bool _tomorrow = false;
  int? _minutes;
  int _planned = 0;
  bool _busy = false;
  bool _waterLogged = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _items.dispose();
    super.dispose();
  }

  DateTime get _targetDay {
    final d = briefingDay(widget.day);
    return _tomorrow ? DateTime(d.year, d.month, d.day + 1) : d;
  }

  Future<void> _go(int page) async {
    if (!mounted) return;
    setState(() => _page = page);
    await _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<bool> _saveItems() async {
    final titles = PlanItemDraft.parseList(_items.text);
    if (titles.isEmpty) return true;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ActivityEntryService(ref.read(databaseProvider)).saveMany(
        titles: titles,
        date: _targetDay,
        estimatedMinutes: _minutes,
      );
      if (!mounted) return false;
      HapticFeedback.lightImpact();
      setState(() {
        _planned += titles.length;
        _items.clear();
      });
      return true;
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'Could not save. Your text is still here.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    // The "top things" page commits what was typed before moving on.
    if (_page == 2 && !await _saveItems()) return;
    if (_page >= _pageCount - 1) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await _go(_page + 1);
  }

  Future<void> _pickEnergy(int index) async {
    setState(() => _energy = index);
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setInt(DayStartSheet.energyKey(widget.day), index);
    } catch (_) {
      // Energy is a convenience; never block the flow on it.
    }
  }

  Future<void> _logWater() async {
    try {
      await ref.read(waterDaoProvider).addWater(250);
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() => _waterLogged = true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save water.')));
      }
    }
  }

  Future<void> _leaveTo(String route) async {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final media = MediaQuery.of(context);
    final height = (media.size.height - media.viewInsets.bottom - 120).clamp(
      360.0,
      640.0,
    );
    final skippable = _page >= 1 && _page < _pageCount - 1;
    final last = _page == _pageCount - 1;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: height + 72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 4),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department_rounded, color: g.spark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < _pageCount; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _page ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i <= _page ? g.spark : g.edge,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _recapPage(g),
                  _energyPage(g),
                  _itemsPage(g),
                  _studyPage(g),
                  _extrasPage(g),
                  _donePage(g),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: _busy ? null : () => _go(_page - 1),
                      child: const Text(AppCopy.back),
                    ),
                  const Spacer(),
                  if (skippable)
                    TextButton(
                      onPressed: _busy ? null : () => _go(_page + 1),
                      child: const Text(AppCopy.skip),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: g.spark,
                      foregroundColor: g.onSpark,
                      minimumSize: const Size(112, 48),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(last ? AppCopy.done : AppCopy.next),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pages ────────────────────────────────────────────────────────────────

  Widget _pageShell(AscentGlass g, String title, List<Widget> children) =>
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: g.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget _stat(AscentGlass g, String value, String label) => Container(
    height: AscentOptionTile.height,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: g.fill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: g.edge),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            color: g.sparkInk,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: g.inkMuted, fontSize: 11.5),
        ),
      ],
    ),
  );

  Widget _recapPage(AscentGlass g) {
    final briefing = ref.watch(dailyBriefingProvider(widget.day));
    final name = ref.watch(userProfileStreamProvider).value?.name.trim() ?? '';
    return _pageShell(g, name.isEmpty ? 'Good morning' : 'Good morning, $name', [
      briefing.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (_, _) => Text(
          'Yesterday could not load.',
          style: TextStyle(color: g.inkMuted),
        ),
        data: (d) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yesterday', style: TextStyle(color: g.inkMuted)),
            const SizedBox(height: 8),
            AscentOptionRow(
              children: [
                _stat(g, '${d.completedYesterday}', 'Done'),
                _stat(g, '${d.trackedMinutesYesterday}m', 'Tracked'),
                _stat(g, '${d.dueToday + d.overdue}', 'Due today'),
              ],
            ),
            if (d.overdue > 0) ...[
              const SizedBox(height: 12),
              Text(
                '${d.overdue} overdue',
                style: TextStyle(
                  color: g.coral,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    ]);
  }

  Widget _energyPage(AscentGlass g) => _pageShell(g, 'How is your energy?', [
    AscentOptionRow(
      gap: 6,
      children: [
        for (var i = 0; i < _energyLabels.length; i++)
          AscentOptionTile(
            icon: _energyIcons[i],
            label: _energyLabels[i],
            selected: _energy == i,
            onTap: () => _pickEnergy(i),
          ),
      ],
    ),
  ]);

  Widget _itemsPage(AscentGlass g) => _pageShell(g, 'Top things today', [
    TextField(
      controller: _items,
      enabled: !_busy,
      minLines: 4,
      maxLines: 6,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'One per line',
        errorText: _error,
        filled: true,
        fillColor: g.fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: g.edge),
        ),
      ),
    ),
    const SizedBox(height: 12),
    AscentOptionRow(
      children: [
        AscentOptionTile(
          icon: Icons.today_rounded,
          label: AppCopy.dateToday,
          selected: !_tomorrow,
          onTap: () => setState(() => _tomorrow = false),
        ),
        AscentOptionTile(
          icon: Icons.event_rounded,
          label: AppCopy.dateTomorrow,
          selected: _tomorrow,
          onTap: () => setState(() => _tomorrow = true),
        ),
        PopupMenuButton<int>(
          tooltip: 'Duration for all',
          enabled: !_busy,
          onSelected: (v) => setState(() => _minutes = v == 0 ? null : v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 0, child: Text('No timer')),
            PopupMenuItem(value: 25, child: Text('25 min')),
            PopupMenuItem(value: 45, child: Text('45 min')),
            PopupMenuItem(value: 60, child: Text('60 min')),
          ],
          child: AscentOptionTile(
            icon: Icons.timer_outlined,
            label: AppCopy.typeTimer,
            value: _minutes == null ? 'Off' : '$_minutes min',
            selected: _minutes != null,
          ),
        ),
      ],
    ),
    if (_planned > 0) ...[
      const SizedBox(height: 12),
      Row(
        children: [
          Icon(Icons.check_circle_rounded, color: g.sage, size: 18),
          const SizedBox(width: 6),
          Text('$_planned added', style: TextStyle(color: g.sage)),
        ],
      ),
    ],
  ]);

  Widget _studyPage(AscentGlass g) {
    final status = ref.watch(studyStreakProvider);
    return _pageShell(g, 'Study target', [
      Row(
        children: [
          Icon(Icons.local_fire_department_rounded, color: g.spark, size: 28),
          const SizedBox(width: 8),
          Text(
            '${status.todayMinutes} / ${status.targetMinutes} min',
            style: TextStyle(
              color: g.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: status.progressFraction,
          minHeight: 8,
          backgroundColor: g.track,
          valueColor: AlwaysStoppedAnimation<Color>(g.spark),
        ),
      ),
      const SizedBox(height: 16),
      AscentOptionRow(
        children: [
          AscentOptionTile(
            icon: Icons.play_arrow_rounded,
            label: 'Focus',
            onTap: () => _leaveTo('/focus'),
          ),
          AscentOptionTile(
            icon: Icons.school_outlined,
            label: 'Learning',
            onTap: () => _leaveTo('/learning'),
          ),
          AscentOptionTile(
            icon: Icons.view_agenda_outlined,
            label: 'Board',
            onTap: () => _leaveTo('/today'),
          ),
        ],
      ),
    ]);
  }

  Widget _extrasPage(AscentGlass g) => _pageShell(g, 'Anything else?', [
    AscentOptionRow(
      children: [
        AscentOptionTile(
          icon: Icons.water_drop_outlined,
          label: 'Water',
          value: _waterLogged ? '+250 ml' : null,
          selected: _waterLogged,
          onTap: _waterLogged ? null : _logWater,
        ),
        AscentOptionTile(
          icon: Icons.payments_outlined,
          label: 'Expense',
          onTap: () => AddTransactionSheet.show(context),
        ),
        AscentOptionTile(
          icon: Icons.edit_note_rounded,
          label: 'Thought',
          onTap: () => _leaveTo('/thought-wall'),
        ),
      ],
    ),
  ]);

  Widget _donePage(AscentGlass g) {
    final autoOpen = ref.watch(dailyBriefingAutoOpenProvider);
    return _pageShell(g, 'You are set', [
      Row(
        children: [
          Icon(Icons.local_fire_department_rounded, color: g.spark, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              [
                if (_planned > 0) '$_planned planned',
                if (_energy != null) 'Energy: ${_energyLabels[_energy!]}',
                if (_planned == 0 && _energy == null) 'Day started',
              ].join(' · '),
              style: TextStyle(color: g.ink, fontSize: 16),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _leaveTo('/focus'),
          icon: const Icon(Icons.local_fire_department_rounded),
          label: const Text('Start focus'),
          style: FilledButton.styleFrom(
            backgroundColor: g.spark,
            foregroundColor: g.onSpark,
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Open each morning'),
        value: autoOpen,
        onChanged: (enabled) async {
          try {
            await ref
                .read(dailyBriefingAutoOpenProvider.notifier)
                .setEnabled(enabled);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not save. Try again.')),
              );
            }
          }
        },
      ),
    ]);
  }
}
