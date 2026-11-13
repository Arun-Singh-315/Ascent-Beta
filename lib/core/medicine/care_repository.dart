import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import '../database/app_database.dart';

/// Personal care context is separate from dose scheduling. Updating or archiving
/// a folder never silently changes a prescription or cancels dose reminders.
class CareRepository {
  CareRepository(this.db);
  final AppDatabase db;

  Stream<List<CarePlan>> watchPlans() =>
      (db.select(db.carePlanTable)..orderBy([
            (p) => OrderingTerm.asc(p.isArchived),
            (p) => OrderingTerm.desc(p.createdAt),
          ]))
          .watch();

  Stream<List<CareRecord>> watchRecords(int planId) =>
      (db.select(db.careRecordTable)
            ..where((r) => r.carePlanId.equals(planId))
            ..orderBy([
              (r) => OrderingTerm.desc(r.recordedAt),
              (r) => OrderingTerm.desc(r.id),
            ]))
          .watch();

  Future<int> savePlan({
    int? id,
    required String title,
    required String person,
    required String clinician,
    required String notes,
    DateTime? nextVisit,
  }) async {
    if (title.trim().isEmpty ||
        title.trim().length > 200 ||
        person.length > 200 ||
        clinician.length > 200 ||
        notes.length > 10000) {
      throw ArgumentError('Check the care plan details');
    }
    final row = CarePlanTableCompanion(
      title: Value(title.trim()),
      person: Value(person.trim().isEmpty ? 'My care' : person.trim()),
      clinician: Value(clinician.trim()),
      notes: Value(notes.trim()),
      nextVisit: Value(nextVisit),
    );
    if (id == null) return db.into(db.carePlanTable).insert(row);
    final count = await (db.update(
      db.carePlanTable,
    )..where((p) => p.id.equals(id))).write(row);
    if (count != 1) throw StateError('Care plan no longer exists');
    return id;
  }

  Future<void> archive(int id, bool archived) async {
    final count =
        await (db.update(db.carePlanTable)..where((p) => p.id.equals(id)))
            .write(CarePlanTableCompanion(isArchived: Value(archived)));
    if (count != 1) throw StateError('Care plan no longer exists');
  }

  Future<Future<void> Function()> removeRecordWithUndo(int id) async {
    final revision = db.workspaceRevision;
    late CareRecord record;
    await db.transaction(() async {
      final row = await (db.select(
        db.careRecordTable,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (row == null) throw StateError('This care record no longer exists');
      record = row;
      await (db.delete(db.careRecordTable)..where((r) => r.id.equals(id))).go();
    });
    var restored = false;
    return () async {
      if (restored) return;
      if (revision != db.workspaceRevision) {
        throw StateError('Workspace changed');
      }
      await db.into(db.careRecordTable).insert(record.toCompanion(true));
      restored = true;
    };
  }

  Future<int> addRecord({
    int? id,
    required int planId,
    required String title,
    required String notes,
    required DateTime recordedAt,
    File? attachment,
    String? fileName,
    Directory? documents,
  }) async {
    if (title.trim().isEmpty ||
        title.trim().length > 200 ||
        notes.length > 10000) {
      throw ArgumentError('Check the record details');
    }
    final revision = db.workspaceRevision;
    File? stored;
    if (attachment != null) {
      if (documents == null || !await attachment.exists()) {
        throw StateError('Select the file again');
      }
      final extension = p.extension(fileName ?? attachment.path).toLowerCase();
      if (!{'.pdf', '.jpg', '.jpeg', '.png'}.contains(extension) ||
          await attachment.length() > 20 * 1024 * 1024) {
        throw ArgumentError('Choose a PDF, JPG or PNG up to 20 MB');
      }
      final folder = await Directory(
        p.join(documents.path, 'care-reports'),
      ).create(recursive: true);
      stored = await attachment.copy(
        p.join(
          folder.path,
          '${DateTime.now().microsecondsSinceEpoch}$extension',
        ),
      );
    }
    try {
      return await db.transaction(() async {
        if (revision != db.workspaceRevision) {
          throw StateError('Workspace changed');
        }
        if (await (db.select(
              db.carePlanTable,
            )..where((p) => p.id.equals(planId))).getSingleOrNull() ==
            null) {
          throw StateError('Care plan no longer exists');
        }
        final row = CareRecordTableCompanion(
          carePlanId: Value(planId),
          title: Value(title.trim()),
          notes: Value(notes.trim()),
          recordedAt: Value(recordedAt),
          filePath: stored == null && id != null
              ? const Value.absent()
              : Value(stored?.path),
          fileName: stored == null && id != null
              ? const Value.absent()
              : Value(
                  stored == null
                      ? null
                      : p.basename(fileName ?? attachment!.path),
                ),
        );
        if (id == null) return await db.into(db.careRecordTable).insert(row);
        final count =
            await (db.update(db.careRecordTable)
                  ..where((r) => r.id.equals(id) & r.carePlanId.equals(planId)))
                .write(row);
        if (count != 1) throw StateError('This care record no longer exists');
        return id;
      });
    } catch (_) {
      if (stored != null) await stored.delete();
      rethrow;
    }
  }
}
