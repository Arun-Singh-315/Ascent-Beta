import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

bool canEnterWorkspace(UserProfile? profile, SharedPreferences preferences) =>
    (preferences.getBool('ascent_quick_start_v1') ?? false) ||
    (profile != null &&
        profile.onboardingComplete &&
        profile.name.trim().isNotEmpty);

// ── SharedPreferences provider ───────────────────────────────────────────────

/// Provider for [SharedPreferences] — initialized in main before runApp
/// or overridden in tests. Throws if accessed before initialization.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with ProviderScope overrides.\n'
    'Initialize SharedPreferences in main() and override this provider.',
  );
});

// ── Theme mode ───────────────────────────────────────────────────────────────

const _themeModeKey = 'ascent_theme_mode';

/// Notifier that persists the user's theme preference.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _values = {
    'system': ThemeMode.system,
    'light': ThemeMode.light,
    'dark': ThemeMode.dark,
  };

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(_themeModeKey) ?? 'system';
    return _values[stored] ?? ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final key = _values.entries.firstWhere((e) => e.value == mode).key;
    await prefs.setString(_themeModeKey, key);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ── Daylight Theme Preset ───────────────────────────────────────────────────

enum DayThemePreset {
  merlotLinen,
  classicClay,
  nordicSky,
}

const _dayThemePresetKey = 'ascent_day_theme_preset';

class DayThemePresetNotifier extends Notifier<DayThemePreset> {
  static const _values = {
    'merlotLinen': DayThemePreset.merlotLinen,
    'classicClay': DayThemePreset.classicClay,
    'nordicSky': DayThemePreset.nordicSky,
  };

  @override
  DayThemePreset build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(_dayThemePresetKey) ?? 'merlotLinen';
    if (stored == 'auroraCalm') {
      return DayThemePreset.merlotLinen;
    }
    return _values[stored] ?? DayThemePreset.merlotLinen;
  }

  Future<void> setPreset(DayThemePreset preset) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final key = _values.entries.firstWhere((e) => e.value == preset).key;
    await prefs.setString(_dayThemePresetKey, key);
    state = preset;
  }
}

final dayThemePresetProvider =
    NotifierProvider<DayThemePresetNotifier, DayThemePreset>(
      DayThemePresetNotifier.new,
    );

// ── Onboarding complete ──────────────────────────────────────────────────────

const _onboardingKey = 'ascent_onboarding_complete';

final onboardingCompleteProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(_onboardingKey) ?? false;
});

Future<void> markOnboardingComplete(WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.setBool(_onboardingKey, true);
  ref.invalidate(onboardingCompleteProvider);
}

// ── Last opened date ─────────────────────────────────────────────────────────

const _lastOpenedKey = 'ascent_last_opened';
const _previousOpenedKey = 'ascent_previous_opened';

final daysSinceLastOpenProvider = Provider<int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final stored = prefs.getString(_previousOpenedKey);
  if (stored == null) return 999; // First open ever
  final last = DateTime.tryParse(stored);
  if (last == null) return 999;
  return DateTime.now().difference(last).inDays;
});

Future<void> touchLastOpened(SharedPreferences prefs) async {
  final currentLast = prefs.getString(_lastOpenedKey);
  if (currentLast != null) {
    await prefs.setString(_previousOpenedKey, currentLast);
  }
  await prefs.setString(_lastOpenedKey, DateTime.now().toIso8601String());
}

// ── Assistant name (Riya by default) ────────────────────────────────────────

const _assistantNameKey = 'ascent_assistant_name';

/// The user-configurable name for the AI assistant. Defaults to 'Riya'.
/// Changing this updates all references throughout the app.
class AssistantNameNotifier extends Notifier<String> {
  @override
  String build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      return prefs.getString(_assistantNameKey) ?? 'Riya';
    } catch (_) {
      return 'Riya';
    }
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_assistantNameKey, trimmed);
    } catch (_) {}
    state = trimmed;
  }

  void reset() {
    setName('Riya');
  }
}

final assistantNameProvider = NotifierProvider<AssistantNameNotifier, String>(
  AssistantNameNotifier.new,
);

// ── Raw Boost Tone & Follow-up Nudges Preferences ─────────────────────────

const _rawBoostToneKey = 'ascent_raw_boost_tone_enabled';
const _accountabilityFollowUpKey = 'ascent_accountability_followup_enabled';

class RawBoostToneNotifier extends Notifier<bool> {
  @override
  bool build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      return prefs.getBool(_rawBoostToneKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(_rawBoostToneKey, enabled);
    } catch (_) {}
    state = enabled;
  }
}

final rawBoostToneEnabledProvider =
    NotifierProvider<RawBoostToneNotifier, bool>(RawBoostToneNotifier.new);

class AccountabilityFollowUpNotifier extends Notifier<bool> {
  @override
  bool build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      return prefs.getBool(_accountabilityFollowUpKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(_accountabilityFollowUpKey, enabled);
    } catch (_) {}
    state = enabled;
  }
}

final accountabilityFollowUpEnabledProvider =
    NotifierProvider<AccountabilityFollowUpNotifier, bool>(
      AccountabilityFollowUpNotifier.new,
    );
