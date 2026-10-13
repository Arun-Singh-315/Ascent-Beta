import '../database/app_database.dart';
import 'local_action_receipts.dart';

/// One chosen water entry per check-in period, even if preference saving fails.
class CheckInActions {
  CheckInActions(this.db);
  final AppDatabase db;
  static String waterRequestId(String period) => 'checkin.water:$period';
  Future<bool> waterSaved(String period) async =>
      await (db.select(db.aiCommandTable)
            ..where((r) => r.requestId.equals(waterRequestId(period))))
          .getSingleOrNull() !=
      null;
  Future<int> saveWater({required String period, required int amountMl}) async {
    if (period.trim().isEmpty || amountMl < 1 || amountMl > 3000) {
      throw ArgumentError('Choose a check-in period and 1–3000 ml');
    }
    final result = await LocalActionReceipts(db).run(
      requestId: waterRequestId(period),
      capability: 'checkin.water',
      arguments: {'period': period},
      write: () async => {'id': await db.waterDao.addWater(amountMl)},
    );
    return result['id'] as int;
  }
}
