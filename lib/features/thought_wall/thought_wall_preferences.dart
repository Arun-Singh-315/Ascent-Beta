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
  });
  final ThoughtCardStyle style;
  final ThoughtCardTone tone;
  final ThoughtCardDensity density;

  ThoughtWallAppearance copyWith({
    ThoughtCardStyle? style,
    ThoughtCardTone? tone,
    ThoughtCardDensity? density,
  }) => ThoughtWallAppearance(
    style: style ?? this.style,
    tone: tone ?? this.tone,
    density: density ?? this.density,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'style': style.name,
    'tone': tone.name,
    'density': density.name,
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
    );
  }
}

class ThoughtWallAppearanceNotifier extends Notifier<ThoughtWallAppearance> {
  bool _saving = false;
  @override
  ThoughtWallAppearance build() {
    try {
      final raw = ref
          .watch(sharedPreferencesProvider)
          .getString(thoughtWallAppearanceKey);
      if (raw != null) {
        return ThoughtWallAppearance.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
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
