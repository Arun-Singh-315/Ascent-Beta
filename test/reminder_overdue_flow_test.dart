import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/reminders/reminders_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SharedPreferences prefs;
  late int id;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Reminders & Alerts': true,
    });
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    id = await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'Missed reminder',
        scheduledAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    );
  });
  tearDown(() => db.close());
  testWidgets(
    'missed active reminders stay Overdue and can be completed from the list',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RemindersScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Missed reminder'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark done'));
      await tester.pumpAndSettle();
      final row = await tester.runAsync(
        () => db.reminderDao.getReminderById(id),
      );
      expect(row!.isActive, false);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );
}
