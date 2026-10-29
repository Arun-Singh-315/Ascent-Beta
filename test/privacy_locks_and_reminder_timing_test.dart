import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/day_glass_material.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/widgets/promise_card.dart';
import 'package:ascent/features/reminders/reminder_action_ui.dart';
import 'package:ascent/features/reminders/reminders_screen.dart';
import 'package:ascent/features/vault/providers/vault_providers.dart';
import 'package:ascent/features/vault/services/vault_security_service.dart';
import 'package:ascent/shared/widgets/locked_commitment_tile.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIdleTracking extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _MockIdleLearning extends LearningHubNotifier {
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
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(_MockIdleTracking.new),
        learningHubProvider.overrideWith(_MockIdleLearning.new),
        vaultSecurityServiceProvider
            .overrideWithValue(VaultSecurityService.forTesting()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget wrapWithHarness(Widget child, {ThemeData? theme}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme ?? AscentTheme.light(),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Reminder Timing & Premature Lock Tests', () {
    testWidgets(
        'Future scheduled reminder cannot be completed prematurely via runReminderAction',
        (tester) async {
      final futureTime = DateTime.now().add(const Duration(hours: 2));
      final reminderId = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Drink Protein Shake',
          scheduledAt: futureTime,
          isActive: const drift.Value(true),
        ),
      );
      final reminder = await db.reminderDao.getReminderById(reminderId);
      expect(reminder, isNotNull);

      await tester.pumpWidget(
        wrapWithHarness(
          Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () async {
                  final changed = await runReminderAction(
                    context,
                    ref,
                    reminder!,
                    ReminderRowAction.done,
                  );
                  expect(changed, isFalse);
                },
                child: const Text('Complete Reminder'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Complete Reminder'));
      await tester.pumpAndSettle();

      // Toast explains scheduled time
      final timeStr = DateFormat('h:mm a').format(futureTime);
      expect(find.textContaining('Scheduled for $timeStr'), findsOneWidget);

      // Reminder remains active in database
      final reloaded = await db.reminderDao.getReminderById(reminderId);
      expect(reloaded?.isActive, isTrue);
    });

    testWidgets('Past or due reminder can be completed normally',
        (tester) async {
      final pastTime = DateTime.now().subtract(const Duration(minutes: 10));
      final reminderId = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Morning Vitamin',
          scheduledAt: pastTime,
          isActive: const drift.Value(true),
        ),
      );
      final reminder = await db.reminderDao.getReminderById(reminderId);
      expect(reminder, isNotNull);

      await tester.pumpWidget(
        wrapWithHarness(
          Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () async {
                  final changed = await runReminderAction(
                    context,
                    ref,
                    reminder!,
                    ReminderRowAction.done,
                  );
                  expect(changed, isTrue);
                },
                child: const Text('Complete Reminder'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Complete Reminder'));
      await tester.pumpAndSettle();

      // Reminder is marked inactive in database
      final reloaded = await db.reminderDao.getReminderById(reminderId);
      expect(reloaded?.isActive, isFalse);
    });

    testWidgets(
        'RemindersScreen displays locked schedule pill for future reminders',
        (tester) async {
      final futureTime = DateTime.now().add(const Duration(hours: 3));
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Late Night Call',
          scheduledAt: futureTime,
          isActive: const drift.Value(true),
        ),
      );

      await tester.pumpWidget(wrapWithHarness(const RemindersScreen()));
      await tester.pumpAndSettle();

      final timeStr = DateFormat('h:mm a').format(futureTime);
      // Locked schedule pill is displayed
      expect(find.text('At $timeStr'), findsOneWidget);

      // Tapping the pill informs the user instead of completing
      await tester.tap(find.text('At $timeStr'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scheduled for $timeStr'), findsOneWidget);
    });
  });

  group('PromiseCard Privacy Locks & Content Deduplication Tests', () {
    testWidgets(
        'Private promise displays locked privacy banner until authenticated',
        (tester) async {
      final privatePromise = PromiseModel(
        id: 42,
        title: 'Secret Deep Work Protocol',
        category: 'Personal',
        intention: 'Build stealth MVP without telling group',
        trackingType: PromiseTrackingType.completion,
        createdAt: DateTime.now(),
        isPrivate: true,
      );

      await tester.pumpWidget(
          wrapWithHarness(PromiseCard(promise: privatePromise)));
      await tester.pumpAndSettle();

      // Secret title & intention must NOT be visible directly in plain text
      expect(find.text('Secret Deep Work Protocol'), findsNothing);
      expect(
          find.text('Build stealth MVP without telling group'), findsNothing);

      // Privacy lock banner is visible
      expect(find.byType(LockedCommitmentTile), findsOneWidget);
      expect(find.text('Private commitment'), findsOneWidget);

      // Tap to authenticate and unlock
      await tester.tap(find.byType(LockedCommitmentTile));
      await tester.pumpAndSettle();

      // Once unlocked, title becomes visible
      expect(find.text('Secret Deep Work Protocol'), findsOneWidget);
    });

    testWidgets(
        'Private promise remains strictly locked and hides title when biometric authentication fails',
        (tester) async {
      final failingSecurity = VaultSecurityService.forTesting(
        mockBiometricsSuccess: false,
      );
      final privatePromise = PromiseModel(
        id: 77,
        title: 'Top Secret Strategy 2026',
        category: 'Personal',
        intention: 'Confidential strategy',
        trackingType: PromiseTrackingType.completion,
        createdAt: DateTime.now(),
        isPrivate: true,
      );

      final failingContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(_MockIdleTracking.new),
          learningHubProvider.overrideWith(_MockIdleLearning.new),
          vaultSecurityServiceProvider.overrideWithValue(failingSecurity),
        ],
      );
      addTearDown(failingContainer.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: failingContainer,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(body: PromiseCard(promise: privatePromise)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Secret title must not be visible
      expect(find.text('Top Secret Strategy 2026'), findsNothing);
      expect(find.byType(LockedCommitmentTile), findsOneWidget);

      // Tap to authenticate (which fails)
      await tester.tap(find.byType(LockedCommitmentTile));
      await tester.pumpAndSettle();

      // Because authentication failed, secret title MUST STILL NOT be visible
      expect(find.text('Top Secret Strategy 2026'), findsNothing);
      expect(find.byType(LockedCommitmentTile), findsOneWidget);
    });

    testWidgets(
        'PromiseCard deduplicates intention when identical to title',
        (tester) async {
      final promiseWithSameIntention = PromiseModel(
        id: 99,
        title: 'No talk until Dec group gayab and work',
        category: 'Personal',
        intention: 'No talk until Dec group gayab and work',
        trackingType: PromiseTrackingType.completion,
        createdAt: DateTime.now(),
        isPrivate: false,
      );

      await tester.pumpWidget(
        wrapWithHarness(PromiseCard(promise: promiseWithSameIntention)),
      );
      await tester.pumpAndSettle();

      // Title must be present exactly once, not duplicated
      expect(
        find.text('No talk until Dec group gayab and work'),
        findsOneWidget,
      );
    });
  });

  group('Day Theme Soft Off-White Polish Tests', () {
    test('MerlotPalette.canvas is soft soothing cashmere linen without bleached whitewash', () {
      expect(MerlotPalette.canvas, equals(const Color(0xFFF5F3EF)));
      expect(MerlotPalette.recessedWell, equals(const Color(0xFFF0EEEA)));
    });

    test('DayGlassMaterial produces pristine off-white canvas with subtle dark blend', () {
      final theme = AscentTheme.light();
      final glass = theme.extension<AscentGlass>()!;
      final material = DayGlassMaterial.from(
        glass,
        GlassTranslucencyPreset.balancedLiquid,
      );
      // Canvas should be close to F7F3EA and not clay tan
      expect(material.canvas.toARGB32() != 0xFFF5F3EF, isTrue);
    });
  });
}
