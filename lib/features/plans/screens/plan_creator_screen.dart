import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/plan_collection_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../planning_providers.dart';
import 'plan_detail_screen.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;

/// A single scheduled placement for a task within the plan creator.
class _TaskPlacement {
  _TaskPlacement({
    Set<int>? days,
    this.timeOfDay = 'morning',
  }) : days = days ?? {0};

  Set<int> days; // 0-based day offsets from start of plan
  String timeOfDay; // 'morning' (9am), 'afternoon' (2pm), 'evening' (7pm)
  TimeOfDay? exactTime;
}

/// Tap-First Full-Screen Plan Creator Flow.
/// 
/// 4 quick steps, almost no typing:
/// 1. Pick the span (Today, 3 days, This week, 2 weeks, Repeating)
/// 2. Add tasks with auto-focused field & instant suggestion chips
/// 3. Place them with taps (Day dots, Morning/Afternoon/Evening, Spread evenly)
/// 4. Confirm with calm summary and smart notification defaults
class PlanCreatorScreen extends ConsumerStatefulWidget {
  const PlanCreatorScreen({
    super.key,
    this.initialSpan = '3d',
    this.initialTasks,
  });

  final String initialSpan;
  final List<String>? initialTasks;

  @override
  ConsumerState<PlanCreatorScreen> createState() => _PlanCreatorScreenState();
}

class _PlanCreatorScreenState extends ConsumerState<PlanCreatorScreen> {
  int _currentStep = 0; // 0: Span, 1: Tasks, 2: Place, 3: Confirm
  late String _selectedSpan;

  late final List<String> _tasks;
  final Map<int, _TaskPlacement> _placements = {};

  final TextEditingController _taskInputController = TextEditingController();
  final FocusNode _taskInputFocus = FocusNode();

  String _reminderMode = 'morning'; // 'off', 'morning', 'exact'
  bool _isCreating = false;

  final List<String> _suggestionChips = [
    'Study',
    'Meditate',
    'Review notes',
    'Lecture 12 · Spring Security',
    'Gym',
    'Read 20 pages',
    'Walk 20 min',
    'Plan the weekend',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSpan = widget.initialSpan;
    _tasks = widget.initialTasks != null
        ? List.from(widget.initialTasks!)
        : [
            'Revise Spring Security',
            'Gym',
            'Read 20 pages',
            'Walk 20 min',
          ];

    _initializePlacements();
  }

  @override
  void dispose() {
    _taskInputController.dispose();
    _taskInputFocus.dispose();
    super.dispose();
  }

  int _getSpanDays() {
    switch (_selectedSpan) {
      case '1d':
        return 1;
      case '3d':
        return 3;
      case '7d':
        return 7;
      case '14d':
        return 14;
      case 'repeating':
        return 7;
      default:
        return 3;
    }
  }

  void _initializePlacements() {
    final spanDays = _getSpanDays();
    final times = ['morning', 'afternoon', 'evening'];
    for (var i = 0; i < _tasks.length; i++) {
      if (!_placements.containsKey(i)) {
        _placements[i] = _TaskPlacement(
          days: {i % spanDays},
          timeOfDay: times[i % times.length],
        );
      }
    }
  }

  void _spreadEvenly() {
    HapticFeedback.lightImpact();
    final spanDays = _getSpanDays();
    final times = ['morning', 'afternoon', 'evening'];

    setState(() {
      for (var i = 0; i < _tasks.length; i++) {
        final assignedDay = i % spanDays;
        final assignedTime = times[(i ~/ spanDays) % times.length];
        _placements[i] = _TaskPlacement(
          days: {assignedDay},
          timeOfDay: assignedTime,
        );
      }
    });
  }

  void _addTask(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    HapticFeedback.selectionClick();

    setState(() {
      final newIndex = _tasks.length;
      _tasks.add(trimmed);
      final spanDays = _getSpanDays();
      final times = ['morning', 'afternoon', 'evening'];
      _placements[newIndex] = _TaskPlacement(
        days: {newIndex % spanDays},
        timeOfDay: times[newIndex % times.length],
      );
    });

    _taskInputController.clear();
    _taskInputFocus.requestFocus();
  }

