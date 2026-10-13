import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import 'database_provider.dart';
import '../actions/checkin_actions.dart';

const dailyCheckInPreferenceKey = 'ascent_daily_checkin_v1';

class DailyCheckInSettings {
  const DailyCheckInSettings({
    this.enabled = false,
    this.spending = false,
    this.water = false,
    this.weekly = false,
    this.afterHour = 18,
    this.dismissedPeriod,
    this.spendingPeriod,
    this.waterPeriod,
  });
  final bool enabled, spending, water, weekly;
  final int afterHour;
  final String? dismissedPeriod, spendingPeriod, waterPeriod;
  String period(DateTime now) {
    final date = weekly
        ? DateTime(now.year, now.month, now.day - now.weekday + 1)
        : DateTime(now.year, now.month, now.day);
    return '${weekly ? 'week' : 'day'}:${date.year}-${date.month}-${date.day}';
  }

  bool due(DateTime now) =>
      enabled &&
      (spending || water) &&
      now.hour >= afterHour &&
      dismissedPeriod != period(now) &&
      ((spending && spendingPeriod != period(now)) ||
          (water && waterPeriod != period(now)));
  DailyCheckInSettings copyWith({
    bool? enabled,
    bool? spending,
    bool? water,
    bool? weekly,
    int? afterHour,
    String? dismissedPeriod,
    String? spendingPeriod,
    String? waterPeriod,
  }) => DailyCheckInSettings(
    enabled: enabled ?? this.enabled,
    spending: spending ?? this.spending,
    water: water ?? this.water,
    weekly: weekly ?? this.weekly,
    afterHour: afterHour ?? this.afterHour,
    dismissedPeriod: dismissedPeriod ?? this.dismissedPeriod,
    spendingPeriod: spendingPeriod ?? this.spendingPeriod,
    waterPeriod: waterPeriod ?? this.waterPeriod,
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'spending': spending,
    'water': water,
    'weekly': weekly,
    'afterHour': afterHour,
    'dismissedPeriod': dismissedPeriod,
    'spendingPeriod': spendingPeriod,
    'waterPeriod': waterPeriod,
  };
  factory DailyCheckInSettings.fromJson(Map<String, dynamic> json) =>
      DailyCheckInSettings(
        enabled: json['enabled'] == true,
        spending: json['spending'] == true,
        water: json['water'] == true,
        weekly: json['weekly'] == true,
        afterHour: json['afterHour'] is int
            ? (json['afterHour'] as int).clamp(0, 23)
            : 18,
        dismissedPeriod: json['dismissedPeriod'] is String
            ? json['dismissedPeriod']
            : null,
        spendingPeriod: json['spendingPeriod'] is String
            ? json['spendingPeriod']
            : null,
        waterPeriod: json['waterPeriod'] is String ? json['waterPeriod'] : null,
      );
}

class DailyCheckInNotifier extends Notifier<DailyCheckInSettings> {
  Future<void> _queue = Future.value();
  @override
  DailyCheckInSettings build() {
    try {
      final raw = ref
          .watch(sharedPreferencesProvider)
          .getString(dailyCheckInPreferenceKey);
      if (raw != null) {
        return DailyCheckInSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return const DailyCheckInSettings();
  }

  Future<void> change(
    DailyCheckInSettings Function(DailyCheckInSettings) update,
  ) {
    final prefs = ref.read(sharedPreferencesProvider);
    final next = _queue.then((_) async {
      final value = update(state);
      final json = jsonEncode(value.toJson());
      if (!await prefs.setString(dailyCheckInPreferenceKey, json)) {
        throw StateError('Could not save check-in preference');
      }
      if (ref.mounted) state = value;
    });
    _queue = next.catchError((Object error) {});
    return next;
  }
}

final dailyCheckInProvider =
    NotifierProvider<DailyCheckInNotifier, DailyCheckInSettings>(
      DailyCheckInNotifier.new,
    );

final checkInWaterSavedProvider = FutureProvider.family<bool, String>(
  (ref, period) =>
      CheckInActions(ref.watch(databaseProvider)).waterSaved(period),
);
