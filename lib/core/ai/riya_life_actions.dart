import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'riya_capabilities.dart';

const riyaLifeCapabilities = <RiyaCapability>[
  RiyaCapability('budgets.list', 'Read monthly budgets', '/money', {
    'offset': RiyaValue.offset,
  }),
  RiyaCapability(
    'budgets.set',
    'Set a monthly budget',
    '/money',
    {
      'category': RiyaValue.text,
      'monthlyLimit': RiyaValue.number,
      'dailyLimit': RiyaValue.number,
      'clearDaily': RiyaValue.boolean,
    },
    required: ['monthlyLimit'],
    write: true,
  ),
  RiyaCapability(
    'budgets.edit',
    'Edit a selected budget',
    '/money',
    {
      'id': RiyaValue.integer,
      'monthlyLimit': RiyaValue.number,
      'dailyLimit': RiyaValue.number,
      'clearDaily': RiyaValue.boolean,
    },
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'budgets.delete',
    'Delete a budget',
    '/money',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
  ),
  RiyaCapability('savings.list', 'Read savings goals', '/money', {
    'offset': RiyaValue.offset,
  }),
  RiyaCapability(
    'savings.create',
    'Create a savings goal',
    '/money',
    {
      'title': RiyaValue.text,
      'targetAmount': RiyaValue.number,
      'targetDate': RiyaValue.date,
    },
    required: ['title', 'targetAmount'],
    write: true,
  ),
  RiyaCapability(
    'savings.edit',
    'Edit a savings goal',
    '/money',
    {
      'id': RiyaValue.integer,
      'title': RiyaValue.text,
      'targetAmount': RiyaValue.number,
      'savedAmount': RiyaValue.nonnegativeNumber,
      'targetDate': RiyaValue.date,
      'clearDate': RiyaValue.boolean,
    },
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'savings.contribute',
    'Record a savings contribution',
    '/money',
    {'id': RiyaValue.integer, 'amount': RiyaValue.number},
    required: ['id', 'amount'],
    write: true,
  ),
  RiyaCapability(
    'savings.delete',
    'Delete a savings goal',
    '/money',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'hydration.logs',
    'Read water entries for today',
    '/hydration',
    {'offset': RiyaValue.offset, 'day': RiyaValue.date},
  ),
  RiyaCapability(
    'hydration.edit',
    'Correct a water entry',
    '/hydration',
    {'id': RiyaValue.integer, 'amountMl': RiyaValue.integer},
    required: ['id', 'amountMl'],
    write: true,
  ),
  RiyaCapability(
    'hydration.delete',
    'Delete a water entry',
    '/hydration',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'hydration.goal',
    'Set the daily water goal',
    '/hydration',
    {'amountMl': RiyaValue.integer},
    required: ['amountMl'],
    write: true,
  ),
];

class RiyaLifeActions {
  RiyaLifeActions(this.db, this.clock);
  final AppDatabase db;
  final DateTime Function() clock;
  bool handles(String id) => riyaLifeCapabilities.any((c) => c.id == id);
  String _title(String value, int limit) {
    final title = value.trim();
    if (title.isEmpty || title.length > limit) {
      throw ArgumentError('Use a title of 1–$limit characters');
    }
    return title;
  }

