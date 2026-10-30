import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/security/app_lock_provider.dart';
import 'package:ascent/core/security/app_lock_gate.dart';
import 'package:ascent/features/vault/providers/vault_providers.dart';
import 'package:ascent/features/vault/services/vault_security_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:ascent/app/app.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/pending_reminder_effects_provider.dart';
import 'package:ascent/core/notifications/promise_check_ins_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late VaultSecurityService testSecurityService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    testSecurityService = VaultSecurityService.forTesting(
      mockBiometricsSuccess: true,
    );
  });

  Widget buildTestApp({required Widget child, AppLockNotifier? notifier}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        vaultSecurityServiceProvider.overrideWithValue(testSecurityService),
      ],
      child: MaterialApp(theme: AscentTheme.light(), home: child),
    );
  }

  group('AppLockProvider State & Logic Tests', () {
    test(
      'Defaults to unlocked and disabled when no preference is saved',
      () async {
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            vaultSecurityServiceProvider.overrideWithValue(testSecurityService),
          ],
        );
        addTearDown(container.dispose);

        final state = container.read(appLockProvider);
        expect(state.isEnabled, isFalse);
        expect(state.isLocked, isFalse);
        expect(state.allowNotifications, isTrue);
        expect(state.redactNotificationContent, isTrue);
        expect(state.hasMasterPin, isFalse);
      },
    );

    test('Setting master PIN updates hasMasterPin and unlocks', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          vaultSecurityServiceProvider.overrideWithValue(testSecurityService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(appLockProvider.notifier);
      final setSuccess = await notifier.setPin('1234');
      expect(setSuccess, isTrue);
      expect(container.read(appLockProvider).hasMasterPin, isTrue);

      final verifySuccess = await notifier.verifyPin('1234');
      expect(verifySuccess, isTrue);

      final verifyFail = await notifier.verifyPin('0000');
      expect(verifyFail, isFalse);
    });

    test('Toggling App Lock requires PIN setup', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          vaultSecurityServiceProvider.overrideWithValue(testSecurityService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(appLockProvider.notifier);
      // Without PIN, enabling fails
      final toggleWithoutPin = await notifier.toggleAppLock(true);
      expect(toggleWithoutPin, isFalse);
      expect(container.read(appLockProvider).isEnabled, isFalse);

      // Now set PIN and enable
      await notifier.setPin('4321');
      final toggleWithPin = await notifier.toggleAppLock(true);
      expect(toggleWithPin, isTrue);
      expect(container.read(appLockProvider).isEnabled, isTrue);

      // Toggling preferences persists
      await notifier.setAllowNotifications(false);
      expect(container.read(appLockProvider).allowNotifications, isFalse);
      expect(prefs.getBool(kAppLockAllowNotificationsKey), isFalse);

      await notifier.setRedactContent(false);
      expect(
        container.read(appLockProvider).redactNotificationContent,
        isFalse,
      );
      expect(prefs.getBool(kAppLockRedactContentKey), isFalse);
    });

    test('Locking when enabled sets isLocked to true', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          vaultSecurityServiceProvider.overrideWithValue(testSecurityService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(appLockProvider.notifier);
      await notifier.setPin('9999');
      await notifier.toggleAppLock(true);

      notifier.lock();
      expect(container.read(appLockProvider).isLocked, isTrue);

      // Verify PIN unlocks
      await notifier.verifyPin('9999');
      expect(container.read(appLockProvider).isLocked, isFalse);
    });
  });

  group('AppLockGate & AppLockScreen UI Tests', () {
    testWidgets('Renders child directly when app lock is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const AppLockGate(
            child: Scaffold(body: Text('Protected Workspace Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protected Workspace Content'), findsOneWidget);
      expect(find.byKey(const ValueKey('app_lock_screen')), findsNothing);
    });

    testWidgets('Renders lock screen when app lock is enabled and locked', (
      tester,
    ) async {
      await testSecurityService.setMasterPin('1234');
      await prefs.setBool(kAppLockEnabledKey, true);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          vaultSecurityServiceProvider.overrideWithValue(testSecurityService),
        ],
      );
      addTearDown(container.dispose);

      // Force lock state
      container.read(appLockProvider.notifier).lock();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const AppLockGate(
              child: Scaffold(body: Text('Secret Content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('app_lock_screen')), findsOneWidget);
      expect(find.text('Ascent Locked'), findsOneWidget);
      expect(find.text('Secret Content'), findsNothing);

      // Tap digits 1, 2, 3, 4
      await tester.tap(find.byKey(const ValueKey('keypad_1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('keypad_2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('keypad_3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('keypad_4')));
      await tester.pumpAndSettle();

      // Now unlocked! Secret content becomes visible!
      expect(find.text('Secret Content'), findsOneWidget);
      expect(find.byKey(const ValueKey('app_lock_screen')), findsNothing);
    });
  });

  testWidgets(
    'Inactive privacy cover does not relock; actual backgrounding locks and preserves the workspace',
    (tester) async {
      await testSecurityService.setMasterPin('1234');
      await prefs.setBool(kAppLockEnabledKey, true);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          vaultSecurityServiceProvider.overrideWithValue(testSecurityService),
        ],
      );
      addTearDown(container.dispose);
      final controller = TextEditingController(text: 'Unsaved draft');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: AppLockGate(
              child: Scaffold(body: TextField(controller: controller)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final notifier = container.read(appLockProvider.notifier);
      await notifier.verifyPin('1234');
      await tester.pumpAndSettle();
      final workspace = tester.element(find.byType(TextField));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(container.read(appLockProvider).isLocked, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.element(find.byType(TextField)), same(workspace));
      expect(find.byKey(const ValueKey('app_lock_screen')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(container.read(appLockProvider).isLocked, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const ValueKey('app_lock_screen')), findsOneWidget);
      expect(await notifier.verifyPin('0000'), isFalse);
      expect(container.read(appLockProvider).isLocked, isTrue);
      await notifier.verifyPin('1234');
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(TextField)), same(workspace));
      expect(controller.text, 'Unsaved draft');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Root builder lock has its own overlay for biometric and delete tooltips',
    (tester) async {
      await testSecurityService.setMasterPin('1234');
      await prefs.setBool(kAppLockEnabledKey, true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            vaultSecurityServiceProvider.overrideWithValue(testSecurityService),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            builder: (_, child) => AppLockGate(child: child!),
            home: const Scaffold(body: Text('Private workspace')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('keypad_biometrics')), findsOneWidget);
      expect(find.byKey(const ValueKey('keypad_backspace')), findsOneWidget);

      await tester.longPress(find.byKey(const ValueKey('keypad_biometrics')));
      await tester.pumpAndSettle();
      expect(find.text('Use biometrics'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('keypad_1')));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('keypad_backspace')));
      await tester.pumpAndSettle();
      expect(find.text('Delete digit'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'AscentApp real root layout provides overlay for lock screen biometric and delete tooltips',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.userProfileDao.upsertProfile(
        const UserProfileTableCompanion(
          name: drift.Value('Test User'),
          targetRole: drift.Value('Software Engineer'),
          onboardingComplete: drift.Value(true),
        ),
      );
      await testSecurityService.setMasterPin('1234');
      await prefs.setBool(kAppLockEnabledKey, true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            vaultSecurityServiceProvider.overrideWithValue(testSecurityService),
            databaseProvider.overrideWithValue(db),
            pendingReminderEffectsProvider.overrideWith((ref) {}),
            promiseCheckInsProvider.overrideWith((ref) {}),
          ],
          child: const AscentApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const ValueKey('app_lock_screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('keypad_biometrics')), findsOneWidget);
      expect(find.byKey(const ValueKey('keypad_backspace')), findsOneWidget);

      await tester.longPress(find.byKey(const ValueKey('keypad_biometrics')));
      await tester.pumpAndSettle();
      expect(find.text('Use biometrics'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('keypad_1')));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('keypad_backspace')));
      await tester.pumpAndSettle();
      expect(find.text('Delete digit'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  group('SettingsScreen Security & App Lock Integration Tests', () {
    testWidgets(
      'Settings screen renders Security & App Lock section with controls',
      (tester) async {
        await tester.pumpWidget(buildTestApp(child: const SettingsScreen()));
        await tester.pumpAndSettle();

        final target = find.text('Security & App Lock');
        await tester.scrollUntilVisible(
          target,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(target, findsOneWidget);
        expect(
          find.byKey(const ValueKey('setting_app_lock_switch')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('setting_redact_notifications_switch')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('setting_allow_notifications_switch')),
          findsOneWidget,
        );
      },
    );
  });
}
