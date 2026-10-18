import 'package:flutter/foundation.dart';

/// Centralized configuration, limits, storage keys, and channel constants for Ascent.
@immutable
class AppConstants {
  const AppConstants._();

  // ── UI & Preview Scalability Limits ──────────────────────────────────────────
  static const int homePreviewMaxItems = 4;
  static const int homeMindSpacePreviewMaxItems = 4;
  static const int titleMaxCharacters = 300;
  static const int noteMaxCharacters = 2000;
  static const int maxDailyWaterMl = 10000;
  static const double targetNarrowScreenWidth = 320.0;
  static const double targetAccessibilityScale = 2.0;

  // ── Performance Targets ──────────────────────────────────────────────────────
  static const int homeRenderBudgetMs = 100;
  static const Duration defaultDebounce = Duration(milliseconds: 300);
  static const Duration snackBarDuration = Duration(seconds: 4);

  // ── SharedPreferences Storage Keys ──────────────────────────────────────────
  static const String keyDayThemePreset = 'day_theme_preset';
  static const String keyThemeMode = 'theme_mode';
  static const String keyAssistantIdentityName = 'assistant_identity_name';
  static const String keyHomeChallengeId = 'home_challenge_id';
  static const String keyLastOpened = 'last_opened';
  static const String keyTutorialCompletedPrefix = 'tutorial_completed_';
  static const String keyQuietRemindersDefault = 'quiet_reminders_default';
  static const String keyFocusMusicVolume = 'focus_music_volume';
  static const String keyFocusMuted = 'focus_music_muted';

  // ── Notification Channel IDs & Names ─────────────────────────────────────────
  static const String channelRemindersId = 'ascent_reminders';
  static const String channelRemindersName = 'Ascent Reminders';
  static const String channelRemindersDesc = 'Scheduled notifications for tasks, routines, and life check-ins';

  static const String channelAlarmsId = 'ascent_alarms';
  static const String channelAlarmsName = 'Ascent Alarms';
  static const String channelAlarmsDesc = 'High-priority ringing alarms for critical reminders and timers';

  static const String channelLearningId = 'ascent_learning';
  static const String channelLearningName = 'Ascent Learning Hub';
  static const String channelLearningDesc = 'Ongoing study timers and lecture tracking notifications';

  static const String channelChaiBreakId = 'ascent_chai_break';
  static const String channelChaiBreakName = 'Ascent Chai Break';
  static const String channelChaiBreakDesc = 'Break sanctuary timer and ambient soundscape player controls';
}
