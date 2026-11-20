import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/plan_collection_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../plan_progress.dart';
import '../widgets/plan_progress_card.dart';
import '../planning_providers.dart';

class PlanDetailScreen extends ConsumerStatefulWidget {
  const PlanDetailScreen({
    super.key,
    required this.collectionId,
    this.planTitle = 'Plan Detail',
    this.spanDays = 3,
  });

  final String collectionId;
  final String planTitle;
  final int spanDays;

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  final TextEditingController _quickAddController = TextEditingController();
  final FocusNode _quickAddFocus = FocusNode();
  bool _isAdding = false;

  @override
  void dispose() {
    _quickAddController.dispose();
    _quickAddFocus.dispose();
    super.dispose();
  }

  Future<void> _handleQuickAdd() async {
    final text = _quickAddController.text.trim();
    if (text.isEmpty || _isAdding) return;

    HapticFeedback.selectionClick();
    setState(() => _isAdding = true);

    try {
      final service = ref.read(planCollectionServiceProvider);
      final now = DateTime.now();
      await service.save(
        title: widget.planTitle,
        collectionId: widget.collectionId,
        requestId: planningId(),
        items: [
          PlanItemDraft(
            title: text,
            at: now.add(const Duration(hours: 1)),
            alert: 'reminder',
          ),
        ],
      );
      _quickAddController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding item: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _toggleItemStatus(PlanItemView item) async {
    HapticFeedback.lightImpact();
    try {
      if (item.taskId != null) {
        final db = ref.read(planCollectionServiceProvider).db;
        await db.taskDao.toggleTaskCompletion(item.taskId!, !item.done);
      }
    } catch (_) {}
  }

  Future<void> _deletePlan() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan'),
        content: const Text(
          'Are you sure you want to delete this plan? All scheduled occurrences and reminders will be removed.',
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
      final service = ref.read(planCollectionServiceProvider);
      await service.deleteCollection(widget.collectionId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final itemsAsync = ref.watch(planItemsProvider(widget.collectionId));
    final collectionsAsync = ref.watch(planCollectionsProvider);

    final currentCollection = collectionsAsync.value
        ?.where((col) => col.id == widget.collectionId)
        .firstOrNull;

    final now = DateTime.now();
    final dfFull = DateFormat('EEE d MMM');
    final dfShort = DateFormat('EEE d');

    final displayTitle = currentCollection?.title ?? widget.planTitle;
    final total = currentCollection?.total ?? 0;
    final done = currentCollection?.done ?? 0;

    // Real dates from the plan's sessions, not from today.
    final sessions = ref.watch(planSessionsProvider(widget.collectionId)).value;
    final progress = sessions == null || sessions.isEmpty
        ? null
        : PlanProgress.from(sessions, now);
    final String dateRangeStr;
    if (progress?.first != null) {
      final day = progress!.dayNumber;
      final lead = day <= 0
          ? 'Starts ${dfShort.format(progress.first!)}'
          : day >= progress.totalDays
          ? 'Last day'
          : 'Day $day of ${progress.totalDays}';
      dateRangeStr =
          '$lead · ${dfShort.format(progress.first!)} – ${dfFull.format(progress.last!)}';
    } else {
      dateRangeStr = 'No scheduled sessions yet';
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
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
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: c.border, width: 1.0),
                    ),
                    color: isDark
                        ? const Color(0xFF16181E)
                        : const Color(0xFFFFFDF9),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: c.textSecondary,
                    ),
                    onSelected: (val) {
                      if (val == 'delete') {
                        _deletePlan();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete plan',
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Title & Subtitle
                  Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateRangeStr,
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PlanProgressCard(collectionId: widget.collectionId),
                  const SizedBox(height: 16),

                  // Circular Progress Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x28222632) : c.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: c.border, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0x20000000)
                              : c.warmShadow,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Progress Ring
                        SizedBox(
                          width: 68,
                          height: 68,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: total > 0 ? (done / total) : 0.0,
                                strokeWidth: 6,
                                backgroundColor: isDark
                                    ? const Color(0x25FFFFFF)
                                    : c.surfaceAlt,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                              Text(
                                '$done/$total',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                done == total && total > 0
                                    ? 'All completed!'
                                    : 'Good start',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                total > done
                                    ? '${total - done} sessions remaining across your horizon.'
                                    : 'Every session accomplished cleanly.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Add Field
                  AppTextField(
                    controller: _quickAddController,
                    focusNode: _quickAddFocus,
                    hintText: 'Add to this plan',
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleQuickAdd(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.add_circle_rounded,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      onPressed: _handleQuickAdd,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Today Section
                  Text(
                    'Today · ${dfShort.format(now)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  itemsAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x20222632) : c.surfaceAlt,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'No items in this plan yet.',
                            style: TextStyle(
                              fontSize: 14,
                              color: c.textTertiary,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (final item in items) ...[
                            _buildTaskItemTile(
                              item: item,
                              onToggle: () => _toggleItemStatus(item),
                              c: c,
                              colorScheme: colorScheme,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading items: $err'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Coming Up Section
                  if (widget.spanDays > 1) ...[
                    Text(
                      'Coming up',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var dayOffset = 1;
                        dayOffset < widget.spanDays;
                        dayOffset++) ...[
                      _buildUpcomingDayTile(
                        date: now.add(Duration(days: dayOffset)),
                        dfShort: dfShort,
                        c: c,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItemTile({
    required PlanItemView item,
    required VoidCallback onToggle,
    required AppColors c,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    final isDone = item.done;
    final timeStr = item.at != null ? DateFormat('h:mm a').format(item.at!) : '';

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x28222632) : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 1.0),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isDone ? colorScheme.primary : c.border,
                  width: 1.5,
                ),
              ),
              child: isDone
                  ? Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: colorScheme.onPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDone ? c.textTertiary : c.textPrimary,
                  decoration:
                      isDone ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
            ),

            if (timeStr.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x302A2E3B) : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingDayTile({
    required DateTime date,
    required DateFormat dfShort,
    required AppColors c,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x28222632) : c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dfShort.format(date),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          Row(
            children: [
              Text(
                'Lined up',
                style: TextStyle(
                  fontSize: 13,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: c.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
