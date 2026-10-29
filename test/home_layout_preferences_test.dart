import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Legacy defaults stay intact and corrupt preferences recover safely',
    () async {
      SharedPreferences.setMockInitialValues({
        homeLayoutPreferenceKey: '{broken',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(
        container.read(homeLayoutProvider).visible,
        HomeLayout.defaults().visible,
      );
    },
  );
  test(
    'Hidden/all-hidden layout, order, compact variants and tool choices persist',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      final layout = HomeLayout.defaults().copyWith(
        order: homeSections.keys.toList().reversed.toList(),
        visible: {},
        tools: {'hydration'},
        compact: {'today'},
        shortcuts: ['thought-wall'],
      );
      await container.read(homeLayoutProvider.notifier).save(layout);
      container.dispose();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final restored = container.read(homeLayoutProvider);
      expect(restored.visible, isEmpty);
      expect(restored.order, layout.order);
      expect(restored.tools, {'hydration'});
      expect(restored.compact, {'today'});
      expect(restored.shortcuts, ['thought-wall']);
    },
  );
  test(
    'Hidden Promises stay hidden while older populated layouts gain new sections',
    () {
      final hidden = HomeLayout.defaults().copyWith(visible: {'mind', 'life'});
      expect(HomeLayout.fromJson(hidden.toJson()).visible, {'mind', 'life'});
      final legacy = HomeLayout.fromJson({
        'version': 1,
        'order': ['mind', 'life'],
        'visible': ['mind', 'life'],
        'tools': ['hydration'],
      });
      expect(legacy.visible, {'mind', 'life', 'promises', 'vault'});
    },
  );
  test(
    'Unknown/duplicate IDs and unavailable variants never corrupt a restored layout',
    () {
      final layout = HomeLayout.fromJson({
        'version': 1,
        'order': ['today', 'bad', 'today'],
        'visible': ['bad'],
        'tools': ['hydration', 'unknown'],
        'compact': ['life', 'today'],
        'shortcuts': [
          'today',
          'today',
          'money',
          'bad',
          'walk',
          'focus',
          'learning',
        ],
      });
      expect(layout.order.toSet(), homeSections.keys.toSet());
      expect(layout.visible, isEmpty);
      expect(layout.tools, {'hydration'});
      expect(layout.compact, {'today'});
      expect(layout.shortcuts, ['today', 'money', 'walk', 'focus']);
    },
  );
}
