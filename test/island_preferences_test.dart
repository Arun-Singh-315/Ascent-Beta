import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascent/core/providers/island_preferences_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final preferences = await SharedPreferences.getInstance();
    final result = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(result.dispose);
    return result;
  }

  test('Missing, malformed and future settings fall back safely', () async {
    for (final raw in [
      null,
      '{broken',
      '[]',
      '{"finish":"future","density":"future","showRecap":17}',
    ]) {
      final initial = <String, Object>{};
      if (raw != null) {
        initial[islandPreferencesKey] = raw;
      }
      final scope = await container(initial);
      final prefs = scope.read(islandPreferencesProvider);
      expect(prefs.finish, IslandFinish.sapphire);
      expect(prefs.density, IslandDensity.detailed);
      expect(prefs.showRecap, isTrue);
    }
  });

  test('Style and visibility settings survive a new provider scope', () async {
    final scope = await container({});
    await scope
        .read(islandPreferencesProvider.notifier)
        .update(
          (p) => p.copyWith(
            finish: IslandFinish.midnight,
            density: IslandDensity.minimal,
            showRecap: false,
            showPaused: false,
            showUpcoming: false,
            animate: false,
          ),
        );
    final stored = scope.read(sharedPreferencesProvider);
    final restored = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(stored)],
    );
    addTearDown(restored.dispose);
    final prefs = restored.read(islandPreferencesProvider);
    expect(prefs.finish, IslandFinish.midnight);
    expect(prefs.density, IslandDensity.minimal);
    expect(prefs.showRecap, isFalse);
    expect(prefs.showUpcoming, isFalse);
    expect(prefs.showPaused, isFalse);
    expect(prefs.animate, isFalse);
  });

  test('Rapid edits merge without overwriting each other', () async {
    final scope = await container({});
    final notifier = scope.read(islandPreferencesProvider.notifier);
    await Future.wait([
      notifier.update((p) => p.copyWith(finish: IslandFinish.frost)),
      notifier.update((p) => p.copyWith(showRecap: false)),
      notifier.update((p) => p.copyWith(density: IslandDensity.minimal)),
    ]);
    final prefs = scope.read(islandPreferencesProvider);
    expect(prefs.finish, IslandFinish.frost);
    expect(prefs.showRecap, isFalse);
    expect(prefs.density, IslandDensity.minimal);
    final data = jsonDecode(
      scope.read(sharedPreferencesProvider).getString(islandPreferencesKey)!,
    );
    expect(data['finish'], 'frost');
    expect(data['showRecap'], isFalse);
    expect(data['density'], 'minimal');
  });
}
