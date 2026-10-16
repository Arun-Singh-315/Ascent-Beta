import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../medicine/medicine_service.dart';
import 'riya_capabilities.dart';

const medicineFields = <String, RiyaValue>{
  'name': RiyaValue.text,
  'dosage': RiyaValue.text,
  'times': RiyaValue.textList,
  'days': RiyaValue.integer,
  'startDate': RiyaValue.date,
  'instructions': RiyaValue.longText,
  'form': RiyaValue.text,
  'active': RiyaValue.boolean,
};
const riyaMedicineCapabilities = <RiyaCapability>[
  RiyaCapability(
    'medicine.create',
    'Save your medicine schedule',
    '/medicine',
    medicineFields,
    required: ['name', 'dosage', 'times', 'days', 'form'],
    write: true,
  ),
  RiyaCapability(
    'medicine.edit',
    'Edit your medicine schedule',
    '/medicine',
    {'id': RiyaValue.integer, ...medicineFields},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'medicine.delete',
    'Delete a medicine and its linked records',
    '/medicine',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'medicine.read',
    'Read your saved schedule',
    '/medicine',
    {'id': RiyaValue.integer},
    required: ['id'],
  ),
  RiyaCapability(
    'medicine.list',
    'Read saved medicine schedules',
    '/medicine',
    {'all': RiyaValue.boolean, 'offset': RiyaValue.offset},
  ),
  RiyaCapability('medicine.doses', 'Read doses for a day', '/medicine', {
    'medicineId': RiyaValue.integer,
    'day': RiyaValue.date,
    'offset': RiyaValue.offset,
  }),
  RiyaCapability(
    'medicine.taken',
    'Mark or correct a dose log',
    '/medicine',
    {'id': RiyaValue.integer, 'taken': RiyaValue.boolean},
    required: ['id', 'taken'],
    write: true,
  ),
];

