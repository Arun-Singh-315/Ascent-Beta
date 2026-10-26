import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';

const thoughtWallAppearanceKey = 'ascent_thought_wall_appearance_v1';

enum ThoughtCardStyle { soft, bubble, minimal }

enum ThoughtCardTone { theme, linen, sage, slate }

enum ThoughtCardDensity { compact, comfortable }

@immutable
class ThoughtWallAppearance {
  const ThoughtWallAppearance({
    this.style = ThoughtCardStyle.soft,
    this.tone = ThoughtCardTone.theme,
    this.density = ThoughtCardDensity.compact,
    this.bubbleFilled = true,
    this.bubbleBorderWidth = 1.8,
  });
  final ThoughtCardStyle style;
  final ThoughtCardTone tone;
  final ThoughtCardDensity density;
  final bool bubbleFilled;
  final double bubbleBorderWidth;

  ThoughtWallAppearance copyWith({
    ThoughtCardStyle? style,
    ThoughtCardTone? tone,
    ThoughtCardDensity? density,
    bool? bubbleFilled,
    double? bubbleBorderWidth,
  }) => ThoughtWallAppearance(
    style: style ?? this.style,
    tone: tone ?? this.tone,
    density: density ?? this.density,
    bubbleFilled: bubbleFilled ?? this.bubbleFilled,
    bubbleBorderWidth: bubbleBorderWidth ?? this.bubbleBorderWidth,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'style': style.name,
    'tone': tone.name,
    'density': density.name,
    'bubbleFilled': bubbleFilled,
    'bubbleBorderWidth': bubbleBorderWidth,
  };

  factory ThoughtWallAppearance.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) return const ThoughtWallAppearance();
    return ThoughtWallAppearance(
      tone:
          ThoughtCardTone.values
              .where((t) => t.name == json['tone'])
              .firstOrNull ??
          ThoughtCardTone.theme,
      style:
          ThoughtCardStyle.values
              .where((s) => s.name == json['style'])
              .firstOrNull ??
          ThoughtCardStyle.soft,
      density:
          ThoughtCardDensity.values
              .where((d) => d.name == json['density'])
              .firstOrNull ??
          ThoughtCardDensity.compact,
      bubbleFilled: json['bubbleFilled'] as bool? ?? true,
      bubbleBorderWidth: (json['bubbleBorderWidth'] as num?)?.toDouble() ?? 1.8,
    );
  }
}

class ThoughtWallAppearanceNotifier extends Notifier<ThoughtWallAppearance> {
  bool _saving = false;
  @override
  ThoughtWallAppearance build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final raw = prefs.getString(thoughtWallAppearanceKey);
      if (raw != null) {
        return ThoughtWallAppearance.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
      final filled = prefs.getBool('home_thought_bubble_filled') ?? true;
      final border =
          prefs.getDouble('home_thought_bubble_border_width') ?? 1.8;
      return ThoughtWallAppearance(
        bubbleFilled: filled,
        bubbleBorderWidth: border,
      );
    } catch (_) {
      // Missing or older preferences retain the default wall appearance.
    }
    return const ThoughtWallAppearance();
  }

  Future<void> save(ThoughtWallAppearance appearance) async {
    if (_saving) throw StateError('An appearance save is already in progress');
    _saving = true;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final encoded = jsonEncode(appearance.toJson());
      if (!await prefs.setString(thoughtWallAppearanceKey, encoded)) {
        throw StateError('Could not save the wall appearance');
      }
      await prefs.setBool('home_thought_bubble_filled', appearance.bubbleFilled);
      await prefs.setDouble(
        'home_thought_bubble_border_width',
        appearance.bubbleBorderWidth,
      );
      if (ref.mounted) state = appearance;
    } finally {
      _saving = false;
    }
  }
}

final thoughtWallAppearanceProvider =
    NotifierProvider<ThoughtWallAppearanceNotifier, ThoughtWallAppearance>(
      ThoughtWallAppearanceNotifier.new,
    );

const thoughtCategoryShortcutsKey = 'ascent_thought_category_shortcuts_v1';

class ThoughtCategoryShortcutsNotifier extends Notifier<List<String>> {
  bool _saving = false;
  @override
  List<String> build() {
    try {
      return ref
              .watch(sharedPreferencesProvider)
              .getStringList(thoughtCategoryShortcutsKey) ??
          const ['bugs', 'suggestions'];
    } catch (_) {
      return const ['bugs', 'suggestions'];
    }
  }

  Future<void> toggle(String category) async {
    if (_saving) return;
    _saving = true;
    try {
      final next = [...state];
      if (next.contains(category)) {
        next.remove(category);
      } else {
        next.add(category);
      }
      if (!await ref
          .read(sharedPreferencesProvider)
          .setStringList(thoughtCategoryShortcutsKey, next)) {
        throw StateError('Could not save quick filters');
      }
      if (ref.mounted) state = next;
    } finally {
      _saving = false;
    }
  }
}

final thoughtCategoryShortcutsProvider =
    NotifierProvider<ThoughtCategoryShortcutsNotifier, List<String>>(
      ThoughtCategoryShortcutsNotifier.new,
    );
