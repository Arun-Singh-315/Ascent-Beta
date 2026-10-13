import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'riya_capabilities.dart';

const transactionFields = <String, RiyaValue>{
  'title': RiyaValue.text,
  'amount': RiyaValue.number,
  'type': RiyaValue.text,
  'category': RiyaValue.text,
  'account': RiyaValue.text,
  'date': RiyaValue.date,
  'notes': RiyaValue.longText,
  'clearNotes': RiyaValue.boolean,
};
const riyaMoneyCapabilities = <RiyaCapability>[
  RiyaCapability(
    'transactions.create',
    'Record income or spending',
    '/money',
    transactionFields,
    required: ['title', 'amount', 'type'],
    write: true,
  ),
  RiyaCapability(
    'transactions.edit',
    'Edit a Money record',
    '/money',
    {'id': RiyaValue.integer, ...transactionFields},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'transactions.delete',
    'Delete a Money record',
    '/money',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'transactions.read',
    'Read a Money record',
    '/money',
    {'id': RiyaValue.integer},
    required: ['id'],
  ),
  RiyaCapability('transactions.list', 'Read scoped Money records', '/money', {
    'scope': RiyaValue.text,
    'day': RiyaValue.date,
    'type': RiyaValue.text,
    'offset': RiyaValue.offset,
  }),
  RiyaCapability(
    'transactions.summary',
    'Read income and spending totals',
    '/money',
    {'from': RiyaValue.date, 'to': RiyaValue.date},
    required: ['from', 'to'],
  ),
];

