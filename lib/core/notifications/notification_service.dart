import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notification Service for Ascent.
/// Provides safe local notifications for daily check-in reminders and interview deadlines
/// without requiring dangerous exact alarm permissions that trigger Google Play policy issues.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Channel constants
  static const String channelStudyId = 'ascent_study_reminders';
  static const String channelStudyName = 'Study Reminders';
  static const String channelCatchUpId = 'ascent_catch_up';
  static const String channelCatchUpName = 'Daily Catch-up Nudge';
  static const String channelTimerId = 'ascent_timer_alerts';
  static const String channelTimerName = 'Live Session & Timer Alerts';

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezones
    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Error initializing timezone: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open Ascent',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handled via root navigator if payload is provided
        },
      );

      // Create Android Channels
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelStudyId,
            channelStudyName,
            description: 'Daily study session and goal reminders',
            importance: Importance.high,
          ),
        );
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelCatchUpId,
            channelCatchUpName,
            description: 'Evening reminder to log your daily study and consistency',
            importance: Importance.defaultImportance,
          ),
        );
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelTimerId,
            channelTimerName,
            description: 'Alerts when sessions or breaks conclude',
            importance: Importance.high,
          ),
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
  }

  /// Request permissions on Android 13+ and iOS.
  Future<bool> requestPermissions() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        return granted ?? false;
      }
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        final granted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return true;
  }

  /// Shows an immediate notification (e.g. test, or milestone achieved).
  Future<void> showInstantNotification({
    int id = 999,
    required String title,
    required String body,
    String? payload,
    String channelId = channelStudyId,
    String channelName = channelStudyName,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Ascent instant alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  /// Alias for showInstantNotification with fixed id 999
  Future<void> sendInstantNotification({
    int id = 999,
    required String title,
    required String body,
    String? payload,
  }) =>
      showInstantNotification(id: id, title: title, body: body, payload: payload);

  /// Schedules daily repeating reminder at given TimeOfDay using safe inexact idle alarms.
  Future<void> scheduleDailyReminder({
    required TimeOfDay time,
    required String title,
    required String body,
    int id = 101,
  }) async {
    if (!_isInitialized) await initialize();

    final scheduledTz = _nextInstanceOfTime(time);

    const androidDetails = AndroidNotificationDetails(
      channelStudyId,
      channelStudyName,
      channelDescription: 'Daily study session and goal reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTz,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Failed to schedule daily reminder: $e');
    }
  }

  /// Schedules 8:00 PM catch-up reminder if consistency has not been logged.
  Future<void> scheduleEveningCatchUpNudge({
    TimeOfDay time = const TimeOfDay(hour: 20, minute: 0),
    int id = 102,
  }) async {
    await scheduleDailyReminder(
      time: time,
      title: 'Keep Your Streak Alive! ⚡',
      body: 'Take 25 minutes to log your focus session or record your progress for today.',
      id: id,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Schedules a one-time reminder at a specific DateTime.
  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required DateTime scheduledAt,
  }) async {
    if (!_isInitialized) await initialize();

    final scheduledTz = tz.TZDateTime.from(scheduledAt, tz.local);
    if (scheduledTz.isBefore(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      channelStudyId,
      channelStudyName,
      channelDescription: 'Ascent reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const linuxDetails = LinuxNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: 'Scheduled reminder: $title',
        scheduledDate: scheduledTz,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Failed to schedule reminder notification: $e');
    }
  }

  /// Cancels a notification by id.
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }

  /// Cancels all notifications.
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }
}
