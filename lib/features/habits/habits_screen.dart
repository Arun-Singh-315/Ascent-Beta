import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/empty_state.dart';

/// Provides a single batch load of all habit streaks (`Map<int, int>`).
/// Replaces the per-item FutureBuilder anti-pattern that called getStreak(id) N times.
final _habitStreaksProvider = FutureProvider.autoDispose<Map<int, int>>((ref) {
  final dao = ref.watch(habitDaoProvider);
  return dao.getAllStreaks();
});

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  void _showAddHabitDialog() {
    final titleController = TextEditingController();
    String category = 'Health';
    final categories = ['Health', 'Study', 'Fitness', 'Productivity', 'Mindfulness'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create New Habit',
                    style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Habit Title',
                  hintText: 'e.g. Read 15 pages, 20 mins meditation, Drink 3L water',
                  filled: true,
                  fillColor: context.bgBase,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Category', style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: categories.map((c) {
                  final isSelected = c == category;
                  return ChoiceChip(
                    label: Text(c),
                    selected: isSelected,
                    selectedColor: context.accentPrimary,
                    backgroundColor: context.bgBase,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : context.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    onSelected: (sel) {
                      if (sel) setSheetState(() => category = c);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AscentButton.outlined(
                      label: 'Cancel',
                      compact: true,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AscentButton.primary(
                      label: 'Save Habit',
                      compact: true,
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isNotEmpty) {
                          await ref.read(habitDaoProvider).insertHabit(
                            HabitTableCompanion.insert(
                              title: title,
                              category: drift.Value(category),
                            ),
                          );
                          // Invalidate streaks so the new habit gets a 0 streak entry
                          ref.invalidate(_habitStreaksProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(allHabitsStreamProvider);
    final completedIdsAsync = ref.watch(todayCompletedHabitIdsStreamProvider);
    // Batch streak load: one DB query for all habits, no FutureBuilder per item
    final streaksAsync = ref.watch(_habitStreaksProvider);

    final completedIds = completedIdsAsync.value ?? <int>{};
    final streaks = streaksAsync.value ?? <int, int>{};

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        title: Text(
          'Daily Habits & Routines',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: context.accentPrimary, size: 28),
            onPressed: _showAddHabitDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: habitsAsync.when(
        data: (habits) {
          if (habits.isEmpty) {
            return EmptyState(
              icon: Icons.checklist_rounded,
              title: 'No Habits Created Yet',
              subtitle: 'Build daily momentum for study, fitness, hydration, and reading.',
              actionLabel: 'Create First Habit',
              onAction: _showAddHabitDialog,
            );
          }

          // Separate active (not completed today) and done habits
          final activeHabits = habits.where((h) => !completedIds.contains(h.id)).toList();
          final doneHabits = habits.where((h) => completedIds.contains(h.id)).toList();
          final allOrdered = [...activeHabits, ...doneHabits];

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: allOrdered.length,
            itemBuilder: (context, index) {
              final habit = allOrdered[index];
              final isDoneToday = completedIds.contains(habit.id);
              // O(1) streak lookup from pre-fetched batch map
              final streak = streaks[habit.id] ?? 0;

              return AscentCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Completion toggle
                    GestureDetector(
                      onTap: () async {
                        await ref.read(habitDaoProvider).toggleHabitToday(habit.id);
                        // Refresh streak after toggle
                        ref.invalidate(_habitStreaksProvider);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDoneToday ? context.accentPrimary : Colors.transparent,
                          border: Border.all(
                            color: isDoneToday ? context.accentPrimary : context.divider,
                            width: 2,
                          ),
                        ),
                        child: isDoneToday
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.title,
                            style: AscentTextStyles.labelLarge.copyWith(
                              color: isDoneToday ? context.textMuted : context.textPrimary,
                              decoration: isDoneToday ? TextDecoration.lineThrough : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                habit.category,
                                style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                              ),
                              if (streak > 0) ...[
                                const SizedBox(width: 6),
                                Text('•', style: TextStyle(color: context.divider)),
                                const SizedBox(width: 6),
                                const Icon(Icons.local_fire_department_rounded, size: 13, color: Colors.orange),
                                const SizedBox(width: 2),
                                Text(
                                  '$streak-day streak',
                                  style: AscentTextStyles.bodySmall.copyWith(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: context.textMuted),
                      onPressed: () async {
                        await ref.read(habitDaoProvider).deleteHabit(habit.id);
                        ref.invalidate(_habitStreaksProvider);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
