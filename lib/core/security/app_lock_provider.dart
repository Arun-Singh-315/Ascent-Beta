import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../../features/vault/providers/vault_providers.dart';
import '../../features/vault/services/vault_security_service.dart';

const String kAppLockEnabledKey = 'ascent_app_lock_enabled_v1';
const String kAppLockAllowNotificationsKey = 'ascent_app_lock_allow_notifications_v1';
const String kAppLockRedactContentKey = 'ascent_app_lock_redact_content_v1';
const String kAppLockBiometricsEnabledKey = 'ascent_app_lock_biometrics_enabled_v1';

class AppLockState {
  const AppLockState({
    this.isEnabled = false,
    this.isLocked = false,
    this.allowNotifications = true,
    this.redactNotificationContent = true,
    this.biometricsEnabled = true,
    this.hasMasterPin = false,
  });

  final bool isEnabled;
  final bool isLocked;
  final bool allowNotifications;
  final bool redactNotificationContent;
  final bool biometricsEnabled;
  final bool hasMasterPin;

  AppLockState copyWith({
    bool? isEnabled,
    bool? isLocked,
    bool? allowNotifications,
    bool? redactNotificationContent,
    bool? biometricsEnabled,
    bool? hasMasterPin,
  }) {
    return AppLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      allowNotifications: allowNotifications ?? this.allowNotifications,
      redactNotificationContent:
          redactNotificationContent ?? this.redactNotificationContent,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      hasMasterPin: hasMasterPin ?? this.hasMasterPin,
    );
  }
}

class AppLockNotifier extends Notifier<AppLockState> {
  @override
  AppLockState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final enabled = prefs.getBool(kAppLockEnabledKey) ?? false;
    final allowNotifs = prefs.getBool(kAppLockAllowNotificationsKey) ?? true;
    final redact = prefs.getBool(kAppLockRedactContentKey) ?? true;
    final biometrics = prefs.getBool(kAppLockBiometricsEnabledKey) ?? true;

    Future.microtask(() async {
      final security = ref.read(vaultSecurityServiceProvider);
      final hasPin = await security.hasMasterPin();
      state = state.copyWith(
        hasMasterPin: hasPin,
        isEnabled: enabled && hasPin,
        isLocked: enabled && hasPin,
      );
    });

    return AppLockState(
      isEnabled: enabled,
      isLocked: enabled,
      allowNotifications: allowNotifs,
      redactNotificationContent: redact,
      biometricsEnabled: biometrics,
      hasMasterPin: false,
    );
  }

  VaultSecurityService get _security => ref.read(vaultSecurityServiceProvider);

  Future<bool> setPin(String pin) async {
    if (pin.length < 4) return false;
    await _security.setMasterPin(pin);
    state = state.copyWith(
      hasMasterPin: true,
      isLocked: false,
    );
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    final ok = await _security.verifyPin(pin);
    if (ok) {
      state = state.copyWith(isLocked: false);
      return true;
    }
    return false;
  }

  Future<bool> authenticateBiometrics() async {
    final canAuth = await _security.canAuthenticateWithBiometrics();
    if (!canAuth) return false;
    final ok = await _security.authenticateBiometrics(
      reason: 'Unlock Ascent to access your workspace',
    );
    if (ok) {
      state = state.copyWith(isLocked: false);
      return true;
    }
    return false;
  }

  void lock() {
    if (state.isEnabled) {
      state = state.copyWith(isLocked: true);
    }
  }

  void unlock() {
    state = state.copyWith(isLocked: false);
  }

  Future<bool> toggleAppLock(bool enable) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (enable) {
      final hasPin = await _security.hasMasterPin();
      if (!hasPin) {
        return false;
      }
      await prefs.setBool(kAppLockEnabledKey, true);
      state = state.copyWith(isEnabled: true, isLocked: false);
      return true;
    } else {
      await prefs.setBool(kAppLockEnabledKey, false);
      state = state.copyWith(isEnabled: false, isLocked: false);
      return true;
    }
  }

  Future<void> setAllowNotifications(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(kAppLockAllowNotificationsKey, value);
    state = state.copyWith(allowNotifications: value);
  }

  Future<void> setRedactContent(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(kAppLockRedactContentKey, value);
    state = state.copyWith(redactNotificationContent: value);
  }

  Future<void> setBiometricsEnabled(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(kAppLockBiometricsEnabledKey, value);
    state = state.copyWith(biometricsEnabled: value);
  }
}

final appLockProvider =
    NotifierProvider<AppLockNotifier, AppLockState>(AppLockNotifier.new);
