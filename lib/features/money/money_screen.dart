import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
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
    switch (category) {
      case 'Food & Groceries':
        return context.accentSecondary;
      case 'Transport':
        return context.accentPrimary;
      case 'Shopping':
        return Colors.purpleAccent;
      case 'Education':
        return Colors.indigoAccent;
      case 'Bills & Subscriptions':
        return Colors.amber;
      case 'Health':
        return context.stateDanger;
      case 'Entertainment':
        return Colors.teal;
      default:
        return context.textMuted;
    }
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
                  'New Savings Goal',
                  style: AscentTextStyles.displaySmall.copyWith(
                    color: context.textPrimary,
                    fontSize: 18,
                  ),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      final target = double.tryParse(targetController.text.trim());
                      final saved = double.tryParse(savedController.text.trim()) ?? 0.0;
                      if (title.isNotEmpty && target != null && target > 0) {
                        await ref.read(financeDaoProvider).insertSavingsGoal(
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
    final remainingBudget = (monthlyLimit - monthSpend).clamp(0.0, double.infinity);
    final budgetProgress = (monthSpend / monthlyLimit).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        title: Text(
          'Money & Budgets',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.tune_outlined, color: context.textPrimary),
            tooltip: 'Budget Limits',
            onPressed: () => BudgetSettingsSheet.show(context, currentBudget: budget),
          ),
          IconButton(
            icon: Icon(Icons.add_rounded, color: context.accentSecondary, size: 28),
            tooltip: 'Record Expense',
            onPressed: () => AddTransactionSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.accentSecondary,
          unselectedLabelColor: context.textMuted,
          indicatorColor: context.accentSecondary,
          tabs: const [
            Tab(text: 'Transactions & Trends'),
            Tab(text: 'Budgets & Goals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 0: Transactions & Trends ─────────────────────────────────
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Hero Balance Card
              AscentCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMMM y').format(now).toUpperCase(),
                          style: AscentTextStyles.labelSmall.copyWith(
                            color: context.textMuted,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (monthSpend > monthlyLimit)
                                ? context.stateDanger.withValues(alpha: 0.15)
                                : context.accentSecondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            monthSpend > monthlyLimit ? 'Over Budget' : 'On Track',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: (monthSpend > monthlyLimit) ? context.stateDanger : context.accentSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${monthSpend.toStringAsFixed(0)}',
                          style: AscentTextStyles.displaySmall.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'spent this month',
                          style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: budgetProgress,
                        minHeight: 7,
                        backgroundColor: context.bgBase,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          monthSpend > monthlyLimit ? context.stateDanger : context.accentSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Remaining: ₹${remainingBudget.toStringAsFixed(0)}',
                          style: AscentTextStyles.bodySmall.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Income: ₹${monthIncome.toStringAsFixed(0)}',
                          style: AscentTextStyles.bodySmall.copyWith(
                            color: context.accentPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── JARVIS Financial Copilot Insight ─────────────────────────
              AscentCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0096C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.blur_on_rounded, color: Color(0xFF00B4D8), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'JARVIS FINANCIAL COPILOT',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: const Color(0xFF00B4D8),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  fontSize: 10,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                remainingBudget > 0
                                    ? '₹${remainingBudget.toStringAsFixed(0)} room left'
                                    : 'Budget exceeded',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: remainingBudget > 0 ? const Color(0xFF5FA070) : context.stateDanger,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            todaySpend > 0
                                ? 'Today you\'ve spent ₹${todaySpend.toStringAsFixed(0)}. Monthly burn is ₹${monthSpend.toStringAsFixed(0)} of ₹${monthlyLimit.toStringAsFixed(0)}. Discretionary spending is pacing within targets.'
                                : 'Zero spending recorded today. You are conserving capital effectively, keeping your monthly savings on course.',
                            style: AscentTextStyles.bodySmall.copyWith(
                              color: context.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Quick Action Bar
              Row(
                children: [
                  Expanded(
                    child: AscentCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Today\'s Spend', style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted)),
                          const SizedBox(height: 4),
                          Text(
                            '₹${(todaySpendAsync.value ?? 0.0).toStringAsFixed(0)}',
                            style: AscentTextStyles.headlineMedium.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AscentButton.primary(
                      icon: Icons.add_rounded,
                      label: 'Add Expense',
                      compact: true,
                      onPressed: () => AddTransactionSheet.show(context),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Recent Transactions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: AscentTextStyles.headlineMedium.copyWith(
                      color: context.textPrimary,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    'Real-time',
                    style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
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
                      title: 'No Expenses Recorded Yet',
                      subtitle: 'Record your daily tea, transport, or bills to track your finances in real-time.',
                      actionLabel: 'Record First Expense',
                      onAction: () => AddTransactionSheet.show(context),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      final isExpense = tx.type == 'expense';
                      final catColor = _categoryColor(context, tx.category);

                      return AscentCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _categoryIcon(tx.category),
                                color: catColor,
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
                                    style: AscentTextStyles.labelLarge.copyWith(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        tx.category,
                                        style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('•', style: TextStyle(color: context.divider)),
                                      const SizedBox(width: 6),
                                      Text(
                                        DateFormat('MMM d').format(tx.date),
                                        style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: context.bgBase,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: context.divider),
                                        ),
                                        child: Text(
                                          tx.account,
                                          style: TextStyle(fontSize: 10, color: context.textMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isExpense ? '-' : '+'}₹${tx.amount.toStringAsFixed(0)}',
                              style: AscentTextStyles.monoCode.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isExpense ? context.textPrimary : context.accentPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 18, color: context.textMuted),
                              onPressed: () async {
                                await ref.read(financeDaoProvider).deleteTransaction(tx.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (e, _) => Center(child: Text('Error loading transactions: $e')),
              ),
              const SizedBox(height: 32),
            ],
          ),

          // ── Tab 1: Budgets & Savings Goals ───────────────────────────────
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Monthly Budget Setting Card
              AscentCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Overall Monthly Budget',
                          style: AscentTextStyles.headlineMedium.copyWith(color: context.textPrimary, fontSize: 16),
                        ),
                        AscentButton.outlined(
                          label: 'Edit Limit',
                          compact: true,
                          onPressed: () => BudgetSettingsSheet.show(context, currentBudget: budget),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₹${monthlyLimit.toStringAsFixed(0)} Limit',
                      style: AscentTextStyles.displaySmall.copyWith(
                        color: context.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daily target: ₹${(budget?.dailyLimit ?? (monthlyLimit / 30)).toStringAsFixed(0)}/day',
                      style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Savings Goals Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Savings Goals',
                    style: AscentTextStyles.headlineMedium.copyWith(
                      color: context.textPrimary,
                      fontSize: 17,
                    ),
                  ),
                  AscentButton.outlined(
                    icon: Icons.add_rounded,
                    label: 'New Goal',
                    compact: true,
                    onPressed: _showAddGoalDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              goalsAsync.when(
                data: (goals) {
                  if (goals.isEmpty) {
                    return AscentCard(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.savings_outlined, size: 36, color: context.accentPrimary),
                            const SizedBox(height: 8),
                            Text('No Savings Goals Added', style: AscentTextStyles.labelLarge.copyWith(color: context.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Set goals for an emergency fund, laptop, or certification.', style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: goals.map((g) {
                      final percent = (g.savedAmount / g.targetAmount).clamp(0.0, 1.0);
                      return AscentCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  g.title,
                                  style: AscentTextStyles.headlineMedium.copyWith(
                                    color: context.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${(percent * 100).toInt()}%',
                                  style: AscentTextStyles.monoCode.copyWith(
                                    color: context.accentPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: percent,
                                minHeight: 6,
                                backgroundColor: context.bgBase,
                                valueColor: AlwaysStoppedAnimation<Color>(context.accentPrimary),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₹${g.savedAmount.toStringAsFixed(0)} of ₹${g.targetAmount.toStringAsFixed(0)}',
                                  style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        // Quick add ₹500 to savings
                                        await ref.read(financeDaoProvider).updateSavingsGoal(
                                          SavingsGoalTableCompanion(
                                            id: drift.Value(g.id),
                                            title: drift.Value(g.title),
                                            targetAmount: drift.Value(g.targetAmount),
                                            savedAmount: drift.Value(g.savedAmount + 500),
                                          ),
                                        );
                                      },
                                      child: const Text('+₹500', style: TextStyle(fontSize: 12)),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline_rounded, size: 16, color: context.textMuted),
                                      onPressed: () => ref.read(financeDaoProvider).deleteSavingsGoal(g.id),
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
