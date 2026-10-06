import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/empty_state.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  void _openAddEditReminderSheet([Reminder? existing]) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    DateTime scheduledDate = existing?.scheduledAt ?? DateTime.now().add(const Duration(hours: 1));
    TimeOfDay scheduledTime = TimeOfDay.fromDateTime(scheduledDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: bottomInset + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing == null ? 'New Reminder' : 'Edit Reminder',
                          style: AscentTextStyles.displaySmall.copyWith(
                            color: context.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      autofocus: existing == null,
                      style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Reminder Title *',
                        hintText: 'e.g. Apply to Stripe, Review DP notes',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Date & Time',
                      style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(DateFormat('EEE, MMM d').format(scheduledDate)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: scheduledDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  scheduledDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    scheduledTime.hour,
                                    scheduledTime.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(scheduledTime.format(context)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: scheduledTime,
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  scheduledTime = picked;
                                  scheduledDate = DateTime(
                                    scheduledDate.year,
                                    scheduledDate.month,
                                    scheduledDate.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AscentButton.primary(
                      label: existing == null ? 'Set Reminder' : 'Update Reminder',
                      expanded: true,
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;

                        final dao = ref.read(reminderDaoProvider);
                        final fullScheduled = DateTime(
                          scheduledDate.year,
                          scheduledDate.month,
                          scheduledDate.day,
                          scheduledTime.hour,
                          scheduledTime.minute,
                        );

                        if (existing == null) {
                          final id = await dao.insertReminder(
                            ReminderTableCompanion(
                              title: drift.Value(title),
                              scheduledAt: drift.Value(fullScheduled),
                              isActive: const drift.Value(true),
                              createdAt: drift.Value(DateTime.now()),
                            ),
                          );

                          await NotificationService.instance.scheduleReminderNotification(
                            id: id,
                            title: title,
                            scheduledAt: fullScheduled,
                          );
                        } else {
                          await dao.updateReminder(
                            ReminderTableCompanion(
                              id: drift.Value(existing.id),
                              title: drift.Value(title),
                              scheduledAt: drift.Value(fullScheduled),
                              isActive: drift.Value(existing.isActive),
                              createdAt: drift.Value(existing.createdAt),
                            ),
                          );

                          await NotificationService.instance.scheduleReminderNotification(
                            id: existing.id,
                            title: title,
                            scheduledAt: fullScheduled,
                          );
                        }

                        ref.invalidate(allRemindersProvider);
                        ref.invalidate(nextUpcomingReminderProvider);

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(existing == null ? 'Reminder scheduled' : 'Reminder updated'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteReminder(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: Text('Are you sure you want to delete "${reminder.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dao = ref.read(reminderDaoProvider);
      await dao.deleteReminder(reminder.id);
      await NotificationService.instance.cancel(reminder.id);
      ref.invalidate(allRemindersProvider);
      ref.invalidate(nextUpcomingReminderProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(allRemindersProvider);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        title: Text(
          'Reminders & Alerts',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      floatingActionButton: AscentButton.fab(
        icon: Icons.add_rounded,
        onPressed: () => _openAddEditReminderSheet(),
      ),
      body: remindersAsync.when(
        data: (reminders) {
          if (reminders.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No Reminders Yet',
              subtitle: 'Set reminders for upcoming interviews, study blocks, and application deadlines.',
              actionLabel: 'Create Reminder',
              onAction: () => _openAddEditReminderSheet(),
            );
          }

          final now = DateTime.now();
          final upcoming = reminders.where((r) => r.scheduledAt.isAfter(now) && r.isActive).toList();
          final past = reminders.where((r) => !r.scheduledAt.isAfter(now) || !r.isActive).toList();

          return ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
            children: [
              if (upcoming.isNotEmpty) ...[
                Text(
                  'Upcoming (${upcoming.length})',
                  style: AscentTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.accentPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ...upcoming.map((rem) => _buildReminderTile(rem, isUpcoming: true)),
                const SizedBox(height: 20),
              ],
              if (past.isNotEmpty) ...[
                Text(
                  'Past or Completed (${past.length})',
                  style: AscentTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                ...past.map((rem) => _buildReminderTile(rem, isUpcoming: false)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildReminderTile(Reminder reminder, {required bool isUpcoming}) {
    final formattedTime = DateFormat('EEE, MMM d • h:mm a').format(reminder.scheduledAt);

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDeleteReminder(reminder);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      child: AscentCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        onTap: () => _openAddEditReminderSheet(reminder),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isUpcoming
                    ? context.accentSecondary.withValues(alpha: 0.15)
                    : context.divider.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUpcoming ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                size: 20,
                color: isUpcoming ? context.accentSecondary : context.textMuted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: AscentTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isUpcoming ? context.textPrimary : context.textMuted,
                      decoration: isUpcoming ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedTime,
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: isUpcoming ? context.textMuted : context.textMuted.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 20, color: context.textMuted),
              padding: EdgeInsets.zero,
              onSelected: (val) {
                if (val == 'edit') {
                  _openAddEditReminderSheet(reminder);
                } else if (val == 'delete') {
                  _confirmDeleteReminder(reminder);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
