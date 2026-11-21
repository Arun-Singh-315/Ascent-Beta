import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/today/models/things_intelligence.dart';
import 'package:ascent/features/today/widgets/things_interactive_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayActivityItem makeActivity({
  required String id,
  required String title,
  String? notes,
  ActivityKind kind = ActivityKind.todo,
  TodayActivityStatus status = TodayActivityStatus.notStarted,
  int? targetMinutes,
  String sourceType = 'task',
  String priority = 'normal',
  int? linkedTaskId,
  bool isOverdue = false,
  DateTime? scheduledTime,
}) => TodayActivityItem(
  id: id,
  title: title,
  notes: notes,
  kind: kind,
  status: status,
  sourceType: sourceType,
  categoryTag: 'Task',
  elapsedSecondsToday: 0,
  targetMinutes: targetMinutes,
  priority: priority,
  linkedTaskId: linkedTaskId,
  isOverdue: isOverdue,
  scheduledTime: scheduledTime,
);

class _FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
    todaySeconds: 0,
    yesterdaySeconds: 0,
    priorStreakDays: 0,
    historicalLongestStreak: 0,
    historicalShortestStreak: 1,
    now: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('ThingsEnrichmentEngine Semantic Intent Classification', () {
    test('classifies medical and health tasks with appropriate blueprint', () {
      final doc = ThingsEnrichmentEngine.analyzeText(
        'Visit dentist for checkup',
      );
      expect(doc.categoryLabel, 'Health & Medical');
      expect(doc.smartLens, ThingsSmartLens.quickWins);
      expect(doc.microSteps.length, 3);
      expect(
        doc.actionChips.any((c) => c.type == ThingsActionType.complete),
        isTrue,
      );

      final med = ThingsEnrichmentEngine.analyzeText(
        'Take thyroid pill',
        sourceType: 'medicine',
      );
      expect(med.categoryLabel, 'Health & Medical');
    });

    test('classifies finance and bill payments with money action chips', () {
      final bill = ThingsEnrichmentEngine.analyzeText(
        'Pay broadband and electricity bill',
      );
      expect(bill.categoryLabel, 'Finance & Bills');
      expect(bill.smartLens, ThingsSmartLens.quickWins);
      expect(
        bill.actionChips.any((c) => c.type == ThingsActionType.moneyLog),
        isTrue,
      );
    });

    test(
      'classifies deep focus and engineering tasks with focus timer chip',
      () {
        final code = ThingsEnrichmentEngine.analyzeText(
          'Implement Uber ride matching system design',
        );
        expect(code.categoryLabel, 'Deep Focus & Engineering');
        expect(code.smartLens, ThingsSmartLens.deepFocus);
        expect(code.suggestedMinutes, greaterThanOrEqualTo(25));
        expect(
          code.actionChips.any((c) => c.type == ThingsActionType.focusTimer),
          isTrue,
        );
      },
    );

    test('classifies travel and logistics tasks', () {
      final trip = ThingsEnrichmentEngine.analyzeText(
        'Book flight to Bangalore and pack luggage',
      );
      expect(trip.categoryLabel, 'Travel & Logistics');
      expect(trip.smartLens, ThingsSmartLens.lifeErrands);
      expect(trip.microSteps.any((s) => s.contains('PNR')), isTrue);
    });

    test('classifies groceries and errands', () {
      final grocery = ThingsEnrichmentEngine.analyzeText(
        'Buy fresh vegetables and almond milk from supermarket',
      );
      expect(grocery.categoryLabel, 'Errands & Home');
      expect(grocery.smartLens, ThingsSmartLens.lifeErrands);
      expect(
        grocery.actionChips.any((c) => c.type == ThingsActionType.moneyLog),
        isTrue,
      );
    });

    test('classifies people, comms and sync meetings', () {
      final comms = ThingsEnrichmentEngine.analyzeText(
        'Quick Zoom meeting with design team to sync',
      );
      expect(comms.categoryLabel, 'People & Comms');
      expect(comms.smartLens, ThingsSmartLens.quickWins);
    });

    test('classifies sanctuary, relaxation and wind-down', () {
      final wind = ThingsEnrichmentEngine.analyzeText(
        'Read chapter 4 and evening chai wind down',
      );
      expect(wind.categoryLabel, 'Sanctuary & Unwind');
      expect(wind.smartLens, ThingsSmartLens.windDown);
    });
  });

  group('ThingsHeroCard & ThingsInteractiveCard Intelligence Interactions', () {

    testWidgets(
      'ThingsInteractiveCard toggles blueprint inline in activity lists',
      (tester) async {
        final activity = makeActivity(
          id: 'interactive_1',
          title: 'Pay electricity bill',
          linkedTaskId: 202,
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(
              () => _FakeTimeTrackingNotifier(),
            ),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ThingsInteractiveCard(activity: activity),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Category pill and Blueprint button rendered
        expect(find.text('Finance & Bills'), findsOneWidget);
        expect(find.text('Blueprint'), findsOneWidget);

        // Tap Blueprint toggle
        await tester.tap(find.text('Blueprint'));
        await tester.pumpAndSettle();

        expect(find.text('Hide'), findsOneWidget);
        expect(
          find.text('Verify exact due amount & billing period'),
          findsOneWidget,
        );
      },
    );
  });

  group('ThingsHubScreen activity filtering', () {

  });
}
