import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/notifications/things_check_in.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayActivityItem makeActivity({
  required String id,
  required String title,
  ActivityKind kind = ActivityKind.todo,
  TodayActivityStatus status = TodayActivityStatus.notStarted,
  int? targetMinutes,
  String sourceType = 'task',
  String priority = 'normal',
  int? linkedTaskId,
}) => TodayActivityItem(
  id: id,
  title: title,
  kind: kind,
  status: status,
  sourceType: sourceType,
  categoryTag: 'Task',
  elapsedSecondsToday: 0,
  targetMinutes: targetMinutes,
  priority: priority,
  linkedTaskId: linkedTaskId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 1 & 3: Deep Link & Notifications Contract', () {
    test(
      'routes /things and /history preserving focus and wrapup parameters',
      () {
        expect(
          NotificationService.destinationForPayload(
            '/things?focus=101&mode=wrapup',
          ),
          '/things?focus=101&mode=wrapup',
        );
        expect(
          NotificationService.destinationForPayload(
            '/history?module=hydration',
          ),
          '/history?module=hydration',
        );
        expect(
          NotificationService.destinationForPayload(
            'ascent://open/things?focus=101',
          ),
          '/things?focus=101',
        );
        expect(
          NotificationService.destinationForPayload('ascent://things'),
          '/things',
        );
      },
    );

    test('ThingsCheckIn carries task id, payload and actions', () async {
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Ship Beta release',
          priority: const drift.Value('high'),
        ),
      );

      final plan = ThingsCheckIn.plan(
        now: DateTime(2026, 11, 2, 9),
        tasks: await db.select(db.taskTable).get(),
        reminders: await db.select(db.reminderTable).get(),
        horizonDays: 7,
      );

      expect(plan.length, 14);
      final firstMidday = plan.firstWhere(
        (p) => p.type == ThingsNotificationType.middayCheckIn,
      );
      expect(firstMidday.taskId, taskId);
      expect(firstMidday.payload, '/things?focus=$taskId');
      expect(
        firstMidday.actions,
        containsAll(['things_start', 'things_done', 'things_snooze']),
      );

      final firstWrapup = plan.firstWhere(
        (p) => p.type == ThingsNotificationType.eveningWrapUp,
      );
      expect(firstWrapup.taskId, taskId);
      expect(firstWrapup.payload, '/things?focus=$taskId&mode=wrapup');
      expect(
        firstWrapup.actions,
        containsAll(['things_carry', 'things_review']),
      );
    });
  });

  group('Phase 2: Things Hub Hero & Day Progress Line', () {
  });

  group('Button Accessibility & Semantics', () {
    testWidgets(
      'AscentButton announces busy and exposes Semantics onTap action',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: Center(
                child: AscentButton.primary(
                  label: 'Save Changes',
                  loading: true,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Semantic label should include busy announcement
        final semanticsFinder = find.byWidgetPredicate(
          (w) =>
              w is Semantics && (w.properties.label?.contains('busy') ?? false),
        );
        expect(semanticsFinder, findsOneWidget);
      },
    );
  });
}
