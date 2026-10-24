import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../streak/study_streak_provider.dart';

const homeLayoutPreferenceKey = 'ascent_home_layout_v1';
const homeSections = <String, String>{
  'streak': 'Study streak',
  'reminders': 'Upcoming reminders',
  'today': 'Today',
  'learning': 'Learning',
  'life': 'Life & Health',
  'mind': 'Mind Space',
  'money': 'Quick expense',
  'checkin': 'Daily check-in',
  'vault': 'Ascent Vault',
};
const homeTools = <String, String>{
  'medicine': 'Medicine',
  'hydration': 'Water',
  'walk': 'Walk',
  'momentum': 'Challenges',
  'chai-break': 'Breaks',
};
const homeShortcutRoutes = <String, String>{
  'today': 'Today',
  'thought-wall': 'Mind Space',
  'learning': 'Learning',
  'reminders': 'Reminders',
  'money': 'Money',
  'focus': 'Focus',
  'medicine': 'Medicine',
  'hydration': 'Water',
  'walk': 'Walk',
  'chai-break': 'Breaks',
  'momentum': 'Challenges',
  'vault': 'Vault',
};

class HomeLayout {
  HomeLayout({
    required List<String> order,
    required Set<String> visible,
    required Set<String> tools,
    Set<String> compact = const {},
    List<String> shortcuts = const [],
  }) : order = List.unmodifiable(order),
       visible = Set.unmodifiable(visible),
       tools = Set.unmodifiable(tools),
       compact = Set.unmodifiable(compact),
       shortcuts = List.unmodifiable(shortcuts);
  final List<String> order;
  final Set<String> visible, tools, compact;
  final List<String> shortcuts;
  factory HomeLayout.defaults() => HomeLayout(
    order: ['mind', ...homeSections.keys.where((id) => id != 'mind')],
    visible: {
      'streak',
      'reminders',
      'today',
      'learning',
      'life',
      'mind',
      'vault',
    },
    tools: homeTools.keys.toSet(),
  );
  HomeLayout copyWith({
    List<String>? order,
    Set<String>? visible,
    Set<String>? tools,
    Set<String>? compact,
    List<String>? shortcuts,
  }) => HomeLayout(
    order: order ?? this.order,
    visible: visible ?? this.visible,
    tools: tools ?? this.tools,
    compact: compact ?? this.compact,
    shortcuts: shortcuts ?? this.shortcuts,
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'order': order,
    'visible': visible.toList(),
    'tools': tools.toList(),
    'compact': compact.toList(),
    'shortcuts': shortcuts,
  };
  factory HomeLayout.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['order'] is! List ||
        json['visible'] is! List ||
        json['tools'] is! List) {
      throw const FormatException('Invalid Home layout');
    }
    List<String> known(Object? value, Map<String, String> registry) {
      if (value is! List || value.any((id) => id is! String)) {
        throw const FormatException('Invalid layout IDs');
      }
      return value.cast<String>().where(registry.containsKey).toSet().toList();
    }

    final order = known(json['order'], homeSections);
    final savedOrder = (json['order'] as List).cast<dynamic>();
    final isExistingWithoutVault = !savedOrder.contains('vault');
    final parsedVisible = known(json['visible'], homeSections).toSet();
    final visible = isExistingWithoutVault
        ? {...parsedVisible, 'vault'}
        : parsedVisible;

    return HomeLayout(
      order: [
        ...order,
        ...homeSections.keys.where((id) => !order.contains(id)),
      ],
      visible: visible,
      tools: known(json['tools'], homeTools).toSet(),
      compact: known(
        json['compact'] ?? [],
        homeSections,
      ).where((id) => id == 'today' || id == 'mind').toSet(),
      shortcuts: known(
        json['shortcuts'] ?? [],
        homeShortcutRoutes,
      ).take(4).toList(),
    );
  }
}

class HomeLayoutNotifier extends Notifier<HomeLayout> {
  bool _saving = false;
  @override
  HomeLayout build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(homeLayoutPreferenceKey);
    if (raw != null) {
      try {
        return HomeLayout.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return HomeLayout.defaults();
  }

  Future<void> save(HomeLayout layout) async {
    if (_saving) throw StateError('A layout save is already in progress');
    final validated = HomeLayout.fromJson(layout.toJson());
    _saving = true;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final json = jsonEncode(validated.toJson());
      if (!await prefs.setString(homeLayoutPreferenceKey, json) ||
          prefs.getString(homeLayoutPreferenceKey) != json) {
        throw StateError('Your layout could not be saved');
      }
      state = validated;
    } finally {
      _saving = false;
    }
  }
}

final homeLayoutProvider = NotifierProvider<HomeLayoutNotifier, HomeLayout>(
  HomeLayoutNotifier.new,
);

/// The legacy flame preference is migrated on the first explicit layout save.
final homeStreakVisibleProvider = Provider<bool>((ref) {
  final layout = ref.watch(homeLayoutProvider);
  final preferences = ref.watch(sharedPreferencesProvider);
  final raw = preferences.getString(homeLayoutPreferenceKey);
  if (raw != null) {
    try {
      HomeLayout.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return layout.visible.contains('streak');
    } catch (_) {}
  }
  return ref.watch(studyStreakCardVisibleProvider);
});
