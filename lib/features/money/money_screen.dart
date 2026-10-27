import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_scaffold.dart';
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

  Widget _transactionRow(FinanceTransaction tx) {
    final g = context.glass;
    final isExpense = tx.type == 'expense';
    final categoryColor = _categoryColor(context, tx.category);
    return Padding(
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
            tooltip: 'Delete transaction',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: g.inkMuted,
            ),
            onPressed: () async {
              await ref.read(financeDaoProvider).deleteTransaction(tx.id);
            },
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController();
    final savedController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppGeometry.radiusr24),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpace.s20,
          right: AppSpace.s20,
          top: AppSpace.s20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpace.s24,
        ),
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
                  child: AscentButton.primary(
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

    final g = context.glass;

    return AscentScaffold(
      title: 'Money & Budgets',
      subtitle: 'Personal ledger & savings goals',
      glow2: g.amberSoft,
      actions: [
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

              const SizedBox(height: 20),

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
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in days.entries)
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
                                Text(
                                  g.title,
                                  style: AscentTextStyles.headlineMedium
                                      .copyWith(color: context.textPrimary)
                                      .merge(AppTypeRoles.typeRole10),
                                ),
                                Text(
                                  '${(percent * 100).toInt()}%',
                                  style: AscentTextStyles.monoCode
                                      .copyWith(color: context.accentPrimary)
                                      .merge(AppTypeRoles.typeRole9),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₹${g.savedAmount.toStringAsFixed(0)} of ₹${g.targetAmount.toStringAsFixed(0)}',
                                  style: AscentTextStyles.bodySmall.copyWith(
                                    color: context.textMuted,
                                  ),
                                ),
                                Row(
                                  children: [
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
                                      onPressed: () => ref
                                          .read(financeDaoProvider)
                                          .deleteSavingsGoal(g.id),
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
