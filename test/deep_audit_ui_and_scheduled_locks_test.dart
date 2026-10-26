import 'dart:convert';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/medicine/medicine_screen.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/widgets/promise_card.dart';
import 'package:ascent/features/promises/widgets/promise_action_button.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdleTracking extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _IdleLearning extends LearningHubNotifier {
  @override
  LearningHubState build() => const LearningHubState(
    courses: [],
    activeCourseId: '',
    activeLectureId: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(_IdleTracking.new),
        learningHubProvider.overrideWith(_IdleLearning.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Medicine Screen Scheduled Lock & Empty State Tests', () {
    testWidgets('Empty state shows concise message and Add Medicine button', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const MedicineScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No medicines added'), findsOneWidget);
      expect(
        find.text('Track daily doses, exact times, and courses here.'),
        findsOneWidget,
      );
      expect(find.text('Add Medicine'), findsOneWidget);
    });

    testWidgets(
      'Future scheduled medicine dose displays locked schedule badge and explains on tap',
      (tester) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dateStr = DateFormat('yyyy-MM-dd').format(today);

        final medId = await db.medicineDao.insertMedicine(
          MedicineTableCompanion.insert(
            name: 'Evening Med',
            dosage: '1 tablet',
            type: const drift.Value('tablet'),
            scheduledTimes: jsonEncode(['23:59']),
            durationDays: const drift.Value(7),
            startDate: today,
          ),
        );

        final logId = await db.medicineDao.insertMedicineLog(
          MedicineLogTableCompanion.insert(
            medicineId: medId,
            dateStr: dateStr,
            timeSlot: '23:59',
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const MedicineScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should NOT show active 'Take' chip
        expect(find.text('Take'), findsNothing);

        // Should show scheduled time chip e.g. 'At 11:59 PM'
        expect(find.text('At 11:59 PM'), findsOneWidget);

        // Tapping the scheduled chip informs user without prematurely completing
        await tester.tap(find.text('At 11:59 PM'));
        await tester.pumpAndSettle();

        expect(
          find.text('Scheduled for 11:59 PM. Available once time arrives.'),
          findsOneWidget,
        );

        final logs = await (db.select(db.medicineLogTable)..where((l) => l.id.equals(logId))).get();
        expect(logs.first.isTaken, isFalse);
      },
    );

    testWidgets(
      'Due or past-due medicine dose displays active Take chip and records completion',
      (tester) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dateStr = DateFormat('yyyy-MM-dd').format(today);

        final medId = await db.medicineDao.insertMedicine(
          MedicineTableCompanion.insert(
            name: 'Morning Med',
            dosage: '5ml',
            type: const drift.Value('syrup'),
            scheduledTimes: jsonEncode(['00:01']),
            durationDays: const drift.Value(7),
            startDate: today,
          ),
        );

        final logId = await db.medicineDao.insertMedicineLog(
          MedicineLogTableCompanion.insert(
            medicineId: medId,
            dateStr: dateStr,
            timeSlot: '00:01',
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const MedicineScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 00:01 is in the past, so 'Take' button is present
        expect(find.text('Take'), findsOneWidget);

        await tester.tap(find.text('Take'));
        await tester.pumpAndSettle();

        final logs = await (db.select(db.medicineLogTable)..where((l) => l.id.equals(logId))).get();
        expect(logs.first.isTaken, isTrue);
      },
    );
  });

  group('Promises Screen & PromiseCard Tests', () {
    testWidgets(
      'Promise with future start date displays Starts date badge and explains on tap',
      (tester) async {
        final futureStart = DateTime.now().add(const Duration(days: 30));
        final promise = PromiseModel(
          id: 101,
          title: 'Deep Focus Sprint',
          intention: 'Finish project without distractions',
          category: 'Focus',
          status: PromiseStatus.active,
          trackingType: PromiseTrackingType.completion,
          createdAt: DateTime.now(),
          schedule: PromiseSchedule(
            startDate: futureStart,
            repeat: PromiseRepeat.once,
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(body: PromiseCard(promise: promise)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final expectedLabel = 'Starts ${DateFormat.MMMd().format(futureStart)}';
        expect(find.text(expectedLabel), findsOneWidget);

        // Tap the chip
        await tester.tap(find.text(expectedLabel));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'This commitment starts on ${DateFormat.MMMd().format(futureStart)}. Tracking unlocks on that day.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Promise ready to act displays crisp contextual action button and triggers callback',
      (tester) async {
        bool triggered = false;
        final today = DateTime.now();
        final promise = PromiseModel(
          id: 102,
          title: 'Daily Walk',
          intention: 'Stay active',
          category: 'Health',
          status: PromiseStatus.active,
          trackingType: PromiseTrackingType.completion,
          createdAt: today,
          schedule: PromiseSchedule(
            startDate: today.subtract(const Duration(days: 1)),
            repeat: PromiseRepeat.daily,
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: PromiseActionButton(
                  promise: promise,
                  onPressed: () {
                    triggered = true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mark today done'), findsOneWidget);
        await tester.tap(find.text('Mark today done'));
        await tester.pumpAndSettle();

        expect(triggered, isTrue);
      },
    );
  });

  group('Settings Screen Permissions & Layout Tests', () {
    testWidgets(
      'Phone Settings & Battery section displays App Info & Battery and Location Settings cleanly',
      (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView).first, const Offset(0, -600));
        await tester.pumpAndSettle();

        expect(find.text('App Info & Battery'), findsWidgets);
        expect(find.text('Location Settings'), findsOneWidget);
      },
    );
  });

  group('Accessibility & Rule 13 Immunity Tests', () {
    testWidgets('MedicineScreen renders cleanly at 320px with 2.0x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(2.0),
              ),
              child: const MedicineScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('PromiseCard renders cleanly at 320px with 2.0x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final promise = PromiseModel(
        id: 103,
        title: 'Very Long Commitment Title That Wraps Gracefully Across Lines',
        intention: 'Deep intention with thoughtful text',
        category: 'Personal Development',
        status: PromiseStatus.active,
        trackingType: PromiseTrackingType.completion,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(body: PromiseCard(promise: promise)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
