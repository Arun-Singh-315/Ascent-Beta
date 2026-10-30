import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../../features/vault/providers/vault_providers.dart';
import '../../features/vault/services/vault_security_service.dart';

const String kAppLockEnabledKey = 'ascent_app_lock_enabled_v1';
const String kAppLockAllowNotificationsKey =
    'ascent_app_lock_allow_notifications_v1';
const String kAppLockRedactContentKey = 'ascent_app_lock_redact_content_v1';
const String kAppLockBiometricsEnabledKey =
    'ascent_app_lock_biometrics_enabled_v1';

class AppLockState {
  const AppLockState({
    this.isEnabled = false,
    this.isLocked = false,
    this.allowNotifications = true,
    this.redactNotificationContent = true,
    this.biometricsEnabled = true,
    this.hasMasterPin = false,
    this.isAuthenticating = false,
  });

  final bool isEnabled;
  final bool isLocked;
  final bool allowNotifications;
  final bool redactNotificationContent;
  final bool biometricsEnabled;
  final bool hasMasterPin;
  final bool isAuthenticating;

  AppLockState copyWith({
    bool? isEnabled,
    bool? isLocked,
    bool? allowNotifications,
    bool? redactNotificationContent,
    bool? biometricsEnabled,
    bool? hasMasterPin,
    bool? isAuthenticating,
  }) {
    return AppLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      allowNotifications: allowNotifications ?? this.allowNotifications,
      redactNotificationContent:
          redactNotificationContent ?? this.redactNotificationContent,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      hasMasterPin: hasMasterPin ?? this.hasMasterPin,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
    );
  }
}

class AppLockNotifier extends Notifier<AppLockState> {
  int _generation = 0;
  @override
  AppLockState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final enabled = prefs.getBool(kAppLockEnabledKey) ?? false;
    final allowNotifs = prefs.getBool(kAppLockAllowNotificationsKey) ?? true;
    final redact = prefs.getBool(kAppLockRedactContentKey) ?? true;
    final biometrics = prefs.getBool(kAppLockBiometricsEnabledKey) ?? true;

    final generation = _generation;
    Future.microtask(() async {
      final hasPin = await ref
          .read(vaultSecurityServiceProvider)
          .hasMasterPin();
      if (!ref.mounted || generation != _generation) return;
      // Initialization may finish after a successful unlock. Never relock it.
      state = state.copyWith(
        hasMasterPin: hasPin,
        isEnabled: state.isEnabled && hasPin,
        isLocked: state.isLocked && hasPin,
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
    _generation++;
    if (pin.length < 4) return false;
    await _security.setMasterPin(pin);
    state = state.copyWith(hasMasterPin: true, isLocked: false);
    return true;
  }

  Future<bool> verifyPin(String pin) =>
      _authenticate(() => _security.verifyPin(pin));

  Future<bool> authenticateBiometrics() => _authenticate(() async {
    if (!await _security.canAuthenticateWithBiometrics()) return false;
    return _security.authenticateBiometrics(
      reason: 'Unlock Ascent to access your workspace',
    );
  });

  Future<bool> _authenticate(Future<bool> Function() action) async {
    if (state.isAuthenticating) return false;
    _generation++;
    state = state.copyWith(isAuthenticating: true);
    try {
      final ok = await action();
      if (ok && ref.mounted) {
        state = state.copyWith(isLocked: false, hasMasterPin: true);
      }
      return ok;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(isAuthenticating: false);
    }
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
    _generation++;
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

final appLockProvider = NotifierProvider<AppLockNotifier, AppLockState>(
  AppLockNotifier.new,
);
