import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

/// The features a person can switch on. Each one declares, in one place,
/// everything other surfaces need: name, pitch, icon, route and the routes it
/// owns. Home tiles and sections, shortcuts, onboarding and the "Unlock next"
/// card all read this registry instead of keeping their own lists.
enum AscentFeature { things, mind, care, money, focus, vault, travel }

@immutable
class FeatureSpec {
  const FeatureSpec({
    required this.id,
    required this.title,
    required this.pick,
    required this.pitch,
    required this.icon,
    required this.route,
    required this.tintId,
    required this.routes,
    this.starter = true,
  });

  final AscentFeature id;

  /// Name used in lists and tiles ("Things").
  final String title;

  /// First-person label for the onboarding picker ("Plan my day").
  final String pick;

  /// One line on why it is worth turning on.
  final String pitch;
  final IconData icon;

  /// Main screen.
  final String route;

  /// Pillar tint id for `BrandPalette.pillarTint`.
  final String tintId;

  /// Every route this feature owns, for gating shortcuts.
  final Set<String> routes;

  /// Offered on the onboarding "Your first two" screen.
  final bool starter;
}

const featureSpecs = <FeatureSpec>[
  FeatureSpec(
    id: AscentFeature.things,
    title: 'Things',
    pick: 'Plan my day',
    pitch: 'To-dos, timed activities and reminders in one list.',
    icon: Icons.checklist_rounded,
    route: '/things',
    tintId: 'things',
    routes: {
      '/things',
      '/today',
      '/reminders',
      '/plans',
      '/calendar',
      '/promises',
    },
  ),
  FeatureSpec(
    id: AscentFeature.mind,
    title: 'Mind',
    pick: 'Capture thoughts',
    pitch: 'A calm wall for ideas, notes and checklists.',
    icon: Icons.bubble_chart_outlined,
    route: '/thought-wall',
    tintId: 'mind',
    routes: {'/thought-wall'},
  ),
  FeatureSpec(
    id: AscentFeature.care,
    title: 'Care',
    pick: 'Take care of myself',
    pitch: 'Water and medicine, logged in one tap.',
    icon: Icons.favorite_outline_rounded,
    route: '/hydration',
    tintId: 'health',
    routes: {'/hydration', '/medicine'},
  ),
  FeatureSpec(
    id: AscentFeature.money,
    title: 'Money',
    pick: 'Track money',
    pitch: 'See where today’s money went.',
    icon: Icons.account_balance_wallet_outlined,
    route: '/money',
    tintId: 'money',
    routes: {'/money'},
  ),
  FeatureSpec(
    id: AscentFeature.focus,
    title: 'Focus',
    pick: 'Focus better',
    pitch: 'Timed focus sessions that build a gentle streak.',
    icon: Icons.timer_outlined,
    route: '/focus',
    tintId: 'focus',
    routes: {'/focus'},
    starter: false,
  ),
  FeatureSpec(
    id: AscentFeature.vault,
    title: 'Vault',
    pick: 'Keep things safe',
    pitch: 'Cards, IDs and notes, locked on this device.',
    icon: Icons.lock_outline_rounded,
    route: '/vault',
    tintId: 'assistant',
    routes: {'/vault'},
    starter: false,
  ),
  FeatureSpec(
    id: AscentFeature.travel,
    title: 'Travel',
    pick: 'Remember my trips',
    pitch: 'Tap I’m here anywhere; split bills and keep photos by place.',
    icon: Icons.luggage_outlined,
    route: '/travel',
    tintId: 'travel',
    routes: {'/travel'},
    starter: false,
  ),
];

FeatureSpec specOf(AscentFeature f) =>
    featureSpecs.firstWhere((s) => s.id == f);

/// The feature that owns [route], or null for routes every user has.
AscentFeature? featureForRoute(String route) {
  final path = Uri.parse(route).path;
  for (final s in featureSpecs) {
    if (s.routes.any((r) => path == r || path.startsWith('$r/'))) return s.id;
  }
  return null;
}

/// What a new person gets when they skip the picker.
const defaultStarterFeatures = {AscentFeature.things, AscentFeature.mind};

const unlockedFeaturesKey = 'ascent_unlocked_features_v1';

/// Features switched on for this person. People who installed Ascent before
/// gating existed have no stored value and keep everything.
class UnlockedFeaturesNotifier extends Notifier<Set<AscentFeature>> {
  @override
  Set<AscentFeature> build() {
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getStringList(unlockedFeaturesKey);
    if (stored == null) return AscentFeature.values.toSet();
    return {
      for (final name in stored)
        ...AscentFeature.values.where((f) => f.name == name),
    };
  }

  Future<void> set(Set<AscentFeature> features) async {
    state = Set.unmodifiable(features);
    await ref.read(sharedPreferencesProvider).setStringList(
      unlockedFeaturesKey,
      [
        for (final f in AscentFeature.values)
          if (features.contains(f)) f.name,
      ],
    );
  }

  Future<void> unlock(AscentFeature f) => set({...state, f});

  Future<void> lock(AscentFeature f) => set({...state}..remove(f));
}

final unlockedFeaturesProvider =
    NotifierProvider<UnlockedFeaturesNotifier, Set<AscentFeature>>(
      UnlockedFeaturesNotifier.new,
    );

/// The next feature to suggest, in registry order, or null when all are on.
AscentFeature? nextLockedFeature(Set<AscentFeature> unlocked) {
  for (final s in featureSpecs) {
    if (!unlocked.contains(s.id)) return s.id;
  }
  return null;
}
