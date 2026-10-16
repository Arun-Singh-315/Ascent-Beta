import 'package:drift/drift.dart' as drift;
import '../database/app_database.dart';
import 'local_action_receipts.dart';

class ExpenseActions {
  ExpenseActions(this.db);
  final AppDatabase db;
  Future<int> save({
    required String requestId,
    required String title,
    required double amount,
    required DateTime date,
    String type = 'expense',
    String category = 'Other',
    String account = 'UPI',
    String? notes,
  }) async {
    final text = title.trim();
    if (text.isEmpty ||
        text.length > 200 ||
        !amount.isFinite ||
        amount <= 0 ||
        !{'expense', 'income'}.contains(type)) {
      throw ArgumentError('Use a description and a finite positive amount');
    }
    final arguments = <String, dynamic>{
      'title': text,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type,
      'category': category,
      'account': account,
      'notes': notes,
    };
    final result = await LocalActionReceipts(db).run(
      requestId: requestId,
      capability: 'expense-entry.save',
      arguments: arguments,
      write: () async {
        final id = await db.financeDao.insertTransaction(
          FinanceTransactionTableCompanion.insert(
            title: text,
            amount: amount,
            date: date,
            type: drift.Value(type),
            category: drift.Value(category),
            account: drift.Value(account),
            notes: drift.Value(notes),
          ),
        );
        return {'id': id};
      },
    );
    return result['id'] as int;
  }
}
