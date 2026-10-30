import 'dart:async';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/security/app_lock_provider.dart';
import 'package:ascent/features/vault/providers/vault_providers.dart';
import 'package:ascent/features/vault/services/vault_security_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelayedSecurity extends VaultSecurityService {
  DelayedSecurity() : super(isTest: true);
  final initialization = Completer<bool>();
  final authentication = Completer<bool>();
  int prompts = 0;
  @override
  Future<bool> hasMasterPin() => initialization.future;
  @override
  Future<bool> canAuthenticateWithBiometrics() async => true;
  @override
  Future<bool> authenticateBiometrics({String reason = ''}) {
    prompts++;
    return authentication.future;
  }

  @override
  Future<bool> verifyPin(String pin) async => pin == '1234';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Delayed initialization cannot relock a completed unlock', () async {
    SharedPreferences.setMockInitialValues({kAppLockEnabledKey: true});
    final prefs = await SharedPreferences.getInstance();
    final service = DelayedSecurity();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        vaultSecurityServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(appLockProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appLockProvider).isLocked, isTrue);
    expect(await notifier.verifyPin('1234'), isTrue);
    service.initialization.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appLockProvider).isLocked, isFalse);
  });
  test(
    'Repeated biometric taps create one native prompt; cancellation remains locked',
    () async {
      SharedPreferences.setMockInitialValues({kAppLockEnabledKey: true});
      final prefs = await SharedPreferences.getInstance();
      final service = DelayedSecurity();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          vaultSecurityServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(appLockProvider.notifier);
      service.initialization.complete(true);
      await Future<void>.delayed(Duration.zero);
      final first = notifier.authenticateBiometrics();
      expect(await notifier.authenticateBiometrics(), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(service.prompts, 1);
      expect(container.read(appLockProvider).isAuthenticating, isTrue);
      service.authentication.complete(false);
      expect(await first, isFalse);
      expect(container.read(appLockProvider).isAuthenticating, isFalse);
      expect(container.read(appLockProvider).isLocked, isTrue);
    },
  );
}
