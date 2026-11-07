import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/reminders/reminders_screen.dart';
import 'package:ascent/shared/widgets/ascent_segmented_control.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Reminders & Alerts': true,
    });
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Reminders Ground Border Style & Apple Reminders UX', () {
    testWidgets('Uses canonical AscentSegmentedControl for active and completed tabs', (
      tester,
    ) async {
      final now = DateTime.now();
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Pay quarterly taxes',
          scheduledAt: now.add(const Duration(hours: 3)),
        ),
      );
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Reviewed quarterly goals',
          scheduledAt: now.subtract(const Duration(days: 1)),
          isActive: const Value(false),
        ),
      );

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
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const RemindersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify canonical AscentSegmentedControl is rendered
      expect(find.byType(AscentSegmentedControl<int>), findsOneWidget);
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);

      // Tap Completed tab
      await tester.tap(find.text('Completed (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Reviewed quarterly goals'), findsOneWidget);
    });

    testWidgets('Renders ground items with Apple-style circular checkbox that completes reminder', (
      tester,
    ) async {
      final now = DateTime.now();
      final id = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Doctor prescription refill',
          scheduledAt: now.subtract(const Duration(hours: 1)), // Overdue
        ),
      );

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
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const RemindersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check section and item title
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Doctor prescription refill'), findsOneWidget);

      // Verify one-tap circular action target is present
      final checkTargetFinder = find.bySemanticsLabel('Mark done');
      expect(checkTargetFinder, findsOneWidget);

      // Tap circular target to complete
      await tester.tap(checkTargetFinder);
      await tester.pumpAndSettle();

      // Verify database updated to inactive
      final saved = await db.reminderDao.getReminderById(id);
      expect(saved!.isActive, isFalse);
    });

    testWidgets('Section headers on ground support expand and collapse toggle', (
      tester,
    ) async {
      final now = DateTime.now();
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Read book chapter',
          scheduledAt: now.add(const Duration(hours: 2)),
        ),
      );

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
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const RemindersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Read book chapter'), findsOneWidget);

      // Tap Today section header to collapse
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.text('Read book chapter'), findsNothing);

      // Tap Today section header again to expand
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.text('Read book chapter'), findsOneWidget);
    });

    testWidgets('Reminders ground list immune to overflow at 320px with 2.0x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'An extremely long reminder title describing critical application submission deadline with detailed requirements',
          scheduledAt: now.add(const Duration(hours: 4)),
          alarmEnabled: const Value(true),
        ),
      );

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
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: const RemindersScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
