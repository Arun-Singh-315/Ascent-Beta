import 'package:ascent/core/features/feature_registry.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_unlock_next_card.dart';
import 'package:ascent/features/hydration/hydration_pace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> container(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('feature registry', () {
    test('every feature has exactly one spec', () {
      for (final f in AscentFeature.values) {
        expect(featureSpecs.where((s) => s.id == f), hasLength(1));
      }
    });

    test('routes map to the feature that owns them', () {
      expect(featureForRoute('/things'), AscentFeature.things);
      expect(featureForRoute('/reminders?id=3'), AscentFeature.things);
      expect(featureForRoute('/hydration'), AscentFeature.care);
      expect(featureForRoute('/medicine/5'), AscentFeature.care);
      expect(featureForRoute('/vault'), AscentFeature.vault);
      expect(featureForRoute('/ai-assistant'), isNull);
      expect(featureForRoute('/you'), isNull);
    });

    test('existing users with no stored choice keep everything', () async {
      final c = await container({});
      expect(c.read(unlockedFeaturesProvider), AscentFeature.values.toSet());
    });

    test('stored choice is read back, unlock and lock persist', () async {
      final c = await container({
        unlockedFeaturesKey: ['things', 'mind'],
      });
      expect(c.read(unlockedFeaturesProvider), {
        AscentFeature.things,
        AscentFeature.mind,
      });
      await c.read(unlockedFeaturesProvider.notifier).unlock(
        AscentFeature.money,
      );
      final prefs = c.read(sharedPreferencesProvider);
      expect(prefs.getStringList(unlockedFeaturesKey), [
        'things',
        'mind',
        'money',
      ]);
      await c.read(unlockedFeaturesProvider.notifier).lock(
        AscentFeature.things,
      );
      expect(c.read(unlockedFeaturesProvider), {
        AscentFeature.mind,
        AscentFeature.money,
      });
    });

    test('next locked feature follows registry order', () {
      expect(
        nextLockedFeature({AscentFeature.things, AscentFeature.mind}),
        AscentFeature.care,
      );
      expect(nextLockedFeature(AscentFeature.values.toSet()), isNull);
    });
  });

  group('unlock next card timing', () {
    final day1 = DateTime(2026, 11, 21);
    final day2 = DateTime(2026, 11, 22);
    const two = {AscentFeature.things, AscentFeature.mind};

    test('never on the day features were chosen', () {
      expect(
        shouldShowUnlockNext(
          unlocked: two,
          today: day1,
          startedDay: day1.toIso8601String(),
        ),
        isFalse,
      );
    });

    test('shows the next day, hides while snoozed', () {
      expect(
        shouldShowUnlockNext(
          unlocked: two,
          today: day2,
          startedDay: day1.toIso8601String(),
        ),
        isTrue,
      );
      expect(
        shouldShowUnlockNext(
          unlocked: two,
          today: day2,
          startedDay: day1.toIso8601String(),
          hiddenUntil: DateTime(2026, 11, 25).toIso8601String(),
        ),
        isFalse,
      );
    });

    test('nothing to suggest when everything is on', () {
      expect(
        shouldShowUnlockNext(
          unlocked: AscentFeature.values.toSet(),
          today: day2,
        ),
        isFalse,
      );
    });
  });

  group('hydration pace', () {
    test('quiet outside waking hours and when on track', () {
      expect(
        hydrationBehindMl(
          now: DateTime(2026, 1, 1, 7),
          drankMl: 0,
          goalMl: 2000,
        ),
        isNull,
      );
      expect(
        hydrationBehindMl(
          now: DateTime(2026, 1, 1, 15),
          drankMl: 1000,
          goalMl: 2000,
        ),
        isNull,
      );
    });

    test('reports how far behind, rounded to 50 ml', () {
      // 15:00 is 7 of 14 waking hours: 1000 ml expected.
      expect(
        hydrationBehindMl(
          now: DateTime(2026, 1, 1, 15),
          drankMl: 400,
          goalMl: 2000,
        ),
        600,
      );
    });
  });
}