  Future<RiyaResult> run(RiyaCommand command) async {
    final a = command.arguments;
    final route = command.capability.route;
    final offset = a['offset'] as int? ?? 0;
    switch (command.id) {
      case 'budgets.list':
        final rows =
            await (db.select(db.financeBudgetTable)
                  ..orderBy([(b) => OrderingTerm.asc(b.id)])
                  ..limit(4, offset: offset))
                .get();
        final now = clock();
        return RiyaResult(
          'Monthly budgets · ${now.year}-${now.month.toString().padLeft(2, '0')}:\n${rows.isEmpty ? 'No budgets set.' : rows.take(3).map((b) => '#${b.id} ${b.category ?? 'Overall'} · ₹${b.monthlyLimit.toStringAsFixed(2)}${b.dailyLimit == null ? '' : ' · daily ₹${b.dailyLimit!.toStringAsFixed(2)}'}').join('\n')}',
          route,
          options: [if (rows.length > 3) 'More budgets'],
        );
      case 'budgets.set':
        if (a['clearDaily'] == true && a.containsKey('dailyLimit')) {
          throw ArgumentError('Choose a daily limit or clear it');
        }
        final rawCategory = a['category'] as String?;
        const categories = [
          'Food & Groceries',
          'Transport',
          'Shopping',
          'Education',
          'Bills & Subscriptions',
          'Health',
          'Entertainment',
          'Savings',
          'Other',
        ];
        final category = rawCategory == null
            ? null
            : categories
                  .where(
                    (c) => c.toLowerCase() == rawCategory.trim().toLowerCase(),
                  )
                  .firstOrNull;
        if (rawCategory != null && category == null) {
          throw ArgumentError('Choose an existing Money category');
        }
        final rows =
            await (db.select(db.financeBudgetTable)..where(
                  (b) => category == null
                      ? b.category.isNull()
                      : b.category.equals(category),
                ))
                .get();
        if (rows.length > 1) {
          throw StateError(
            'Several budgets match this category. Choose their record numbers in Money first',
          );
        }
        final previous = rows.firstOrNull;
        final daily = a['clearDaily'] == true
            ? null
            : (a['dailyLimit'] as num?)?.toDouble() ?? previous?.dailyLimit;
        final id =
            previous?.id ??
            await db
                .into(db.financeBudgetTable)
                .insert(
                  FinanceBudgetTableCompanion.insert(
                    monthlyLimit: (a['monthlyLimit'] as num).toDouble(),
                    category: Value(category),
                    dailyLimit: Value(daily),
                    updatedAt: Value(clock()),
                  ),
                );
        if (previous != null) {
          await (db.update(
            db.financeBudgetTable,
          )..where((b) => b.id.equals(id))).write(
            FinanceBudgetTableCompanion(
              monthlyLimit: Value((a['monthlyLimit'] as num).toDouble()),
              dailyLimit: Value(daily),
              updatedAt: Value(clock()),
            ),
          );
        }
        return RiyaResult(
          'Monthly budget #$id saved for ${category ?? 'Overall'}.',
          route,
          entityType: 'budgets',
          entityId: id,
        );
      case 'budgets.edit':
        final budget = await (db.select(
          db.financeBudgetTable,
        )..where((b) => b.id.equals(a['id']))).getSingleOrNull();
        if (budget == null) throw StateError('This budget no longer exists');
        if (a.keys.every((key) => key == 'id')) {
          throw ArgumentError('Choose a budget field to change');
        }
        if (a['clearDaily'] == true && a.containsKey('dailyLimit')) {
          throw ArgumentError('Choose a daily limit or clear it');
        }
        await (db.update(
          db.financeBudgetTable,
        )..where((b) => b.id.equals(budget.id))).write(
          FinanceBudgetTableCompanion(
            monthlyLimit: a.containsKey('monthlyLimit')
                ? Value((a['monthlyLimit'] as num).toDouble())
                : const Value.absent(),
            dailyLimit: a['clearDaily'] == true
                ? const Value(null)
                : a.containsKey('dailyLimit')
                ? Value((a['dailyLimit'] as num).toDouble())
                : const Value.absent(),
            updatedAt: Value(clock()),
          ),
        );
        return RiyaResult(
          'Budget #${budget.id} updated.',
          route,
          entityType: 'budgets',
          entityId: budget.id,
        );
      case 'budgets.delete':
        if (await (db.delete(
              db.financeBudgetTable,
            )..where((b) => b.id.equals(a['id']))).go() !=
            1) {
          throw StateError('This budget no longer exists');
        }
        return RiyaResult('Budget #${a['id']} deleted.', route);
      case 'savings.list':
        final rows =
            await (db.select(db.savingsGoalTable)
                  ..orderBy([
                    (g) => OrderingTerm.desc(g.createdAt),
                    (g) => OrderingTerm.desc(g.id),
                  ])
                  ..limit(4, offset: offset))
                .get();
        return RiyaResult(
          rows.isEmpty
              ? 'No savings goals.'
              : 'Savings goals:\n${rows.take(3).map((g) => '#${g.id} ${g.title} · ₹${g.savedAmount.toStringAsFixed(2)} / ₹${g.targetAmount.toStringAsFixed(2)}').join('\n')}',
          route,
          options: [if (rows.length > 3) 'More savings goals'],
        );
      case 'savings.create':
        final id = await db.financeDao.insertSavingsGoal(
          SavingsGoalTableCompanion.insert(
            title: _title(a['title'], 150),
            targetAmount: (a['targetAmount'] as num).toDouble(),
            targetDate: Value(
              a['targetDate'] == null
                  ? null
                  : DateTime.parse(a['targetDate']).toLocal(),
            ),
          ),
        );
        return RiyaResult(
          'Savings goal #$id saved.',
          route,
          entityType: 'savings',
          entityId: id,
        );
      case 'savings.edit':
      case 'savings.contribute':
      case 'savings.delete':
        final goal = await (db.select(
          db.savingsGoalTable,
        )..where((g) => g.id.equals(a['id']))).getSingleOrNull();
        if (goal == null) {
          throw StateError('This savings goal no longer exists');
        }
        if (command.id == 'savings.delete') {
          await db.financeDao.deleteSavingsGoal(goal.id);
          return RiyaResult(
            'Savings goal #${goal.id} deleted. Transaction history is kept.',
            route,
          );
        }
        if (command.id == 'savings.contribute') {
          final total = goal.savedAmount + (a['amount'] as num).toDouble();
          if (!total.isFinite || goal.savedAmount < 0) {
            throw StateError(
              'The saved amount needs correction before adding a contribution',
            );
          }
          await (db.update(db.savingsGoalTable)
                ..where((g) => g.id.equals(goal.id)))
              .write(SavingsGoalTableCompanion(savedAmount: Value(total)));
          return RiyaResult(
            'Goal #${goal.id}: tracked savings ₹${total.toStringAsFixed(2)}. No transaction was created.',
            route,
          );
        }
        if (a.keys.every((key) => key == 'id')) {
          throw ArgumentError('Choose a field to change');
        }
        if (a['clearDate'] == true && a.containsKey('targetDate')) {
          throw ArgumentError('Choose a target date or clear it');
        }
        await (db.update(
          db.savingsGoalTable,
        )..where((g) => g.id.equals(goal.id))).write(
          SavingsGoalTableCompanion(
            title: a.containsKey('title')
                ? Value(_title(a['title'], 150))
                : const Value.absent(),
            targetAmount: a.containsKey('targetAmount')
                ? Value((a['targetAmount'] as num).toDouble())
                : const Value.absent(),
            savedAmount: a.containsKey('savedAmount')
                ? Value((a['savedAmount'] as num).toDouble())
                : const Value.absent(),
            targetDate: a['clearDate'] == true
                ? const Value(null)
                : a.containsKey('targetDate')
                ? Value(DateTime.parse(a['targetDate']).toLocal())
                : const Value.absent(),
          ),
        );
        return RiyaResult(
          'Savings goal #${goal.id} updated.',
          route,
          entityType: 'savings',
          entityId: goal.id,
        );
      case 'hydration.logs':
        final requested = a['day'] == null
            ? clock()
            : DateTime.parse(a['day']).toLocal();
        final from = DateTime(requested.year, requested.month, requested.day),
            to = DateTime(requested.year, requested.month, requested.day + 1);
        final rows =
            await (db.select(db.waterLogTable)
                  ..where(
                    (w) =>
                        w.date.isBiggerOrEqualValue(from) &
                        w.date.isSmallerThanValue(to),
                  )
                  ..orderBy([(w) => OrderingTerm.desc(w.id)])
                  ..limit(4, offset: offset))
                .get();
        return RiyaResult(
          'Water entries · ${from.day}/${from.month}/${from.year}:\n${rows.isEmpty ? 'Nothing logged.' : rows.take(3).map((w) => '#${w.id} ${w.amountMl} ml').join('\n')}',
          route,
          options: [if (rows.length > 3) 'More water entries'],
        );
      case 'hydration.goal':
        final ml = a['amountMl'] as int;
        if (ml > 10000) throw ArgumentError('Use a goal of 1–10000 ml');
        await db.waterDao.setDailyWaterGoal(ml);
        return RiyaResult(
          'Daily water goal saved: $ml ml. No water entry was logged.',
          route,
        );
      case 'hydration.edit':
      case 'hydration.delete':
        final log = await (db.select(
          db.waterLogTable,
        )..where((w) => w.id.equals(a['id']))).getSingleOrNull();
        if (log == null) throw StateError('This water entry no longer exists');
        if (command.id == 'hydration.delete') {
          await db.waterDao.deleteWater(log.id);
          return RiyaResult('Water entry #${log.id} deleted.', route);
        }
        final ml = a['amountMl'] as int;
        if (ml > 3000) throw ArgumentError('Use 1–3000 ml for one entry');
        await (db.update(db.waterLogTable)..where((w) => w.id.equals(log.id)))
            .write(WaterLogTableCompanion(amountMl: Value(ml)));
        return RiyaResult(
          'Water entry #${log.id} corrected to $ml ml. Its original date is kept.',
          route,
          entityType: 'hydration',
          entityId: log.id,
        );
      default:
        throw UnsupportedError('Unsupported life action');
    }
  }
}
