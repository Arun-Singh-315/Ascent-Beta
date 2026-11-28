import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../home/home_zone.dart';
import 'settings_provider.dart';

export '../home/home_zone.dart';

const homeLayoutPreferenceKey = 'ascent_home_layout_v1';
const homeSections = <String, String>{
  'promises': 'Promises',
  'streak': 'Study streak',
  'reminders': 'Upcoming reminders',
  'today': 'Today',
  'life': 'Daily rhythm',
  'mind': 'Mindspace',
  'money': 'Quick expense',
  'checkin': 'Daily check-in',
  'vault': 'Ascent Vault',
};
const homeTools = <String, String>{
  'medicine': 'Medicine',
  'hydration': 'Water',
};
const homeShortcutRoutes = <String, String>{
  'assistant': 'Assistant',
  'plans': 'Plans',
  'today': 'Today',
  'thought-wall': 'Mindspace',
  'reminders': 'Reminders',
  'money': 'Money',
  'focus': 'Focus',
  'medicine': 'Medicine',
  'hydration': 'Water',
  'vault': 'Vault',
};

/// What paints Home's background (Day Page). Zones is the default: each
/// zone gets its own soft tint, and the colour change divides the sections.
enum HomeBackground { zones, doodle, sky, plain }

enum HomeDensity { comfortable, compact }

/// The Now zone (header, capture, Now card, Needs you) can't be hidden.
const fixedHomeZones = {HomeZone.now};

/// Default zone tint strength (0.3–1).
const defaultZoneStrength = 0.7;

class HomeLayout {
  HomeLayout({
    required List<String> order,
    required Set<String> visible,
    required Set<String> tools,
    Set<String> compact = const {},
    List<String> shortcuts = const [],
    List<HomeZone> zones = HomeZone.values,
    Set<HomeZone> hiddenZones = const {},
    this.background = HomeBackground.zones,
    double zoneStrength = defaultZoneStrength,
    this.density = HomeDensity.comfortable,
    this.changeThroughDay = true,
  }) : order = List.unmodifiable(order),
       visible = Set.unmodifiable(visible),
       tools = Set.unmodifiable(tools),
       compact = Set.unmodifiable(compact),
       shortcuts = List.unmodifiable(shortcuts),
       zones = List.unmodifiable(_completeZones(zones)),
       hiddenZones = Set.unmodifiable(hiddenZones.difference(fixedHomeZones)),
       zoneStrength = zoneStrength.clamp(0.3, 1.0).toDouble();
  final List<String> order;
  final Set<String> visible, tools, compact;
  final List<String> shortcuts;

  /// Zone order, top to bottom. Always holds every zone exactly once, with
  /// Now first.
  final List<HomeZone> zones;
  final Set<HomeZone> hiddenZones;
  final HomeBackground background;
  final double zoneStrength;
  final HomeDensity density;

  /// Lift a zone that is live right now (a running session, a due dose)
  /// without changing the saved order.
  final bool changeThroughDay;

  /// Zones Home shows, in order.
  List<HomeZone> get visibleZones =>
      zones.where((z) => !hiddenZones.contains(z)).toList();

  static List<HomeZone> _completeZones(List<HomeZone> zones) {
    final seen = <HomeZone>{HomeZone.now};
    return [
      HomeZone.now,
      for (final z in zones)
        if (seen.add(z)) z,
      for (final z in HomeZone.values)
        if (seen.add(z)) z,
    ];
  }

