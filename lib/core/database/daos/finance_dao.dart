part of '../app_database.dart';

@DriftAccessor(tables: [
  FinanceTransactionTable,
  FinanceBudgetTable,
  SavingsGoalTable,
])
class FinanceDao extends DatabaseAccessor<AppDatabase> with _$FinanceDaoMixin {
  FinanceDao(super.db);

  /// Watch all transactions sorted by date desc.
  Stream<List<FinanceTransaction>> watchAllTransactions() {
    return (select(financeTransactionTable)
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  /// Watch recent transactions with limit.
  Stream<List<FinanceTransaction>> watchRecentTransactions({int limit = 15}) {
    return (select(financeTransactionTable)
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit))
        .watch();
  }

  /// Watch today's total spending (expenses only).
  Stream<double> watchTodaySpending() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final amountSum = financeTransactionTable.amount.sum();
    final query = selectOnly(financeTransactionTable)
      ..addColumns([amountSum])
      ..where(financeTransactionTable.type.equals('expense') &
          financeTransactionTable.date.isBiggerOrEqualValue(startOfDay) &
          financeTransactionTable.date.isSmallerOrEqualValue(endOfDay));

    return query.watchSingle().map((row) => row.read(amountSum) ?? 0.0);
  }

  /// Watch this month's total spending.
  Stream<double> watchMonthSpending(int year, int month) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    final amountSum = financeTransactionTable.amount.sum();
    final query = selectOnly(financeTransactionTable)
      ..addColumns([amountSum])
      ..where(financeTransactionTable.type.equals('expense') &
          financeTransactionTable.date.isBiggerOrEqualValue(startOfMonth) &
          financeTransactionTable.date.isSmallerOrEqualValue(endOfMonth));

    return query.watchSingle().map((row) => row.read(amountSum) ?? 0.0);
  }

  /// Watch this month's total income.
  Stream<double> watchMonthIncome(int year, int month) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    final amountSum = financeTransactionTable.amount.sum();
    final query = selectOnly(financeTransactionTable)
      ..addColumns([amountSum])
      ..where(financeTransactionTable.type.equals('income') &
          financeTransactionTable.date.isBiggerOrEqualValue(startOfMonth) &
          financeTransactionTable.date.isSmallerOrEqualValue(endOfMonth));

    return query.watchSingle().map((row) => row.read(amountSum) ?? 0.0);
  }

  /// Watch category spending for a given month.
  Stream<Map<String, double>> watchCategorySpending(int year, int month) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    final amountSum = financeTransactionTable.amount.sum();
    final categoryCol = financeTransactionTable.category;

    final query = selectOnly(financeTransactionTable)
      ..addColumns([categoryCol, amountSum])
      ..where(financeTransactionTable.type.equals('expense') &
          financeTransactionTable.date.isBiggerOrEqualValue(startOfMonth) &
          financeTransactionTable.date.isSmallerOrEqualValue(endOfMonth))
      ..groupBy([categoryCol]);

    return query.watch().map((rows) {
      final map = <String, double>{};
      for (final r in rows) {
        final cat = r.read(categoryCol) ?? 'Other';
        final sum = r.read(amountSum) ?? 0.0;
        map[cat] = sum;
      }
      return map;
    });
  }

  /// Insert transaction.
  Future<int> insertTransaction(FinanceTransactionTableCompanion entry) {
    return into(financeTransactionTable).insert(entry);
  }

  /// Update transaction.
  Future<bool> updateTransaction(FinanceTransactionTableCompanion entry) {
    return update(financeTransactionTable).replace(entry);
  }

  /// Delete transaction.
  Future<int> deleteTransaction(int id) {
    return (delete(financeTransactionTable)..where((t) => t.id.equals(id))).go();
  }

  // ── Budgets ────────────────────────────────────────────────────────────────

  /// Watch overall monthly budget.
  Stream<FinanceBudget?> watchOverallBudget() {
    return (select(financeBudgetTable)
          ..where((b) => b.category.isNull())
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Set or update overall budget.
  Future<void> setOverallBudget(double monthlyLimit, {double? dailyLimit}) async {
    final existing = await (select(financeBudgetTable)
          ..where((b) => b.category.isNull()))
        .getSingleOrNull();

    if (existing == null) {
      await into(financeBudgetTable).insert(
        FinanceBudgetTableCompanion.insert(
          monthlyLimit: monthlyLimit,
          dailyLimit: Value(dailyLimit),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await update(financeBudgetTable).replace(
        FinanceBudgetTableCompanion(
          id: Value(existing.id),
          monthlyLimit: Value(monthlyLimit),
          dailyLimit: Value(dailyLimit),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  // ── Savings Goals ──────────────────────────────────────────────────────────

  Stream<List<SavingsGoal>> watchSavingsGoals() {
    return (select(savingsGoalTable)
          ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
        .watch();
  }

  Future<int> insertSavingsGoal(SavingsGoalTableCompanion entry) {
    return into(savingsGoalTable).insert(entry);
  }

  Future<bool> updateSavingsGoal(SavingsGoalTableCompanion entry) {
    return update(savingsGoalTable).replace(entry);
  }

  Future<int> deleteSavingsGoal(int id) {
    return (delete(savingsGoalTable)..where((g) => g.id.equals(id))).go();
  }
}
