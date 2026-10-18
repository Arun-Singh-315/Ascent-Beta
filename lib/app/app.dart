import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import '../core/providers/settings_provider.dart';
import '../core/notifications/pending_reminder_effects_provider.dart';

/// Root application widget. Reads theme preference from [settingsProvider]
/// and builds a [MaterialApp.router] powered by [ascentRouter].
class AscentApp extends ConsumerWidget {
  const AscentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final dayPreset = ref.watch(dayThemePresetProvider);
    ref.watch(pendingReminderEffectsProvider);

    return MaterialApp.router(
      title: 'Ascent',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AscentTheme.light(preset: dayPreset),
      darkTheme: AscentTheme.dark(preset: dayPreset),
      themeMode: themeMode,

      // Router
      routerConfig: ascentRouter,
    );
  }
}