  factory HomeLayout.defaults() => HomeLayout(
    order: [
      'mind',
      'today',
      ...homeSections.keys.where((id) => id != 'mind' && id != 'today'),
    ],
    visible: {
      'promises',
      'streak',
      'reminders',
      'today',
      'life',
      'mind',
      'vault',
    },
    tools: homeTools.keys.toSet(),
    shortcuts: const ['focus', 'hydration', 'assistant', 'vault'],
  );
  HomeLayout copyWith({
    List<String>? order,
    Set<String>? visible,
    Set<String>? tools,
    Set<String>? compact,
    List<String>? shortcuts,
    List<HomeZone>? zones,
    Set<HomeZone>? hiddenZones,
    HomeBackground? background,
    double? zoneStrength,
    HomeDensity? density,
    bool? changeThroughDay,
  }) => HomeLayout(
    order: order ?? this.order,
    visible: visible ?? this.visible,
    tools: tools ?? this.tools,
    compact: compact ?? this.compact,
    shortcuts: shortcuts ?? this.shortcuts,
    zones: zones ?? this.zones,
    hiddenZones: hiddenZones ?? this.hiddenZones,
    background: background ?? this.background,
    zoneStrength: zoneStrength ?? this.zoneStrength,
    density: density ?? this.density,
    changeThroughDay: changeThroughDay ?? this.changeThroughDay,
  );
  Map<String, dynamic> toJson() => {
    'version': 2,
    'order': order,
    'visible': visible.toList(),
    'tools': tools.toList(),
    'compact': compact.toList(),
    'shortcuts': shortcuts,
    'zones': [for (final z in zones) z.name],
    'hiddenZones': [for (final z in hiddenZones) z.name],
    'background': background.name,
    'zoneStrength': zoneStrength,
    'density': density.name,
    'changeThroughDay': changeThroughDay,
  };

  /// Which zones a version 1 layout hid, read from its section switches.
  /// Only switches that were on by default count as a choice; an empty v1
  /// Home stays as bare as the person made it.
  static Set<HomeZone> _hiddenFromV1(Set<String> visible) {
    if (visible.isEmpty) {
      return HomeZone.values.toSet().difference(fixedHomeZones);
    }
    return {
      if (!visible.contains('today')) HomeZone.plan,
      if (!visible.contains('promises') && !visible.contains('streak'))
        HomeZone.keep,
      if (!visible.contains('mind')) HomeZone.mind,
      if (!visible.contains('life')) HomeZone.care,
    };
  }

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.firstWhere((v) => v.name == name, orElse: () => fallback);

  factory HomeLayout.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if ((version != 1 && version != 2) ||
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
    final isExistingWithoutPromises = !savedOrder.contains('promises');
    final parsedVisible = known(json['visible'], homeSections).toSet();
    var visible = parsedVisible;
    // Migrate older active layouts without overriding explicit hidden choices
    // or turning an intentionally empty Home back into a populated one.
    if (parsedVisible.isNotEmpty) {
      if (isExistingWithoutVault) visible = {...visible, 'vault'};
      // Promises arrived later: show them once to existing layouts too.
      if (isExistingWithoutPromises) visible = {...visible, 'promises'};
    }

    final rawShortcuts = json['shortcuts'];
    final parsedShortcuts = (rawShortcuts == null)
        ? const ['focus', 'hydration', 'assistant', 'vault']
        : known(rawShortcuts, homeShortcutRoutes).take(4).toList();

    List<HomeZone> zoneList(Object? raw) => raw is List
        ? [
            for (final name in raw)
              for (final z in HomeZone.values)
                if (z.name == name) z,
          ]
        : const [];
    final strength = json['zoneStrength'];

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
      shortcuts: parsedShortcuts,
      zones: version == 2 ? zoneList(json['zones']) : HomeZone.values,
      hiddenZones: version == 2
          ? zoneList(json['hiddenZones']).toSet()
          : _hiddenFromV1(parsedVisible),
      background: _enum(
        HomeBackground.values,
        json['background'],
        HomeBackground.zones,
      ),
      zoneStrength: strength is num ? strength.toDouble() : defaultZoneStrength,
      density: _enum(
        HomeDensity.values,
        json['density'],
        HomeDensity.comfortable,
      ),
      changeThroughDay: json['changeThroughDay'] is bool
          ? json['changeThroughDay'] as bool
          : true,
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
  return true;
});
