import 'package:drift/drift.dart';

@DataClassName('FinanceTransaction')
class FinanceTransactionTable extends Table {
  @override
  String get tableName => 'finance_transactions';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  RealColumn get amount => real()();
  // 'expense', 'income', 'transfer'
  TextColumn get type => text().withDefault(const Constant('expense'))();
  // 'Food & Groceries', 'Transport', 'Shopping', 'Education', 'Bills & Subscriptions', 'Health', 'Entertainment', 'Savings', 'Other'
  TextColumn get category => text().withDefault(const Constant('Other'))();
  DateTimeColumn get date => dateTime()();
  // 'UPI', 'Cash', 'Bank Account', 'Credit Card'
  TextColumn get account => text().withDefault(const Constant('UPI'))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('FinanceBudget')
class FinanceBudgetTable extends Table {
  @override
  String get tableName => 'finance_budgets';

  IntColumn get id => integer().autoIncrement()();
  // null = overall monthly budget, or specific category name
  TextColumn get category => text().nullable()();
  RealColumn get monthlyLimit => real()();
  RealColumn get dailyLimit => real().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('SavingsGoal')
class SavingsGoalTable extends Table {
  @override
  String get tableName => 'savings_goals';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 150)();
  RealColumn get targetAmount => real()();
  RealColumn get savedAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
