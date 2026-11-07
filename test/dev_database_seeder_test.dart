import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/database/dev_database_seeder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('DevDatabaseSeeder populates 20 days of medicine, hydration, walks, thoughts, and history', () async {
    await DevDatabaseSeeder.seed20DaysData(db);

    // Verify User Profile
    final profile = await (db.select(db.userProfileTable)..limit(1)).getSingle();
    expect(profile.name, 'Arun Singh');
    expect(profile.targetRole, 'Senior Software Engineer');

    // Verify Medicines & Logs
    final medicines = await db.select(db.medicineTable).get();
    expect(medicines.length, 5);

    final logs = await db.select(db.medicineLogTable).get();
    expect(logs.length, 100); // 5 meds * 20 days = 100 logs
    final takenLogs = logs.where((l) => l.isTaken).toList();
    expect(takenLogs.length, greaterThan(80));

    // Verify Hydration Logs
    final waterLogs = await db.select(db.waterLogTable).get();
    expect(waterLogs.length, greaterThan(80)); // 20 days * multiple logs

    // Verify Walk Sessions
    final walks = await db.select(db.walkSessionTable).get();
    expect(walks.length, 20);

    // Verify Time Sessions (Study Streak)
    final sessions = await db.select(db.timeSessionTable).get();
    expect(sessions.length, 20);

    // Verify Tasks
    final tasks = await db.select(db.taskTable).get();
    expect(tasks.length, greaterThan(30));

    // Verify Thoughts
    final thoughts = await db.select(db.thoughtTable).get();
    expect(thoughts.length, greaterThan(5));

    // Verify History Events
    final historyEvents = await db.select(db.historyEventTable).get();
    expect(historyEvents.length, greaterThan(100));
  });
}