class RiyaMoneyActions {
  RiyaMoneyActions(this.db, this.clock);
  final AppDatabase db;
  final DateTime Function() clock;
  bool handles(String id) => riyaMoneyCapabilities.any((c) => c.id == id);
  static const categories = [
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
  static const accounts = ['UPI', 'Cash', 'Bank Account', 'Credit Card'];
  String _choice(String value, List<String> choices) => choices.firstWhere(
    (c) => c.toLowerCase() == value.trim().toLowerCase(),
    orElse: () => throw ArgumentError('Choose one of ${choices.join(', ')}'),
  );
  String _type(String value) => _choice(value, ['income', 'expense']);
  String _title(String value) {
    final text = value.trim();
    if (text.isEmpty || text.length > 200) {
      throw ArgumentError('Use a description of 1–200 characters');
    }
    return text;
  }

  String _excerpt(String text) =>
      text.length <= 160 ? text : '${text.substring(0, 157)}…';
  String _line(FinanceTransaction r) =>
      '#${r.id} ${r.type} · ₹${r.amount.toStringAsFixed(2)} · ${_excerpt(r.title)}';
  Future<RiyaResult> run(RiyaCommand cmd) async {
    final a = cmd.arguments;
    if (cmd.id == 'transactions.list') {
      final scope = a['scope'] as String? ?? 'today';
      if (!{'today', 'tomorrow', 'date', 'all'}.contains(scope) ||
          (scope == 'date' && a['day'] == null) ||
          (scope == 'all' && a['day'] != null)) {
        throw ArgumentError('Choose a Money period');
      }
      final type = a['type'] == null ? null : _type(a['type']);
      final now = a['day'] == null
          ? clock()
          : DateTime.parse(a['day']).toLocal();
      final from = DateTime(
        now.year,
        now.month,
        now.day + (scope == 'tomorrow' ? 1 : 0),
      );
      final to = DateTime(from.year, from.month, from.day + 1);
      final rows =
          await (db.select(db.financeTransactionTable)
                ..where(
                  (r) =>
                      (type == null
                          ? const Constant(true)
                          : r.type.equals(type)) &
                      (scope == 'all'
                          ? const Constant(true)
                          : r.date.isBiggerOrEqualValue(from) &
                                r.date.isSmallerThanValue(to)),
                )
                ..orderBy([
                  (r) => OrderingTerm.desc(r.date),
                  (r) => OrderingTerm.desc(r.id),
                ])
                ..limit(4, offset: a['offset'] as int? ?? 0))
              .get();
      final label = scope == 'all'
          ? 'All'
          : '${from.day}/${from.month}/${from.year}';
      return RiyaResult(
        '$label · ${type ?? 'Money records'}:\n${rows.isEmpty ? 'No recorded transactions.' : rows.take(3).map(_line).join('\n')}',
        '/money',
        options: [
          if (rows.length > 3)
            'More ${type == 'income' ? 'income' : 'transactions'}',
          'Transactions today',
          'Transactions all',
        ],
      );
    }
    if (cmd.id == 'transactions.summary') {
      final from = DateTime.parse(a['from']).toLocal(),
          to = DateTime.parse(a['to']).toLocal();
      if (!to.isAfter(from) || to.difference(from).inDays > 366) {
        throw ArgumentError('Choose a period of at most one year');
      }
      final table = db.financeTransactionTable;
      final sum = table.amount.sum();
      final rows =
          await (db.selectOnly(table)
                ..addColumns([table.type, sum])
                ..where(
                  table.date.isBiggerOrEqualValue(from) &
                      table.date.isSmallerThanValue(to) &
                      table.type.isIn(['income', 'expense']),
                )
                ..groupBy([table.type]))
              .get();
      double total(String type) =>
          rows
              .where((r) => r.read(table.type) == type)
              .map((r) => r.read(sum) ?? 0.0)
              .firstOrNull ??
          0.0;
      final income = total('income'), spending = total('expense');
      if (!income.isFinite ||
          !spending.isFinite ||
          !(income - spending).isFinite) {
        throw StateError('Recorded amounts exceed the supported total range');
      }
      return RiyaResult(
        'Recorded income ₹${income.toStringAsFixed(2)} · spending ₹${spending.toStringAsFixed(2)} · net ₹${(income - spending).toStringAsFixed(2)}.\n${from.toIso8601String()} to ${to.toIso8601String()} (end exclusive).',
        '/money',
      );
    }
    if (a['clearNotes'] == true && a.containsKey('notes')) {
      throw ArgumentError('Choose notes or clear notes');
    }
    if (cmd.id == 'transactions.create' && a['clearNotes'] == true) {
      throw ArgumentError('New records have no notes to clear');
    }
    final title = a['title'] == null ? null : _title(a['title']);
    final type = a['type'] == null ? null : _type(a['type']);
    final category = a['category'] == null
        ? null
        : _choice(a['category'], categories);
    final account = a['account'] == null
        ? null
        : _choice(a['account'], accounts);
    final date = a['date'] == null ? null : DateTime.parse(a['date']).toLocal();
    if (cmd.id == 'transactions.create') {
      final id = await db.financeDao.insertTransaction(
        FinanceTransactionTableCompanion.insert(
          title: title!,
          amount: (a['amount'] as num).toDouble(),
          date: date ?? clock(),
          type: Value(type!),
          category: Value(category ?? 'Other'),
          account: Value(account ?? 'UPI'),
          notes: Value(a['notes'] as String?),
        ),
      );
      return RiyaResult(
        'Recorded $type #$id · ₹${(a['amount'] as num).toStringAsFixed(2)} · $title.',
        '/money',
        entityType: 'transactions',
        entityId: id,
      );
    }
    final old = await (db.select(
      db.financeTransactionTable,
    )..where((r) => r.id.equals(a['id'] as int))).getSingleOrNull();
    if (old == null) throw StateError('This Money record no longer exists');
    if (cmd.id == 'transactions.read') {
      return RiyaResult(
        '${_line(old)}\n${old.date.toIso8601String()} · ${old.category} · ${old.account}${old.notes == null ? '' : '\n${_excerpt(old.notes!)}'}',
        '/money',
        entityType: 'transactions',
        entityId: old.id,
      );
    }
    if (cmd.id == 'transactions.delete') {
      await db.financeDao.deleteTransaction(old.id);
      return RiyaResult('Deleted ${old.type} #${old.id}.', '/money');
    }
    if (a.keys.every(
      (key) => key == 'id' || key == 'clearNotes' && a[key] != true,
    )) {
      throw ArgumentError('Choose a field to change');
    }
    await (db.update(
      db.financeTransactionTable,
    )..where((r) => r.id.equals(old.id))).write(
      FinanceTransactionTableCompanion(
        title: title == null ? const Value.absent() : Value(title),
        type: type == null ? const Value.absent() : Value(type),
        amount: a['amount'] == null
            ? const Value.absent()
            : Value((a['amount'] as num).toDouble()),
        date: date == null ? const Value.absent() : Value(date),
        category: category == null ? const Value.absent() : Value(category),
        account: account == null ? const Value.absent() : Value(account),
        notes: a['clearNotes'] == true
            ? const Value(null)
            : a.containsKey('notes')
            ? Value(a['notes'] as String)
            : const Value.absent(),
      ),
    );
    return RiyaResult(
      'Updated Money record #${old.id}.',
      '/money',
      entityType: 'transactions',
      entityId: old.id,
    );
  }
}