  void _removeTask(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _tasks.removeAt(index);
      _placements.remove(index);
      // Re-index placements
      final updatedPlacements = <int, _TaskPlacement>{};
      for (var i = 0; i < _tasks.length; i++) {
        updatedPlacements[i] = _placements[i] ??
            _TaskPlacement(
              days: {i % _getSpanDays()},
              timeOfDay: 'morning',
            );
      }
      _placements
        ..clear()
        ..addAll(updatedPlacements);
    });
  }

  int _calculateTotalSessions() {
    var total = 0;
    for (var i = 0; i < _tasks.length; i++) {
      total += _placements[i]?.days.length ?? 1;
    }
    return total;
  }

  DateTime _getTimeForSlot(DateTime date, String timeOfDay, TimeOfDay? exact) {
    if (exact != null) {
      return DateTime(date.year, date.month, date.day, exact.hour, exact.minute);
    }
    switch (timeOfDay) {
      case 'morning':
        return DateTime(date.year, date.month, date.day, 9, 0);
      case 'afternoon':
        return DateTime(date.year, date.month, date.day, 14, 0);
      case 'evening':
        return DateTime(date.year, date.month, date.day, 19, 0);
      default:
        return DateTime(date.year, date.month, date.day, 9, 0);
    }
  }

  Future<void> _handleCreatePlan() async {
    if (_tasks.isEmpty || _isCreating) return;
    HapticFeedback.mediumImpact();
    setState(() => _isCreating = true);

    try {
      final service = ref.read(planCollectionServiceProvider);
      final now = DateTime.now();
      final baseDate = DateTime(now.year, now.month, now.day);
      final spanDays = _getSpanDays();

      final List<PlanItemDraft> drafts = [];

      for (var i = 0; i < _tasks.length; i++) {
        final title = _tasks[i];
        final placement = _placements[i] ?? _TaskPlacement();

        for (final dayOffset in placement.days) {
          final sessionDate = baseDate.add(Duration(days: dayOffset));
          final scheduledAt = _getTimeForSlot(
            sessionDate,
            placement.timeOfDay,
            placement.exactTime,
          );

          drafts.add(
            PlanItemDraft(
              title: title,
              at: scheduledAt,
              recurrence: _selectedSpan == 'repeating' ? 'daily' : 'once',
              alert: _reminderMode == 'off' ? 'none' : 'reminder',
              dateOnly: false,
            ),
          );
        }
      }

      String planTitle;
      switch (_selectedSpan) {
        case '1d':
          planTitle = 'Today\'s Sprint';
          break;
        case '3d':
          planTitle = 'Next 3 Days';
          break;
        case '7d':
          planTitle = 'This Week\'s Plan';
          break;
        case '14d':
          planTitle = '2-Week Horizon';
          break;
        case 'repeating':
          planTitle = 'Daily Routine';
          break;
        default:
          planTitle = 'My Plan';
      }

      final requestId = planningId();
      final collectionId = await service.save(
        title: planTitle,
        items: drafts,
        requestId: requestId,
        description: 'Created with tap-first planner',
      );

      if (!mounted) return;

      // Navigate to dedicated Plan Detail screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PlanDetailScreen(
            collectionId: collectionId,
            planTitle: planTitle,
            spanDays: spanDays,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating plan: $e')),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Step Indicator Bar
            _buildTopBar(context, c, colorScheme),

            // Step Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildCurrentStep(context, c, colorScheme, isDark),
              ),
            ),

            // Bottom Action Bar
            _buildBottomBar(context, c, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    AppColors c,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Close (✕ on Step 1) or Back arrow on Steps 2-4
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              if (_currentStep == 0) {
                Navigator.of(context).pop();
              } else {
                setState(() => _currentStep--);
              }
            },
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
                _currentStep == 0
                    ? Icons.close_rounded
                    : Icons.arrow_back_rounded,
                size: 20,
                color: c.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 4-step dot progress indicator
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isActive = index <= _currentStep;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _currentStep ? 24 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isActive ? colorScheme.primary : c.border,
                  ),
                );
              }),
            ),
          ),

          // Step label (e.g. "1 of 4")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border, width: 1.0),
            ),
            child: Text(
              '${_currentStep + 1} of 4',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(
    BuildContext context,
    AppColors c,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Span(context, c, colorScheme, isDark);
      case 1:
        return _buildStep2Tasks(context, c, colorScheme, isDark);
      case 2:
        return _buildStep3Place(context, c, colorScheme, isDark);
      case 3:
        return _buildStep4Confirm(context, c, colorScheme, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── STEP 1: PICK THE SPAN ──────────────────────────────────────────────────
  Widget _buildStep1Span(
    BuildContext context,
    AppColors c,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final now = DateTime.now();
    final dfMonthDay = DateFormat('EEE d MMM');
    final dfShort = DateFormat('EEE d');

    final todayStr = '${dfMonthDay.format(now)} · one clean sweep';
    final threeDayStr =
        '${dfShort.format(now)} – ${dfMonthDay.format(now.add(const Duration(days: 2)))}';
    final weekStr =
        'Until ${dfMonthDay.format(now.add(const Duration(days: 6)))}';
    final twoWeeksStr =
        'Until ${dfMonthDay.format(now.add(const Duration(days: 13)))}';

    final options = [
      ('1d', 'Today', todayStr, null),
      ('3d', '3 days', threeDayStr, null),
      ('7d', 'This week', weekStr, null),
      ('14d', '2 weeks', twoWeeksStr, null),
      ('repeating', 'Repeating', 'Daily or on days you choose', Icons.repeat_rounded),
    ];

    return KeyedSubtree(
      key: const ValueKey('step_1_span'),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          Text(
            'How long is this plan for?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick one. You can change days later.',
            style: TextStyle(
              fontSize: 15,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Span option tiles
          for (final opt in options) ...[
            _buildSpanTile(
              id: opt.$1,
              title: opt.$2,
              subtitle: opt.$3,
              icon: opt.$4,
              isSelected: _selectedSpan == opt.$1,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedSpan = opt.$1;
                  _initializePlacements();
                });
              },
              c: c,
              colorScheme: colorScheme,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 16, color: c.textTertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alarms, repeats and check-ins have smart defaults. You never have to set them up front.',
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSpanTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColors c,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0x35BF5A36) : colorScheme.primaryContainer.withValues(alpha: 0.35))
              : (isDark ? const Color(0x20222630) : c.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? colorScheme.primary : c.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x25000000) : c.warmShadow,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Badge / Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? colorScheme.primary
                    : (isDark ? const Color(0x30323644) : c.surfaceAlt),
              ),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(
                      icon,
                      size: 20,
                      color: isSelected ? colorScheme.onPrimary : c.textPrimary,
                    )
                  : Text(
                      id,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? colorScheme.onPrimary : c.textPrimary,
                      ),
                    ),
            ),
            const SizedBox(width: 14),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Checkmark indicator
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: colorScheme.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── STEP 2: ADD WHAT YOU WANT TO DO ────────────────────────────────────────
  Widget _buildStep2Tasks(
    BuildContext context,
    AppColors c,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return KeyedSubtree(
      key: const ValueKey('step_2_tasks'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What do you want to do?',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add tasks one by one. Tap a suggestion to skip typing.',
                  style: TextStyle(
                    fontSize: 15,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Rapid Task Input with '+' action button
                AppTextField(
                  controller: _taskInputController,
                  focusNode: _taskInputFocus,
                  hintText: 'Add a task',
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (val) => _addTask(val),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.add_circle_rounded,
                      color: colorScheme.primary,
                      size: 26,
                    ),
                    onPressed: () => _addTask(_taskInputController.text),
                  ),
                ),
                const SizedBox(height: 12),

                // Suggestion chips row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final suggestion in _suggestionChips) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(
                              suggestion,
                              style: TextStyle(
                                fontSize: 13,
                                color: c.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            backgroundColor:
                                isDark ? const Color(0x302A2E3B) : c.surfaceAlt,
                            side: BorderSide(color: c.border, width: 1.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            onPressed: () => _addTask(suggestion),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Header: "Your tasks" · "N added"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your tasks',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_tasks.length} added',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Reorderable list of task bubbles
          Expanded(
            child: _tasks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No tasks yet. Type above or tap a suggestion chip.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: c.textTertiary,
                        ),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 4),
                    itemCount: _tasks.length,
                    // ignore: deprecated_member_use
                    onReorder: (oldIndex, newIndex) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (oldIndex < newIndex) newIndex -= 1;
                        final item = _tasks.removeAt(oldIndex);
                        _tasks.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final taskTitle = _tasks[index];
                      return Container(
                        key: ValueKey('task_bubble_${index}_$taskTitle'),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0x28222632)
                              : c.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.border, width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0x20000000)
                                  : c.warmShadow,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.drag_indicator_rounded,
                              size: 18,
                              color: c.textTertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                taskTitle,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: c.textSecondary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              onPressed: () => _removeTask(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── STEP 3: PLACE THEM WITH TAPS ───────────────────────────────────────────
  Widget _buildStep3Place(
    BuildContext context,
    AppColors c,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final spanDays = _getSpanDays();
    final now = DateTime.now();
    final dfShort = DateFormat('EEE d');

    final dayLabels = List.generate(spanDays, (i) {
      final d = now.add(Duration(days: i));
      return i == 0 ? 'Today' : dfShort.format(d);
    });

    return KeyedSubtree(
      key: const ValueKey('step_3_place'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'When will you do each?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the days, then a time of day.',
                            style: TextStyle(
                              fontSize: 14,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // "Spread evenly" button
                    TextButton.icon(
                      onPressed: _spreadEvenly,
                      icon: Icon(
                        Icons.auto_fix_high_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      label: Text(
                        'Spread evenly',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Placement Cards
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final taskTitle = _tasks[index];
                final placement = _placements[index] ?? _TaskPlacement();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x28222632) : c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? const Color(0x20000000) : c.warmShadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        taskTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Day pills row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var dayIdx = 0;
                                dayIdx < dayLabels.length;
                                dayIdx++) ...[
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _buildChoicePill(
                                  label: dayLabels[dayIdx],
                                  isSelected: placement.days.contains(dayIdx),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      if (placement.days.contains(dayIdx)) {
                                        if (placement.days.length > 1) {
                                          placement.days.remove(dayIdx);
                                        }
                                      } else {
                                        placement.days.add(dayIdx);
                                      }
                                    });
                                  },
                                  c: c,
                                  colorScheme: colorScheme,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Time of day segmented row (Morning, Afternoon, Evening)
                      Row(
                        children: [
                          _buildTimeSlotPill(
                            slot: 'morning',
                            label: 'Morning',
                            dotColor: const Color(0xFFC99A3C), // soft gold
                            isSelected: placement.timeOfDay == 'morning',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => placement.timeOfDay = 'morning');
                            },
                            c: c,
                            colorScheme: colorScheme,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildTimeSlotPill(
                            slot: 'afternoon',
                            label: 'Afternoon',
                            dotColor: const Color(0xFF3563E9), // dusk blue
                            isSelected: placement.timeOfDay == 'afternoon',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => placement.timeOfDay = 'afternoon');
                            },
                            c: c,
                            colorScheme: colorScheme,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _buildTimeSlotPill(
                            slot: 'evening',
                            label: 'Evening',
                            dotColor: const Color(0xFF6B5BD6), // twilight
                            isSelected: placement.timeOfDay == 'evening',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => placement.timeOfDay = 'evening');
                            },
                            c: c,
                            colorScheme: colorScheme,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoicePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColors c,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : (isDark ? const Color(0x302A2E3B) : c.surfaceAlt),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : c.border,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? colorScheme.onPrimary : c.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlotPill({
    required String slot,
    required String label,
    required Color dotColor,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColors c,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0x35BF5A36) : colorScheme.primaryContainer)
                : (isDark ? const Color(0x252A2E3B) : c.surfaceAlt),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colorScheme.primary : c.border,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STEP 4: CONFIRM ────────────────────────────────────────────────────────
  Widget _buildStep4Confirm(
    BuildContext context,
    AppColors c,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final spanDays = _getSpanDays();
    final now = DateTime.now();
    final dfShort = DateFormat('EEE d');
    final totalSessions = _calculateTotalSessions();

    return KeyedSubtree(
      key: const ValueKey('step_4_confirm'),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          Text(
            'Looks good?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_tasks.length} tasks · $totalSessions sessions across $spanDays days',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),

          // Day breakdown cards
          for (var dayIdx = 0; dayIdx < spanDays; dayIdx++) ...[
            _buildDayBreakdownCard(
              dayIdx: dayIdx,
              date: now.add(Duration(days: dayIdx)),
              dfShort: dfShort,
              c: c,
              colorScheme: colorScheme,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 16),
          // Reminders Segment
          Text(
            'Reminders',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x30222632) : c.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border, width: 1.0),
            ),
            child: Row(
              children: [
                _buildReminderSegOption('off', 'Off', c, colorScheme),
                _buildReminderSegOption(
                    'morning', 'Morning nudge', c, colorScheme),
                _buildReminderSegOption(
                    'exact', 'At task time', c, colorScheme),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _reminderMode == 'morning'
                ? 'One gentle notification at 8:00 am with the day\'s tasks.'
                : _reminderMode == 'exact'
                    ? 'Notifications scheduled at the start of each session.'
                    : 'No notifications will be scheduled.',
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReminderSegOption(
    String mode,
    String label,
    AppColors c,
    ColorScheme colorScheme,
  ) {
    final isSelected = _reminderMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _reminderMode = mode);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? colorScheme.onPrimary : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayBreakdownCard({
    required int dayIdx,
    required DateTime date,
    required DateFormat dfShort,
    required AppColors c,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    final dayLabel = dayIdx == 0 ? 'Today' : dfShort.format(date);
    // Gather tasks scheduled on this day
    final dayTasks = <(String, String)>[];
    for (var i = 0; i < _tasks.length; i++) {
      final p = _placements[i];
      if (p != null && p.days.contains(dayIdx)) {
        dayTasks.add((_tasks[i], p.timeOfDay));
      }
    }

    if (dayTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x28222632) : c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              Text(
                '${dayTasks.length} tasks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (taskTitle, timeOfDay) in dayTasks) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: timeOfDay == 'morning'
                          ? const Color(0xFFC99A3C)
                          : timeOfDay == 'afternoon'
                              ? const Color(0xFF3563E9)
                              : const Color(0xFF6B5BD6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      taskTitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    timeOfDay[0].toUpperCase() + timeOfDay.substring(1),
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── BOTTOM ACTION BAR ──────────────────────────────────────────────────────
  Widget _buildBottomBar(
    BuildContext context,
    AppColors c,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(
          top: BorderSide(color: c.border, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            // Quiet "Back" button
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _currentStep--);
              },
              child: Text(
                'Back',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary,
                ),
              ),
            ),
            const Spacer(),
          ] else ...[
            const Spacer(),
          ],

          // Primary Action CTA
          FilledButton(
            onPressed: _currentStep == 3
                ? (_isCreating ? null : _handleCreatePlan)
                : () {
                    HapticFeedback.selectionClick();
                    setState(() => _currentStep++);
                  },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isCreating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CupertinoActivityIndicator(
                      radius: 10,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Text(
                    _currentStep == 3 ? 'Create plan' : 'Next',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
