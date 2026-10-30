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
import 'package:ascent/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late VaultSecurityService testSecurityService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    testSecurityService = VaultSecurityService.forTesting(mockBiometricsSuccess: true);
  });

  Widget buildTestApp({
    required Widget child,
    AppLockNotifier? notifier,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        vaultSecurityServiceProvider.overrideWithValue(testSecurityService),
      ],
      child: MaterialApp(
        theme: AscentTheme.light(),
        home: child,
      ),
    );
  }

  group('AppLockProvider State & Logic Tests', () {
    test('Defaults to unlocked and disabled when no preference is saved', () async {
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
    });

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
      expect(container.read(appLockProvider).redactNotificationContent, isFalse);
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
    testWidgets('Renders child directly when app lock is disabled', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const AppLockGate(
            child: Scaffold(
              body: Text('Protected Workspace Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protected Workspace Content'), findsOneWidget);
      expect(find.byKey(const ValueKey('app_lock_screen')), findsNothing);
    });

    testWidgets('Renders lock screen when app lock is enabled and locked', (tester) async {
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
              child: Scaffold(
                body: Text('Secret Content'),
              ),
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

  group('SettingsScreen Security & App Lock Integration Tests', () {
    testWidgets('Settings screen renders Security & App Lock section with controls', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final target = find.text('Security & App Lock');
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(target, findsOneWidget);
      expect(find.byKey(const ValueKey('setting_app_lock_switch')), findsOneWidget);
      expect(find.byKey(const ValueKey('setting_redact_notifications_switch')), findsOneWidget);
      expect(find.byKey(const ValueKey('setting_allow_notifications_switch')), findsOneWidget);
    });
  });
}
