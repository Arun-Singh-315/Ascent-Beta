import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'boost_notification_copy.dart';

/// Notification Service for Ascent.
/// Provides modern, stylish notifications with rich typography, custom vibration,
/// accent coloring, and raw brotherly momentum boosts (5-Minute Rule & Streak Guardian).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Offset used to pair a task reminder with its 20-minute follow-up nudge
  static const int followUpIdOffset = 500000;

  // Notification Channel Constants
  static const String channelBoostNudgesId = 'ascent_boost_nudges';
  static const String channelBoostNudgesName = 'Raw Momentum & Streak Guardian';
  static const String channelStudyId = 'ascent_study_reminders';
  static const String channelStudyName = 'Study & Task Reminders';
  static const String channelCatchUpId = 'ascent_catch_up';
  static const String channelCatchUpName = 'Daily Catch-up Nudge';
  static const String channelTimerId = 'ascent_timer_alerts';
  static const String channelTimerName = 'Live Session & Timer Alerts';
  static const String channelMomentumWakeId = 'ascent_momentum_wake';
  static const String channelMomentumWakeName = 'Momentum Wake-Up Alert';
  static const String channelMomentumCommitmentId = 'ascent_momentum_commitments';
  static const String channelMomentumCommitmentName = 'Momentum Scheduled Sessions';
  static const String channelMomentumWindDownId = 'ascent_momentum_winddown';
  static const String channelMomentumWindDownName = 'Momentum Evening Wind-Down';
  static const String channelMedicineId = 'ascent_medicine_reminders';
  static const String channelMedicineName = 'Medicine & Prescription Reminders';
  static const String channelOngoingSessionId = 'ascent_ongoing_session';
  static const String channelOngoingSessionName = 'Active Session & Background Audio';
  static const int ongoingSessionNotificationId = 888800;
  static const int ongoingWalkNotificationId = 888801;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezones
    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Error initializing timezone: $e');
    }

    const androidSettings = AndroidInitializationSettings('@drawable/ic_launcher_foreground');
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

      // Create Android Notification Channels
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelBoostNudgesId,
            channelBoostNudgesName,
            description: 'Raw brotherly momentum nudges, 5-minute rule, and streak guardian',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            ledColor: Color(0xFF00B4D8),
          ),
        );
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelStudyId,
            channelStudyName,
            description: 'Daily study session and goal reminders',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
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
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelMomentumWakeId,
            channelMomentumWakeName,
            description: 'Alarms for target wake-up times and circadian entrainment',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            ledColor: Color(0xFF00B4D8),
          ),
        );
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelMomentumCommitmentId,
            channelMomentumCommitmentName,
            description: 'Reminders for scheduled gym workouts, outdoor walks, and supporting habits',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelMomentumWindDownId,
            channelMomentumWindDownName,
            description: 'Evening wind-down notifications to protect your 8-hour sleep recovery window',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelMedicineId,
            channelMedicineName,
            description: 'Timely reminders for prescribed medicines, tablets, and doses',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidImpl.createNotificationChannel(
          const AndroidNotificationChannel(
            channelOngoingSessionId,
            channelOngoingSessionName,
            description: 'Ongoing background lecture playback and active focus session timers',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
  }

  /// Checks if notifications are currently permitted by the OS.
  Future<bool> areNotificationsEnabled() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final enabled = await androidImpl.areNotificationsEnabled();
        return enabled ?? false;
      }
    } catch (e) {
      debugPrint('Error checking notifications enabled: $e');
    }
    return true;
  }

  /// Requests exact alarms access on Android 12+.
  Future<bool> requestExactAlarmsPermission() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.requestExactAlarmsPermission();
        return true;
      }
    } catch (e) {
      debugPrint('Error requesting exact alarm permission: $e');
    }
    return false;
  }

  /// Request permissions on Android 13+ (POST_NOTIFICATIONS) and iOS.
  Future<bool> requestPermissions() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        try {
          await androidImpl.requestExactAlarmsPermission();
        } catch (_) {}
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

  /// Builds a modern, stylized NotificationDetails payload with expandable text,
  /// tactile vibration, and Ascent cyan brand accent color.
  NotificationDetails _buildModernNotificationDetails({
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String title,
    required String body,
    String? summaryText,
    Importance importance = Importance.max,
    Priority priority = Priority.max,
  }) {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      icon: '@drawable/ic_launcher_foreground',
      color: const Color(0xFF00B4D8),
      enableLights: true,
      ledColor: const Color(0xFF00B4D8),
      ledOnMs: 500,
      ledOffMs: 500,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 150, 80, 220]),
      subText: 'Ascent • Momentum Engine',
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: summaryText ?? '⚡ 5-Min Rule',
        htmlFormatSummaryText: false,
      ),
      playSound: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      subtitle: 'Ascent • Momentum Engine',
    );

    const linuxDetails = LinuxNotificationDetails();

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );
  }

  /// Shows an immediate stylized notification.
  Future<bool> showInstantNotification({
    int id = 999,
    required String title,
    required String body,
    String? summaryText,
    String? payload,
    String channelId = channelBoostNudgesId,
    String channelName = channelBoostNudgesName,
  }) async {
    if (!_isInitialized) await initialize();

    // Ensure permissions on Android 13+ / iOS
    final enabled = await areNotificationsEnabled();
    if (!enabled) {
      final granted = await requestPermissions();
      if (!granted) {
        debugPrint('Cannot show instant notification: permissions denied by user.');
        return false;
      }
    }

    final notificationDetails = _buildModernNotificationDetails(
      channelId: channelId,
      channelName: channelName,
      channelDescription: 'Ascent instant alerts',
      title: title,
      body: body,
      summaryText: summaryText,
      importance: Importance.high,
      priority: Priority.high,
    );

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to show notification: $e');
      return false;
    }
  }

  /// Alias for showInstantNotification with fixed id 999
  Future<bool> sendInstantNotification({
    int id = 999,
    required String title,
    required String body,
    String? payload,
  }) =>
      showInstantNotification(id: id, title: title, body: body, payload: payload);

  /// Fires an instant raw brotherly boost preview for user testing.
  Future<bool> sendTestBoostNotification() async {
    final msg = BoostNotificationCopy.forTestBoost();
    return showInstantNotification(
      id: 777,
      title: msg.title,
      body: msg.body,
      summaryText: msg.summary,
      channelId: channelBoostNudgesId,
      channelName: channelBoostNudgesName,
    );
  }

  /// Schedules daily repeating reminder at given TimeOfDay using safe inexact idle alarms.
  Future<void> scheduleDailyReminder({
    required TimeOfDay time,
    required String title,
    required String body,
    int id = 101,
  }) async {
    if (!_isInitialized) await initialize();

    final scheduledTz = _nextInstanceOfTime(time);
    final notificationDetails = _buildModernNotificationDetails(
      channelId: channelStudyId,
      channelName: channelStudyName,
      channelDescription: 'Daily study session and goal reminders',
      title: title,
      body: body,
      summaryText: '⚡ Daily Prime',
      importance: Importance.high,
      priority: Priority.high,
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

  /// Daily Mid-day (14:30) and Evening Streak Guardian (20:30) brotherly nudges.
  Future<void> scheduleDailyMomentumGuardianNudges() async {
    if (!_isInitialized) await initialize();

    // 1. Midday 14:30 Check-in
    final midMsg = BoostNotificationCopy.forMiddayCheck();
    await _scheduleDailyBoost(
      id: 201,
      time: const TimeOfDay(hour: 14, minute: 30),
      msg: midMsg,
    );

    // 2. Evening 20:30 Streak Guardian
    final eveningMsg = BoostNotificationCopy.forEveningStreakGuardian();
    await _scheduleDailyBoost(
      id: 202,
      time: const TimeOfDay(hour: 20, minute: 30),
      msg: eveningMsg,
    );
  }

  Future<void> _scheduleDailyBoost({
    required int id,
    required TimeOfDay time,
    required NotificationMessage msg,
  }) async {
    final scheduledTz = _nextInstanceOfTime(time);
    final details = _buildModernNotificationDetails(
      channelId: channelBoostNudgesId,
      channelName: channelBoostNudgesName,
      channelDescription: 'Daily momentum and streak guardian nudges',
      title: msg.title,
      body: msg.body,
      summaryText: msg.summary,
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: msg.title,
        body: msg.body,
        scheduledDate: scheduledTz,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Failed to schedule daily boost $id: $e');
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

  /// Schedules a one-time reminder at a specific DateTime with raw boost copy
  /// and an automated 20-minute follow-up accountability nudge.
  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required DateTime scheduledAt,
    bool scheduleFollowUp = true,
  }) async {
    if (!_isInitialized) await initialize();

    final nowTz = tz.TZDateTime.now(tz.local);
    var scheduledTz = tz.TZDateTime.from(scheduledAt, tz.local);

    // If within 30 seconds in past (boundary latency during saving), schedule for 10 seconds ahead
    if (scheduledTz.isBefore(nowTz)) {
      if (nowTz.difference(scheduledTz).inSeconds < 45) {
        scheduledTz = nowTz.add(const Duration(seconds: 10));
      } else {
        debugPrint('Cannot schedule reminder in the past: $scheduledTz (now: $nowTz)');
        return;
      }
    }

    final boostMsg = BoostNotificationCopy.forScheduledTask(title);
    final notificationDetails = _buildModernNotificationDetails(
      channelId: channelBoostNudgesId,
      channelName: channelBoostNudgesName,
      channelDescription: 'Ascent raw momentum reminders and 5-min rule',
      title: boostMsg.title,
      body: boostMsg.body,
      summaryText: boostMsg.summary,
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: boostMsg.title,
        body: boostMsg.body,
        scheduledDate: scheduledTz,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('Successfully scheduled exact reminder id=$id at $scheduledTz');
    } catch (exactErr) {
      debugPrint('Exact alarm failed ($exactErr), falling back to inexactAllowWhileIdle for id=$id');
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: boostMsg.title,
          body: boostMsg.body,
          scheduledDate: scheduledTz,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        debugPrint('Successfully scheduled inexact reminder fallback id=$id at $scheduledTz');
      } catch (e) {
        debugPrint('Failed to schedule reminder notification fallback: $e');
      }
    }

    // Schedule the 20-minute follow-up accountability nudge ("Yo bro where you at?")
    if (scheduleFollowUp) {
      final followUpTz = scheduledTz.add(const Duration(minutes: 20));
      final followUpBoost = BoostNotificationCopy.forMissingYouFollowUp(title);
      final followUpDetails = _buildModernNotificationDetails(
        channelId: channelBoostNudgesId,
        channelName: channelBoostNudgesName,
        channelDescription: 'Accountability follow-up nudges',
        title: followUpBoost.title,
        body: followUpBoost.body,
        summaryText: followUpBoost.summary,
      );

      try {
        await _plugin.zonedSchedule(
          id: id + followUpIdOffset,
          title: followUpBoost.title,
          body: followUpBoost.body,
          scheduledDate: followUpTz,
          notificationDetails: followUpDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        debugPrint('Scheduled exact accountability follow-up nudge id=${id + followUpIdOffset} at $followUpTz');
      } catch (exactErr) {
        debugPrint('Exact follow-up failed ($exactErr), falling back to inexactAllowWhileIdle for id=${id + followUpIdOffset}');
        try {
          await _plugin.zonedSchedule(
            id: id + followUpIdOffset,
            title: followUpBoost.title,
            body: followUpBoost.body,
            scheduledDate: followUpTz,
            notificationDetails: followUpDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          debugPrint('Scheduled inexact follow-up fallback id=${id + followUpIdOffset} at $followUpTz');
        } catch (e) {
          debugPrint('Failed to schedule follow-up nudge: $e');
        }
      }
    }
  }

  /// Schedules a 6:00 AM (or target time) wake alarm for Momentum with persistent vibration and alarm sound.
  Future<void> scheduleMomentumWakeAlarm({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await initialize();

    final nowTz = tz.TZDateTime.now(tz.local);
    var scheduledTz = tz.TZDateTime.from(scheduledAt, tz.local);
    if (scheduledTz.isBefore(nowTz)) {
      if (nowTz.difference(scheduledTz).inSeconds < 45) {
        scheduledTz = nowTz.add(const Duration(seconds: 10));
      } else {
        return;
      }
    }

    final androidDetails = AndroidNotificationDetails(
      channelMomentumWakeId,
      channelMomentumWakeName,
      channelDescription: 'Alarms for target wake-up times and circadian entrainment',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@drawable/ic_launcher_foreground',
      color: const Color(0xFF00B4D8),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableLights: true,
      ledColor: const Color(0xFF00B4D8),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 1000]),
      subText: 'Ascent • Momentum Wake Alert',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: '⏰ 06:00 AM Wake Call',
      ),
      playSound: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
      subtitle: 'Ascent • Momentum Wake Alert',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTz,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('Scheduled exact Momentum wake alarm id=$id at $scheduledTz');
    } catch (e) {
      debugPrint('Exact wake alarm failed ($e), falling back to inexactAllowWhileIdle for id=$id');
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledTz,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (err) {
        debugPrint('Failed to schedule Momentum wake alarm fallback: $err');
      }
    }
  }

  /// Schedules a workout, walk, or habit session reminder for Momentum.
  Future<void> scheduleMomentumCommitmentReminder({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
    String? summaryText,
  }) async {
    if (!_isInitialized) await initialize();

    final nowTz = tz.TZDateTime.now(tz.local);
    var scheduledTz = tz.TZDateTime.from(scheduledAt, tz.local);
    if (scheduledTz.isBefore(nowTz)) {
      if (nowTz.difference(scheduledTz).inSeconds < 45) {
        scheduledTz = nowTz.add(const Duration(seconds: 10));
      } else {
        return;
      }
    }

    final details = _buildModernNotificationDetails(
      channelId: channelMomentumCommitmentId,
      channelName: channelMomentumCommitmentName,
      channelDescription: 'Reminders for scheduled gym workouts and outdoor walks',
      title: title,
      body: body,
      summaryText: summaryText ?? '⚡ Momentum Session',
      importance: Importance.high,
      priority: Priority.high,
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTz,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('Scheduled exact Momentum commitment id=$id at $scheduledTz');
    } catch (e) {
      debugPrint('Exact commitment failed ($e), falling back to inexact for id=$id');
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledTz,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (err) {
        debugPrint('Failed to schedule Momentum commitment fallback: $err');
      }
    }
  }

  /// Schedules 10:00 PM evening wind-down notification to protect sleep window.
  Future<void> scheduleMomentumWindDownReminder({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await initialize();

    final nowTz = tz.TZDateTime.now(tz.local);
    var scheduledTz = tz.TZDateTime.from(scheduledAt, tz.local);
    if (scheduledTz.isBefore(nowTz)) {
      if (nowTz.difference(scheduledTz).inSeconds < 45) {
        scheduledTz = nowTz.add(const Duration(seconds: 10));
      } else {
        return;
      }
    }

    final details = _buildModernNotificationDetails(
      channelId: channelMomentumWindDownId,
      channelName: channelMomentumWindDownName,
      channelDescription: 'Evening wind-down reminder to protect your 8-hour sleep opportunity',
      title: title,
      body: body,
      summaryText: '🌙 Wind-Down & Recovery',
      importance: Importance.high,
      priority: Priority.high,
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTz,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('Scheduled exact Momentum wind-down id=$id at $scheduledTz');
    } catch (e) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledTz,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (err) {
        debugPrint('Failed to schedule Momentum wind-down fallback: $err');
      }
    }
  }

  /// Schedules a dedicated reminder for taking medicine/prescriptions.
  Future<void> scheduleMedicineReminder({
    required int id,
    required String medicineName,
    required String dosage,
    required String instructions,
    required DateTime scheduledAt,
  }) async {
    if (!_isInitialized) await initialize();

    final nowTz = tz.TZDateTime.now(tz.local);
    var scheduledTz = tz.TZDateTime.from(scheduledAt, tz.local);

    if (scheduledTz.isBefore(nowTz)) {
      if (nowTz.difference(scheduledTz).inSeconds < 45) {
        scheduledTz = nowTz.add(const Duration(seconds: 10));
      } else {
        debugPrint('Cannot schedule medicine in past: $scheduledTz');
        return;
      }
    }

    final title = '💊 Time for your Medicine: $medicineName';
    final body = 'Please take $dosage ($instructions). Health is your greatest momentum!';

    final details = _buildModernNotificationDetails(
      channelId: channelMedicineId,
      channelName: channelMedicineName,
      channelDescription: 'Medicine and prescription dose alerts',
      title: title,
      body: body,
      summaryText: 'Prescription Schedule',
    );

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTz,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '/medicine',
      );
      debugPrint('Scheduled exact medicine reminder id=$id at $scheduledTz');
    } catch (e) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledTz,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '/medicine',
        );
        debugPrint('Scheduled fallback medicine reminder id=$id at $scheduledTz');
      } catch (err) {
        debugPrint('Failed to schedule medicine reminder: $err');
      }
    }
  }

  /// Cancels a notification by id and also cancels any linked follow-up accountability nudge.
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
      await _plugin.cancel(id: id + followUpIdOffset);
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

  /// Shows or updates an ongoing notification for background lectures or active focus sessions.
  Future<void> showOngoingSessionNotification({
    required String title,
    required String body,
    String? subText,
    int? elapsedSeconds,
  }) async {
    if (!_isInitialized) await initialize();
    try {
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      final chronometerStart = elapsedSeconds != null
          ? nowMillis - (elapsedSeconds * 1000)
          : nowMillis;

      final androidDetails = AndroidNotificationDetails(
        channelOngoingSessionId,
        channelOngoingSessionName,
        channelDescription: 'Ongoing background lecture playback and active focus session timers',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        usesChronometer: true,
        when: chronometerStart,
        color: const Color(0xFF00B4D8),
        subText: subText ?? 'Ascent • Active Session',
        category: AndroidNotificationCategory.status,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentSound: false,
        presentAlert: false,
      );
      await _plugin.show(
        id: ongoingSessionNotificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails, iOS: darwinDetails),
      );
    } catch (e) {
      debugPrint('Failed to show ongoing session notification: $e');
    }
  }

  /// Cancels the ongoing session notification when lecture or timer stops.
  Future<void> cancelOngoingSessionNotification() async {
    try {
      await _plugin.cancel(id: ongoingSessionNotificationId);
    } catch (e) {
      debugPrint('Failed to cancel ongoing session notification: $e');
    }
  }

  /// Shows or updates an ongoing notification for background outdoor walking or run session.
  Future<void> showOngoingWalkNotification({
    required int durationSeconds,
    required double distanceKm,
    required String pace,
    bool isPaused = false,
  }) async {
    if (!_isInitialized) await initialize();
    try {
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      final chronometerStart = nowMillis - (durationSeconds * 1000);

      final androidDetails = AndroidNotificationDetails(
        channelOngoingSessionId,
        channelOngoingSessionName,
        channelDescription: 'Ongoing walking and GPS activity tracker',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: !isPaused,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        usesChronometer: !isPaused,
        when: chronometerStart,
        color: const Color(0xFF2C6B45),
        subText: isPaused ? 'Walk Paused' : 'Walk Active • GPS Live',
        category: AndroidNotificationCategory.status,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentSound: false,
        presentAlert: false,
      );
      await _plugin.show(
        id: ongoingWalkNotificationId,
        title: isPaused ? 'Walking Paused ⏸️' : 'Walking in Progress 🚶',
        body: '${distanceKm.toStringAsFixed(2)} km • Pace: $pace /km',
        notificationDetails: NotificationDetails(android: androidDetails, iOS: darwinDetails),
      );
    } catch (e) {
      debugPrint('Failed to show ongoing walk notification: $e');
    }
  }

  /// Cancels the ongoing walk notification.
  Future<void> cancelOngoingWalkNotification() async {
    try {
      await _plugin.cancel(id: ongoingWalkNotificationId);
    } catch (e) {
      debugPrint('Failed to cancel ongoing walk notification: $e');
    }
  }
}
