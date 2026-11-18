import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import '../../shared/widgets/history_action.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_dialog.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_switch.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/empty_state.dart';
import 'add_transaction_sheet.dart';
import 'budget_settings_sheet.dart';

class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _showAllTransactions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleExpenseReminder(bool enable, Reminder? existingReminder) async {
    final db = ref.read(databaseProvider);
    HapticFeedback.lightImpact();
    if (existingReminder != null) {
      await db.reminderDao.updateReminder(
        ReminderTableCompanion(
          id: drift.Value(existingReminder.id),
          isActive: drift.Value(enable),
          alertSyncPending: const drift.Value(true),
        ),
      );
      if (mounted) {
        AscentSnackBar.show(
          context,
          message: enable
              ? 'Evening expense reflection reminder enabled'
              : 'Evening expense reflection reminder paused',
          icon: enable ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
        );
      }
    } else if (enable) {
      final now = DateTime.now();
      var scheduled = DateTime(now.year, now.month, now.day, 21, 0); // 9:00 PM
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Evening Expense Reflection · Mindful Check-In 🌙',
          scheduledAt: scheduled,
          isActive: const drift.Value(true),
          alertSyncPending: const drift.Value(true),
        ),
      );
      if (mounted) {
        AscentSnackBar.show(
          context,
          message: 'Daily expense check-in scheduled for 9:00 PM',
          icon: Icons.alarm_on_rounded,
        );
      }
    }
  }

  Future<void> _scheduleBillReminder(FinanceTransaction tx) async {
    final db = ref.read(databaseProvider);
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final scheduled = DateTime(now.year, now.month, now.day, 10, 0).add(const Duration(days: 3));
    await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'Bill Due: ${tx.title} (₹${tx.amount.toStringAsFixed(0)})',
        scheduledAt: scheduled,
        isActive: const drift.Value(true),
        alertSyncPending: const drift.Value(true),
      ),
    );
    if (mounted) {
      AscentSnackBar.show(
        context,
        message: 'Reminder scheduled for ${tx.title}',
        icon: Icons.notifications_active_outlined,
      );
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Food & Groceries':
        return Icons.restaurant_outlined;
      case 'Transport':
        return Icons.directions_subway_outlined;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Education':
        return Icons.school_outlined;
      case 'Bills & Subscriptions':
        return Icons.receipt_long_outlined;
      case 'Health':
        return Icons.favorite_outline_rounded;
      case 'Entertainment':
        return Icons.movie_outlined;
      case 'Savings':
        return Icons.savings_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  Color _categoryColor(BuildContext context, String category) {
    final g = context.glass;
    switch (category) {
      case 'Food & Groceries':
        return g.clay;
      case 'Transport':
        return g.slate;
      case 'Shopping':
        return g.amber;
      case 'Education':
        return g.slate;
      case 'Bills & Subscriptions':
        return g.coral;
      case 'Health':
        return g.sage;
      case 'Entertainment':
        return g.clay;
      case 'Savings':
        return g.sage;
      default:
        return g.inkMuted;
    }
  }

  Future<void> _deleteTransaction(FinanceTransaction tx) async {
    await ref.read(financeDaoProvider).deleteTransaction(tx.id);
    if (mounted) {
      AscentSnackBar.undo(
        context,
        message: '${tx.title} removed',
        onUndo: () async {
          await ref.read(financeDaoProvider).insertTransaction(
            FinanceTransactionTableCompanion.insert(
              id: drift.Value(tx.id),
              title: tx.title,
              amount: tx.amount,
              date: tx.date,
              type: drift.Value(tx.type),
              category: drift.Value(tx.category),
              account: drift.Value(tx.account),
              notes: drift.Value(tx.notes),
              isRecurring: drift.Value(tx.isRecurring),
            ),
          );
        },
      );
    }
  }

  Future<void> _deleteSavingsGoal(SavingsGoal goal) async {
    await ref.read(financeDaoProvider).deleteSavingsGoal(goal.id);
    if (mounted) {
      AscentSnackBar.undo(
        context,
        message: 'Goal "${goal.title}" removed',
        onUndo: () async {
          await ref.read(financeDaoProvider).insertSavingsGoal(
            SavingsGoalTableCompanion.insert(
              id: drift.Value(goal.id),
              title: goal.title,
              targetAmount: goal.targetAmount,
              savedAmount: drift.Value(goal.savedAmount),
              targetDate: drift.Value(goal.targetDate),
            ),
          );
        },
      );
    }
  }

  void _showEditGoalDialog(SavingsGoal goal) {
    final titleController = TextEditingController(text: goal.title);
    final targetController = TextEditingController(
      text: goal.targetAmount.truncateToDouble() == goal.targetAmount
          ? goal.targetAmount.toInt().toString()
          : goal.targetAmount.toString(),
    );

    showAscentCenteredForm<void>(
      context: context,
      maxWidth: 420,
      builder: (ctx) => Material(
        color: ctx.bgSurface,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Savings Goal',
                    style: AscentTextStyles.displaySmall
                        .copyWith(color: context.textPrimary)
                        .merge(AppTypeRoles.typeRole1),
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
                decoration: InputDecoration(
                  labelText: 'Goal Title',
                  filled: true,
                  fillColor: context.bgBase,
                  border: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Target Amount (₹)',
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: context.bgBase,
                  border: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                    child: AscentButton.tonal(
                      label: 'Save Changes',
                      compact: true,
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final target = double.tryParse(targetController.text.trim());
                        if (title.isNotEmpty && target != null && target > 0) {
                          await ref.read(financeDaoProvider).updateSavingsGoal(
                            SavingsGoalTableCompanion(
                              id: drift.Value(goal.id),
                              title: drift.Value(title),
                              targetAmount: drift.Value(target),
                              savedAmount: drift.Value(goal.savedAmount),
                              targetDate: drift.Value(goal.targetDate),
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

  void _showDepositWithdrawDialog(SavingsGoal goal) {
    final amountController = TextEditingController();
    bool isDeposit = true;

    showAscentCenteredForm<void>(
      context: context,
      maxWidth: 420,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Material(
          color: ctx.bgSurface,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fund Goal',
                      style: AscentTextStyles.displaySmall
                          .copyWith(color: context.textPrimary)
                          .merge(AppTypeRoles.typeRole1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${goal.title} · ₹${goal.savedAmount.toStringAsFixed(0)} of ₹${goal.targetAmount.toStringAsFixed(0)}',
                  style: TextStyle(color: context.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                AscentSegmentedControl<bool>(
                  segments: const [
                    AscentSegment(value: true, label: 'Deposit (+)'),
                    AscentSegment(value: false, label: 'Withdraw (−)'),
                  ],
                  selected: isDeposit,
                  accented: true,
                  onChanged: (val) => setDialogState(() => isDeposit = val),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isDeposit ? 'Deposit Amount (₹)' : 'Withdraw Amount (₹)',
                    prefixText: '₹ ',
                    filled: true,
                    fillColor: context.bgBase,
                    border: OutlineInputBorder(
                      borderRadius: AppGeometry.roundedr12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: [500, 1000, 2000].map((amt) => ActionChip(
                    label: Text('+₹$amt', style: const TextStyle(fontSize: 12)),
                    onPressed: () => setDialogState(() {
                      amountController.text = '$amt';
                    }),
                  )).toList(),
                ),
                const SizedBox(height: 18),
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
                      child: AscentButton.tonal(
                        label: isDeposit ? 'Add Funds' : 'Withdraw',
                        compact: true,
                        onPressed: () async {
                          final amt = double.tryParse(amountController.text.trim());
                          if (amt != null && amt > 0) {
                            final newTotal = isDeposit
                                ? goal.savedAmount + amt
                                : (goal.savedAmount - amt).clamp(0.0, double.infinity);
                            await ref.read(financeDaoProvider).updateSavingsGoal(
                              SavingsGoalTableCompanion(
                                id: drift.Value(goal.id),
                                title: drift.Value(goal.title),
                                targetAmount: drift.Value(goal.targetAmount),
                                savedAmount: drift.Value(newTotal),
                                targetDate: drift.Value(goal.targetDate),
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
      ),
    );
  }

  Widget _transactionRow(FinanceTransaction tx) {
    final g = context.glass;
    final isExpense = tx.type == 'expense';
    final categoryColor = _categoryColor(context, tx.category);
    return InkWell(
      onTap: () => AddTransactionSheet.show(context, transactionToEdit: tx),
      borderRadius: AppGeometry.roundedr10,
      child: Padding(
        key: ValueKey('transaction_${tx.id}'),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: .12),
                borderRadius: AppGeometry.roundedr10,
              ),
              child: Icon(
                _categoryIcon(tx.category),
                color: categoryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: g.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        tx.category,
                        style: TextStyle(color: g.inkMuted, fontSize: 12),
                      ),
                      Text(
                        tx.account,
                        style: TextStyle(color: g.inkMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${isExpense ? '−' : '+'}₹${tx.amount.toStringAsFixed(0)}',
                    style: AscentTextStyles.monoCode.copyWith(
                      color: isExpense ? g.coral : g.sage,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit transaction',
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: g.inkMuted,
              ),
              onPressed: () => AddTransactionSheet.show(
                context,
                transactionToEdit: tx,
              ),
            ),
            IconButton(
              tooltip: 'Delete transaction',
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: g.inkMuted,
              ),
              onPressed: () => _deleteTransaction(tx),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final savedController = TextEditingController();

    showAscentCenteredForm<void>(
      context: context,
      maxWidth: 420,
      builder: (ctx) => Material(
        color: ctx.bgSurface,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Savings Goal',
                    style: AscentTextStyles.displaySmall
                        .copyWith(color: context.textPrimary)
                        .merge(AppTypeRoles.typeRole1),
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
                decoration: InputDecoration(
                  labelText: 'Goal Title',
                  hintText: 'e.g. Emergency Fund, Laptop, Course',
                  filled: true,
                  fillColor: context.bgBase,
                  border: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Target Amount (₹)',
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: context.bgBase,
                  border: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: savedController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Currently Saved (₹, optional)',
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: context.bgBase,
                  border: OutlineInputBorder(
                    borderRadius: AppGeometry.roundedr12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                    child: AscentButton.tonal(
                      label: 'Create Goal',
                      compact: true,
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final target = double.tryParse(
                          targetController.text.trim(),
                        );
                        final saved =
                            double.tryParse(savedController.text.trim()) ?? 0.0;
                        if (title.isNotEmpty && target != null && target > 0) {
                          await ref
                              .read(financeDaoProvider)
                              .insertSavingsGoal(
                                SavingsGoalTableCompanion.insert(
                                  title: title,
                                  targetAmount: target,
                                  savedAmount: drift.Value(saved),
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
    final now = DateTime.now();
    final todaySpendAsync = ref.watch(todaySpendingStreamProvider);
    final monthSpendAsync = ref.watch(currentMonthSpendingStreamProvider);
    final monthIncomeAsync = ref.watch(currentMonthIncomeStreamProvider);
    final budgetAsync = ref.watch(overallBudgetStreamProvider);
    final recentTxAsync = ref.watch(recentTransactionsStreamProvider);
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);
    final remindersAsync = ref.watch(allRemindersProvider);
    final reminders = remindersAsync.value ?? const [];
    final expenseReminder = reminders
        .where((r) => r.title.contains('Expense') || r.title.contains('Spend'))
        .firstOrNull;
    final isExpenseReminderActive =
        expenseReminder != null && expenseReminder.isActive;

    final todaySpend = todaySpendAsync.value ?? 0.0;
    final monthSpend = monthSpendAsync.value ?? 0.0;
    final monthIncome = monthIncomeAsync.value ?? 0.0;
    final budget = budgetAsync.value;
    final monthlyLimit = budget?.monthlyLimit ?? 15000.0;
    final remainingBudget = (monthlyLimit - monthSpend).clamp(
      0.0,
      double.infinity,
    );
    final budgetProgress = (monthSpend / monthlyLimit).clamp(0.0, 1.0);

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = math.max(1, daysInMonth - now.day + 1);
    final safeDailySpend = (remainingBudget / daysRemaining).clamp(
      0.0,
      double.infinity,
    );
    final safeRemainingToday = (safeDailySpend - todaySpend).clamp(
      0.0,
      double.infinity,
    );
    final isMindfulPace = todaySpend <= safeDailySpend;

    final g = context.glass;

    return AscentScaffold(
      title: 'Money & Budgets',
      subtitle: 'Personal ledger & savings goals',
      glow2: g.amberSoft,
      actions: [
        const HistoryAction(module: 'money'),
        IconButton(
          icon: Icon(Icons.tune_outlined, color: g.ink),
          tooltip: 'Budget Limits',
          onPressed: () =>
              BudgetSettingsSheet.show(context, currentBudget: budget),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: g.clay,
        unselectedLabelColor: g.inkMuted,
        indicatorColor: g.clay,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppPalette.transparent,
        tabs: const [
          Tab(text: 'Transactions & Trends'),
          Tab(text: 'Budgets & Goals'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 0: Transactions & Trends ─────────────────────────────────
          ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s20,
              vertical: AppSpace.s16,
            ),
            children: [
              // Safe to Spend Velocity Card
              AscentCard(
                margin: const EdgeInsets.only(bottom: AppSpace.s16),
                padding: const EdgeInsets.all(AppSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (isMindfulPace ? g.sage : g.amber)
                                .withValues(alpha: 0.14),
                            borderRadius: AppGeometry.roundedr10,
                          ),
                          child: Icon(
                            isMindfulPace
                                ? Icons.spa_outlined
                                : Icons.speed_rounded,
                            color: isMindfulPace ? g.sage : g.amber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Safe to Spend Today',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: g.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                '$daysRemaining days remaining in ${DateFormat('MMMM').format(now)}',
                                style: TextStyle(
                                  color: g.inkMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        AppTag(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s8,
                            vertical: AppSpace.s3,
                          ),
                          nightDecoration: BoxDecoration(
                            color: (isMindfulPace ? g.sage : g.amber)
                                .withValues(alpha: 0.15),
                            borderRadius: AppGeometry.roundedr6,
                          ),
                          child: Text(
                            isMindfulPace
                                ? 'Mindful Pace 🍃'
                                : 'Adjusting Pace ⚡',
                            style: AppTypeRoles.typeRole34.copyWith(
                              color: isMindfulPace ? g.sage : g.amber,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '₹${safeRemainingToday.toStringAsFixed(0)}',
                          style: AscentTextStyles.displaySmall
                              .copyWith(
                                color: isMindfulPace ? g.sage : g.coral,
                                fontWeight: FontWeight.w800,
                              )
                              .merge(AppTypeRoles.typeRole45),
                        ),
                        Text(
                          'available today (₹${safeDailySpend.toStringAsFixed(0)}/day allowance)',
                          style: AscentTextStyles.bodySmall.copyWith(
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isMindfulPace
                          ? 'You are pacing mindfully within your monthly budget.'
                          : 'Spending is ahead of daily pace. Prioritize essentials.',
                      style: TextStyle(
                        color: g.inkMuted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Hero Balance Card
              AscentCard(
                padding: const EdgeInsets.all(AppSpace.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          DateFormat('MMMM y').format(now).toUpperCase(),
                          style: AscentTextStyles.labelSmall
                              .copyWith(
                                color: context.textMuted,
                                letterSpacing: 1.2,
                              )
                              .merge(AppTypeRoles.typeRole9),
                        ),
                        AppTag(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s8,
                            vertical: AppSpace.s3,
                          ),
                          nightDecoration: BoxDecoration(
                            color: (monthSpend > monthlyLimit)
                                ? context.stateDanger.withValues(alpha: 0.15)
                                : context.accentSecondary.withValues(
                                    alpha: 0.12,
                                  ),
                            borderRadius: AppGeometry.roundedr6,
                          ),
                          child: Text(
                            monthSpend > monthlyLimit
                                ? 'Over Budget'
                                : 'On Track',
                            style: AppTypeRoles.typeRole34.copyWith(
                              color: (monthSpend > monthlyLimit)
                                  ? context.stateDanger
                                  : context.accentSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '₹${monthSpend.toStringAsFixed(0)}',
                          style: AscentTextStyles.displaySmall
                              .copyWith(color: context.textPrimary)
                              .merge(AppTypeRoles.typeRole45),
                        ),
                        Text(
                          'spent this month',
                          style: AscentTextStyles.bodyMedium.copyWith(
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Progress bar
                    ClipRRect(
                      borderRadius: AppGeometry.roundedr6,
                      child: LinearProgressIndicator(
                        value: budgetProgress,
                        minHeight: 7,
                        backgroundColor: context.bgBase,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          monthSpend > monthlyLimit
                              ? context.stateDanger
                              : context.accentSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Remaining: ₹${remainingBudget.toStringAsFixed(0)}',
                          style: AscentTextStyles.bodySmall
                              .copyWith(color: context.textPrimary)
                              .merge(AppTypeRoles.typeRole8),
                        ),
                        Text(
                          'Income: ₹${monthIncome.toStringAsFixed(0)}',
                          style: AscentTextStyles.bodySmall
                              .copyWith(color: g.sage)
                              .merge(AppTypeRoles.typeRole8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: g.line),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's spend",
                              style: TextStyle(color: g.inkMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${todaySpend.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: g.coral,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        AscentButton.primary(
                          icon: Icons.add_rounded,
                          label: 'Add Expense',
                          expanded: false,
                          onPressed: () => AddTransactionSheet.show(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Spending by Category Breakdown
              StreamBuilder<Map<String, double>>(
                stream: ref
                    .watch(financeDaoProvider)
                    .watchCategorySpending(now.year, now.month),
                builder: (context, snapshot) {
                  final catMap = snapshot.data ?? const {};
                  if (catMap.isEmpty) return const SizedBox.shrink();
                  final totalCategorySpend = catMap.values.fold<double>(
                    0.0,
                    (sum, val) => sum + val,
                  );
                  final sorted = catMap.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  return AscentCard(
                    margin: const EdgeInsets.only(bottom: AppSpace.s16),
                    padding: const EdgeInsets.all(AppSpace.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: g.clay.withValues(alpha: 0.12),
                                borderRadius: AppGeometry.roundedr8,
                              ),
                              child: Icon(
                                Icons.pie_chart_outline_rounded,
                                color: g.clay,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Spending by Category',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: g.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            Text(
                              '₹${totalCategorySpend.toStringAsFixed(0)}',
                              style: AscentTextStyles.monoCode.copyWith(
                                color: g.inkSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final entry in sorted.take(4)) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _categoryIcon(entry.key),
                                      size: 14,
                                      color: _categoryColor(context, entry.key),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          color: g.ink,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '₹${entry.value.toStringAsFixed(0)} (${totalCategorySpend > 0 ? ((entry.value / totalCategorySpend) * 100).toInt() : 0}%)',
                                      style: TextStyle(
                                        color: g.inkMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: AppGeometry.roundedr6,
                                  child: LinearProgressIndicator(
                                    value: totalCategorySpend > 0
                                        ? (entry.value / totalCategorySpend)
                                            .clamp(0.0, 1.0)
                                        : 0.0,
                                    minHeight: 5,
                                    backgroundColor: context.bgBase,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _categoryColor(context, entry.key),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 4),

              // Recent Transactions Header
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Recent Transactions',
                    style: AscentTextStyles.headlineMedium
                        .copyWith(color: context.textPrimary)
                        .merge(AppTypeRoles.typeRole13),
                  ),
                  Text(
                    'Real-time',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Transactions Stream
              recentTxAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No Transactions Yet',
                      subtitle:
                          'Use Add Expense in the summary to record spending or income.',
                    );
                  }

                  final days = <DateTime, List<FinanceTransaction>>{};
                  for (final tx in transactions) {
                    final day = DateTime(
                      tx.date.year,
                      tx.date.month,
                      tx.date.day,
                    );
                    days.putIfAbsent(day, () => []).add(tx);
                  }

                  final allDayEntries = days.entries.toList();
                  final hasHighVolume =
                      allDayEntries.length > 2 || transactions.length > 6;
                  final visibleEntries = _showAllTransactions
                      ? allDayEntries
                      : allDayEntries.take(2).toList();

                  final recurringBills = transactions
                      .where(
                        (t) =>
                            t.isRecurring ||
                            t.category == 'Bills & Subscriptions',
                      )
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (recurringBills.isNotEmpty)
                        AscentCard(
                          margin: const EdgeInsets.only(bottom: AppSpace.s16),
                          padding: const EdgeInsets.all(AppSpace.s14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.repeat_rounded,
                                    color: g.coral,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Upcoming Bills & Subscriptions',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: g.ink,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              for (final bill in recurringBills.take(3)) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              bill.title,
                                              style: TextStyle(
                                                color: g.ink,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              '₹${bill.amount.toStringAsFixed(0)} · ${bill.category}',
                                              style: TextStyle(
                                                color: g.inkMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Builder(
                                        builder: (context) {
                                          final hasReminder = reminders.any(
                                            (r) =>
                                                r.title.contains(bill.title) &&
                                                r.isActive,
                                          );
                                          if (hasReminder) {
                                            return AppTag(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              nightDecoration: BoxDecoration(
                                                color: g.sage.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    AppGeometry.roundedr6,
                                              ),
                                              child: Text(
                                                'Reminder Set 🔔',
                                                style: TextStyle(
                                                  color: g.sage,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          }
                                          return AscentButton.ghost(
                                            icon: Icons.alarm_add_rounded,
                                            label: 'Remind',
                                            compact: true,
                                            onPressed: () =>
                                                _scheduleBillReminder(bill),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      for (final entry in visibleEntries)
                        AscentCard(
                          key: ValueKey(
                            'transactions_${entry.key.toIso8601String()}',
                          ),
                          margin: const EdgeInsets.only(bottom: AppSpace.s16),
                          padding: const EdgeInsets.all(AppSpace.s14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                DateFormat('EEEE, MMM d, y').format(entry.key),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: g.inkSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              for (var i = 0; i < entry.value.length; i++) ...[
                                if (i > 0) Divider(height: 1, color: g.line),
                                _transactionRow(entry.value[i]),
                              ],
                            ],
                          ),
                        ),

                      // High-Volume Protection: Expand / Collapse Toggle
                      if (hasHighVolume) ...[
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(
                              () =>
                                  _showAllTransactions = !_showAllTransactions,
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _showAllTransactions
                                        ? 'Show Recent Only'
                                        : 'Show All ${transactions.length} Transactions',
                                    style: TextStyle(
                                      color: g.clay,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _showAllTransactions
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: g.clay,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Direct Link to Full Module History
                      AscentCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s16,
                          vertical: AppSpace.s12,
                        ),
                        child: InkWell(
                          onTap: () => context.push('/history?module=money'),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 16,
                                color: g.inkMuted,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'View Full Ledger in History (${transactions.length} records)',
                                  style: TextStyle(
                                    color: g.inkMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpace.s24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) =>
                    Center(child: Text('Error loading transactions: $e')),
              ),
              const SizedBox(height: 32),
            ],
          ),

          // ── Tab 1: Budgets & Savings Goals ───────────────────────────────
          ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s20,
              vertical: AppSpace.s16,
            ),
            children: [
              // Monthly Budget Setting Card
              AscentCard(
                padding: const EdgeInsets.all(AppSpace.s18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Overall Monthly Budget',
                          style: AscentTextStyles.headlineMedium
                              .copyWith(color: context.textPrimary)
                              .merge(AppTypeRoles.typeRole10),
                        ),
                        AscentButton.outlined(
                          label: 'Edit Limit',
                          expanded: false,
                          onPressed: () => BudgetSettingsSheet.show(
                            context,
                            currentBudget: budget,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₹${monthlyLimit.toStringAsFixed(0)} Limit',
                      style: AscentTextStyles.displaySmall
                          .copyWith(color: context.textPrimary)
                          .merge(AppTypeRoles.typeRole46),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daily target: ₹${(budget?.dailyLimit ?? (monthlyLimit / 30)).toStringAsFixed(0)}/day',
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Daily Mindful Expense Check-in Card
              AscentCard(
                padding: const EdgeInsets.all(AppSpace.s16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: g.clay.withValues(alpha: 0.12),
                        borderRadius: AppGeometry.roundedr10,
                      ),
                      child: Icon(
                        Icons.nightlight_round,
                        color: g.clay,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evening Expense Reflection',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: g.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Daily gentle nudge at 9:00 PM to record spending & reflect on mindful choices.',
                            style: TextStyle(
                              color: g.inkMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AscentSwitch(
                      key: const ValueKey('expense_reminder_switch'),
                      value: isExpenseReminderActive,
                      onChanged: (val) =>
                          _toggleExpenseReminder(val, expenseReminder),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Savings Goals Header
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Savings Goals',
                    style: AscentTextStyles.headlineMedium
                        .copyWith(color: context.textPrimary)
                        .merge(AppTypeRoles.typeRole13),
                  ),
                  AscentButton.outlined(
                    icon: Icons.add_rounded,
                    label: 'New Goal',
                    expanded: false,
                    onPressed: _showAddGoalDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              goalsAsync.when(
                data: (goals) {
                  if (goals.isEmpty) {
                    return AscentCard(
                      padding: const EdgeInsets.all(AppSpace.s24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.savings_outlined,
                              size: 36,
                              color: context.accentPrimary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No Savings Goals Added',
                              style: AscentTextStyles.labelLarge.copyWith(
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Set goals for an emergency fund, laptop, or certification.',
                              style: AscentTextStyles.bodySmall.copyWith(
                                color: context.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: goals.map((g) {
                      final percent = (g.savedAmount / g.targetAmount).clamp(
                        0.0,
                        1.0,
                      );
                      return AscentCard(
                        margin: const EdgeInsets.only(bottom: AppSpace.s10),
                        padding: const EdgeInsets.all(AppSpace.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    g.title,
                                    style: AscentTextStyles.headlineMedium
                                        .copyWith(color: context.textPrimary)
                                        .merge(AppTypeRoles.typeRole10),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                        color: context.textMuted,
                                      ),
                                      tooltip: 'Edit goal',
                                      onPressed: () => _showEditGoalDialog(g),
                                    ),
                                    Text(
                                      '${(percent * 100).toInt()}%',
                                      style: AscentTextStyles.monoCode
                                          .copyWith(color: context.accentPrimary)
                                          .merge(AppTypeRoles.typeRole9),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: AppGeometry.roundedr6,
                              child: LinearProgressIndicator(
                                value: percent,
                                minHeight: 6,
                                backgroundColor: context.bgBase,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  context.accentPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Text(
                                  '₹${g.savedAmount.toStringAsFixed(0)} of ₹${g.targetAmount.toStringAsFixed(0)}',
                                  style: AscentTextStyles.bodySmall.copyWith(
                                    color: context.textMuted,
                                  ),
                                ),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 4,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_card_rounded,
                                        size: 16,
                                        color: context.accentPrimary,
                                      ),
                                      tooltip: 'Deposit or withdraw funds',
                                      onPressed: () => _showDepositWithdrawDialog(g),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        // Quick add ₹500 to savings
                                        await ref
                                            .read(financeDaoProvider)
                                            .updateSavingsGoal(
                                              SavingsGoalTableCompanion(
                                                id: drift.Value(g.id),
                                                title: drift.Value(g.title),
                                                targetAmount: drift.Value(
                                                  g.targetAmount,
                                                ),
                                                savedAmount: drift.Value(
                                                  g.savedAmount + 500,
                                                ),
                                              ),
                                            );
                                      },
                                      child: const Text(
                                        '+₹500',
                                        style: AppTypeRoles.typeRole27,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: context.textMuted,
                                      ),
                                      tooltip: 'Delete goal',
                                      onPressed: () => _deleteSavingsGoal(g),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ],
      ),
    );
  }
}