class RiyaMedicineActions {
  RiyaMedicineActions(this.db, this.clock);
  final AppDatabase db;
  final DateTime Function() clock;
  bool handles(String id) => riyaMedicineCapabilities.any((c) => c.id == id);
  String excerpt(String text) =>
      text.length <= 150 ? text : '${text.substring(0, 147)}…';
  Future<RiyaResult> run(RiyaCommand command) async {
    final a = command.arguments;
    final service = MedicineService(db, syncAlerts: false, clock: clock);
    if (command.id == 'medicine.list') {
      final rows =
          await (db.select(db.medicineTable)
                ..where(
                  (m) => a['all'] == true
                      ? const Constant(true)
                      : m.isActive.equals(true),
                )
                ..orderBy([
                  (m) => OrderingTerm.desc(m.createdAt),
                  (m) => OrderingTerm.desc(m.id),
                ])
                ..limit(4, offset: a['offset'] as int? ?? 0))
              .get();
      return RiyaResult(
        rows.isEmpty
            ? 'No saved ${a['all'] == true ? '' : 'active '}medicine schedules.'
            : 'Saved schedules:\n${rows.take(3).map((m) => '#${m.id} ${excerpt(m.name)} · ${m.dosage} · ${m.isActive ? 'active' : 'paused'}').join('\n')}',
        '/medicine',
        options: [
          if (rows.length > 3) 'More medicines',
          'Medicines all',
          'Doses today',
        ],
      );
    }
    if (command.id == 'medicine.doses') {
      final day = a['day'] == null
          ? clock()
          : DateTime.parse(a['day']).toLocal();
      final date =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final rows =
          await (db.select(db.medicineLogTable)
                ..where(
                  (l) =>
                      l.dateStr.equals(date) &
                      (a['medicineId'] == null
                          ? const Constant(true)
                          : l.medicineId.equals(a['medicineId'])),
                )
                ..orderBy([
                  (l) => OrderingTerm.asc(l.timeSlot),
                  (l) => OrderingTerm.asc(l.id),
                ])
                ..limit(4, offset: a['offset'] as int? ?? 0))
              .get();
      final lines = <String>[];
      for (final dose in rows.take(3)) {
        final medicine = await db.medicineDao.getMedicineById(dose.medicineId);
        lines.add(
          'Dose #${dose.id} · ${dose.timeSlot} · ${excerpt(medicine?.name ?? 'Schedule #${dose.medicineId}')} · ${dose.isTaken ? 'taken' : 'pending'}',
        );
      }
      return RiyaResult(
        '$date:\n${lines.isEmpty ? 'No recorded doses for this day.' : lines.join('\n')}',
        '/medicine',
        options: [if (rows.length > 3) 'More doses', 'Doses tomorrow'],
      );
    }
    if (command.id == 'medicine.taken') {
      final log = await (db.select(
        db.medicineLogTable,
      )..where((l) => l.id.equals(a['id']))).getSingleOrNull();
      if (log == null) throw StateError('This dose no longer exists');
      await service.toggleDose(log.id, a['taken']);
      return RiyaResult(
        'Dose #${log.id} marked ${a['taken'] == true ? 'taken' : 'pending'}.',
        '/medicine',
        cancelReminderIds: a['taken'] == true && log.linkedReminderId != null
            ? [log.linkedReminderId!]
            : [],
        reminderIds: a['taken'] == false && log.linkedReminderId != null
            ? [log.linkedReminderId!]
            : [],
      );
    }
    if (command.id == 'medicine.create') {
      if (a['active'] == false) {
        throw ArgumentError('Create a schedule before pausing it');
      }
      final id = await service.addMedicine(
        name: a['name'],
        dosage: a['dosage'],
        scheduledTimes: (a['times'] as List).cast<String>(),
        durationDays: a['days'],
        startDate: a['startDate'] == null
            ? clock()
            : DateTime.parse(a['startDate']).toLocal(),
        instructions: a['instructions'] as String? ?? 'As recorded',
        type: a['form'] as String? ?? 'tablet',
      );
      return _saved(id);
    }
    final medicine = await db.medicineDao.getMedicineById(a['id']);
    if (medicine == null) {
      throw StateError('This medicine schedule no longer exists');
    }
    if (command.id == 'medicine.read') {
      return RiyaResult(
        '#${medicine.id} ${medicine.name}\n${medicine.dosage} · ${(jsonDecode(medicine.scheduledTimes) as List).join(', ')}\n${medicine.durationDays} days from ${medicine.startDate.toIso8601String()} · ${medicine.instructions} · ${medicine.isActive ? 'active' : 'paused'}',
        '/medicine',
        entityType: 'medicine',
        entityId: medicine.id,
      );
    }
    if (command.id == 'medicine.delete') {
      final logs = await db.medicineDao.watchLogsForMedicine(medicine.id).first;
      await service.deleteMedicine(medicine.id);
      return RiyaResult(
        'Deleted schedule #${medicine.id} and its linked dose records, tasks and reminders.',
        '/medicine',
        cancelReminderIds: logs
            .map((l) => l.linkedReminderId)
            .whereType<int>()
            .toList(),
      );
    }
    if (a.length == 1) throw ArgumentError('Choose a schedule field to change');
    await service.updateMedicine(
      medicine.id,
      name: a['name'],
      dosage: a['dosage'],
      scheduledTimes: (a['times'] as List?)?.cast<String>(),
      durationDays: a['days'],
      startDate: a['startDate'] == null
          ? null
          : DateTime.parse(a['startDate']).toLocal(),
      instructions: a['instructions'],
      type: a['form'],
      active: a['active'],
    );
    return _saved(medicine.id);
  }

  Future<RiyaResult> _saved(int id) async {
    final logs = await db.medicineDao.watchLogsForMedicine(id).first;
    return RiyaResult(
      'Saved medicine schedule #$id. Historical doses were preserved; upcoming alerts still need device scheduling.',
      '/medicine',
      entityType: 'medicine',
      entityId: id,
      reminderIds: logs
          .map((l) => l.linkedReminderId)
          .whereType<int>()
          .toList(),
    );
  }
}
