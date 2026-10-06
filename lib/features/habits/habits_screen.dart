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

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  void _showAddHabitDialog() {
    final titleController = TextEditingController();
    String category = 'Health';
    final categories = ['Health', 'Study', 'Fitness', 'Productivity'];

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
    final completedIds = completedIdsAsync.value ?? <int>{};

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

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              final isDoneToday = completedIds.contains(habit.id);

              return FutureBuilder<int>(
                future: ref.read(habitDaoProvider).getStreak(habit.id),
                builder: (context, streakSnap) {
                  final streak = streakSnap.data ?? 0;

                  return AscentCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () async {
                            await ref.read(habitDaoProvider).toggleHabitToday(habit.id);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
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
                                  const SizedBox(width: 6),
                                  Text('•', style: TextStyle(color: context.divider)),
                                  const SizedBox(width: 6),
                                  Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.orange),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$streak-day streak',
                                    style: AscentTextStyles.bodySmall.copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: context.textMuted),
                          onPressed: () => ref.read(habitDaoProvider).deleteHabit(habit.id),
                        ),
                      ],
                    ),
                  );
                },
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
