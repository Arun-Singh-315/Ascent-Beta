import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

enum IslandFinish { sapphire, frost, midnight }

enum IslandDensity { detailed, minimal }

const islandPreferencesKey = 'ascent_dynamic_island_preferences_v1';

class IslandPreferences {
  const IslandPreferences({
    this.finish = IslandFinish.sapphire,
    this.density = IslandDensity.detailed,
    this.showUpcoming = true,
    this.showRecap = true,
    this.showPaused = true,
    this.animate = true,
  });

  final IslandFinish finish;
  final IslandDensity density;
  final bool showUpcoming, showRecap, showPaused, animate;

  IslandPreferences copyWith({
    IslandFinish? finish,
    IslandDensity? density,
    bool? showUpcoming,
    bool? showRecap,
    bool? showPaused,
    bool? animate,
  }) => IslandPreferences(
    finish: finish ?? this.finish,
    density: density ?? this.density,
    showUpcoming: showUpcoming ?? this.showUpcoming,
    showRecap: showRecap ?? this.showRecap,
    showPaused: showPaused ?? this.showPaused,
    animate: animate ?? this.animate,
  );

  Map<String, Object> toJson() => {
    'finish': finish.name,
    'density': density.name,
    'showUpcoming': showUpcoming,
    'showRecap': showRecap,
    'showPaused': showPaused,
    'animate': animate,
  };

  factory IslandPreferences.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, dynamic raw, T fallback) =>
        values.where((v) => v.name == raw).firstOrNull ?? fallback;
    bool flag(String key) => json[key] is bool ? json[key] as bool : true;
    return IslandPreferences(
      finish: enumValue(
        IslandFinish.values,
        json['finish'],
        IslandFinish.sapphire,
      ),
      density: enumValue(
        IslandDensity.values,
        json['density'],
        IslandDensity.detailed,
      ),
      showUpcoming: flag('showUpcoming'),
      showRecap: flag('showRecap'),
      showPaused: flag('showPaused'),
      animate: flag('animate'),
    );
  }
}

class IslandPreferencesNotifier extends Notifier<IslandPreferences> {
  Future<void> _pending = Future.value();

  @override
  IslandPreferences build() {
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getString(islandPreferencesKey);
    try {
      return stored == null
          ? const IslandPreferences()
          : IslandPreferences.fromJson(
              jsonDecode(stored) as Map<String, dynamic>,
            );
    } catch (_) {
      return const IslandPreferences();
    }
  }

  // Serialize edits and merge against the latest saved state so rapid changes
  // to different controls cannot overwrite each other.
  Future<void> update(IslandPreferences Function(IslandPreferences) change) {
    final task = _pending.then((_) async {
      final next = change(state);
      final encoded = jsonEncode(next.toJson());
      final prefs = ref.read(sharedPreferencesProvider);
      if (!await prefs.setString(islandPreferencesKey, encoded)) {
        throw StateError('Could not save island preferences');
      }
      if (ref.mounted) state = next;
    });
    _pending = task.catchError((Object _) {});
    return task;
  }
}

final islandPreferencesProvider =
    NotifierProvider<IslandPreferencesNotifier, IslandPreferences>(
      IslandPreferencesNotifier.new,
    );
